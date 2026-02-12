#!/usr/bin/env python3
"""
LLM Model Operator

A simple Kubernetes operator that watches LLMModel custom resources and
creates/updates Deployments to run the model serving containers.

This demonstrates the operator pattern:
- Watch custom resources (LLMModel)
- Reconcile desired state (spec) with actual state (deployments)
- Update status based on actual state

Author: nano-k8s-cluster examples
"""

from kubernetes import client, config
from kubernetes.watch import Watch
import time
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Kubernetes API configuration
CRD_GROUP = "ai.example.com"
CRD_VERSION = "v1"
CRD_PLURAL = "llmmodels"
NAMESPACE = "default"

# Container image to use for model serving
# In production, this would be a real vLLM or similar image
MODEL_CONTAINER_IMAGE = "nginx:1.25"


def get_deployment_name(llmmodel_name: str) -> str:
    """Generate deployment name from LLMModel name."""
    return f"llmmodel-{llmmodel_name}"


def build_deployment_spec(llmmodel: dict) -> dict:
    """
    Build a Kubernetes Deployment spec from an LLMModel resource.

    Args:
        llmmodel: The LLMModel custom resource

    Returns:
        Deployment spec dictionary
    """
    name = llmmodel['metadata']['name']
    spec = llmmodel.get('spec', {})

    deployment_spec = {
        'apiVersion': 'apps/v1',
        'kind': 'Deployment',
        'metadata': {
            'name': get_deployment_name(name),
            'namespace': NAMESPACE,
            'labels': {
                'app': 'llm-serving',
                'llmmodel': name
            }
        },
        'spec': {
            'replicas': spec.get('replicas', 1),
            'selector': {
                'matchLabels': {
                    'app': 'llm-serving',
                    'llmmodel': name
                }
            },
            'template': {
                'metadata': {
                    'labels': {
                        'app': 'llm-serving',
                        'llmmodel': name
                    }
                },
                'spec': {
                    'containers': [{
                        'name': 'model',
                        'image': MODEL_CONTAINER_IMAGE,
                        'ports': [{'containerPort': 80}],
                        'env': [
                            {
                                'name': 'MODEL_NAME',
                                'value': spec.get('modelName', '')
                            },
                            {
                                'name': 'MODEL_PATH',
                                'value': spec.get('modelPath', '')
                            },
                            {
                                'name': 'MAX_TOKENS',
                                'value': str(spec.get('maxTokens', 4096))
                            },
                            {
                                'name': 'TEMPERATURE',
                                'value': str(spec.get('temperature', 0.7))
                            },
                            {
                                'name': 'GPU_TYPE',
                                'value': spec.get('gpuType', 'A100')
                            },
                            {
                                'name': 'GPU_MEMORY',
                                'value': spec.get('gpuMemory', '80Gi')
                            }
                        ]
                    }]
                }
            }
        }
    }

    return deployment_spec


def reconcile_llmmodel(llmmodel: dict, apps_api: client.AppsV1Api, custom_api: client.CustomObjectsApi):
    """
    Reconcile a single LLMModel resource.

    This is the core reconciliation logic:
    1. Read the LLMModel spec (desired state)
    2. Check if Deployment exists (actual state)
    3. Create or update Deployment to match desired state
    4. Update LLMModel status with actual state

    Args:
        llmmodel: The LLMModel custom resource
        apps_api: Kubernetes AppsV1Api client
        custom_api: Kubernetes CustomObjectsApi client
    """
    name = llmmodel['metadata']['name']
    deployment_name = get_deployment_name(name)

    logger.info(f"Reconciling LLMModel: {name}")

    # Build deployment spec from LLMModel spec
    deployment_spec = build_deployment_spec(llmmodel)

    # Create or update deployment
    try:
        # Try to get existing deployment
        apps_api.read_namespaced_deployment(deployment_name, NAMESPACE)
        # Update existing
        apps_api.patch_namespaced_deployment(
            name=deployment_name,
            namespace=NAMESPACE,
            body=deployment_spec
        )
        logger.info(f"✓ Updated deployment {deployment_name}")
    except client.ApiException as e:
        if e.status == 404:
            # Create new deployment
            apps_api.create_namespaced_deployment(
                namespace=NAMESPACE,
                body=deployment_spec
            )
            logger.info(f"✓ Created deployment {deployment_name}")
        else:
            logger.error(f"Error handling deployment: {e}")
            raise

    # Update status
    update_llmmodel_status(name, deployment_name, apps_api, custom_api)


def update_llmmodel_status(name: str, deployment_name: str, apps_api: client.AppsV1Api, custom_api: client.CustomObjectsApi):
    """
    Update the LLMModel status with actual deployment state.

    Args:
        name: LLMModel name
        deployment_name: Deployment name
        apps_api: Kubernetes AppsV1Api client
        custom_api: Kubernetes CustomObjectsApi client
    """
    try:
        deployment = apps_api.read_namespaced_deployment(deployment_name, NAMESPACE)
        ready_replicas = deployment.status.ready_replicas or 0
        desired_replicas = deployment.spec.replicas

        status_patch = {
            'status': {
                'phase': 'Running',
                'replicas': desired_replicas,
                'readyReplicas': ready_replicas,
                'message': f'Deployment {deployment_name} has {ready_replicas}/{desired_replicas} ready replicas'
            }
        }

        custom_api.patch_namespaced_custom_object(
            group=CRD_GROUP,
            version=CRD_VERSION,
            namespace=NAMESPACE,
            plural=CRD_PLURAL,
            name=name,
            body=status_patch
        )
        logger.info(f"✓ Updated status for {name}")
    except Exception as e:
        logger.error(f"Error updating status: {e}")


def delete_deployment_for_llmmodel(llmmodel: dict, apps_api: client.AppsV1Api):
    """
    Delete the deployment when LLMModel is deleted.

    Args:
        llmmodel: The LLMModel custom resource
        apps_api: Kubernetes AppsV1Api client
    """
    name = llmmodel['metadata']['name']
    deployment_name = get_deployment_name(name)

    try:
        apps_api.delete_namespaced_deployment(deployment_name, NAMESPACE)
        logger.info(f"✓ Deleted deployment {deployment_name}")
    except client.ApiException as e:
        if e.status == 404:
            logger.info(f"Deployment {deployment_name} already deleted")
        else:
            logger.error(f"Error deleting deployment: {e}")


def do_initial_reconciliation(apps_api: client.AppsV1Api, custom_api: client.CustomObjectsApi):
    """
    Perform initial reconciliation of all existing LLMModel resources.

    This is called when the operator starts to handle any resources that
    were created before the operator started.

    Args:
        apps_api: Kubernetes AppsV1Api client
        custom_api: Kubernetes CustomObjectsApi client
    """
    logger.info("Performing initial reconciliation...")

    try:
        llmmodels = custom_api.list_namespaced_custom_object(
            NAMESPACE, CRD_GROUP, CRD_VERSION, CRD_PLURAL
        )

        items = llmmodels.get('items', [])
        logger.info(f"Found {len(items)} existing LLMModel resources")

        for llmmodel in items:
            name = llmmodel['metadata']['name']
            logger.info(f"Initial reconcile: {name}")
            reconcile_llmmodel(llmmodel, apps_api, custom_api)

    except client.ApiException as e:
        if e.status == 404:
            logger.info("No LLMModel resources found (CRD may not exist yet)")
        else:
            logger.error(f"Initial reconcile error: {e}")


def watch_and_reconcile(apps_api: client.AppsV1Api, custom_api: client.CustomObjectsApi):
    """
    Watch for changes to LLMModel resources and reconcile.

    This is the main reconciliation loop. It watches for events
    (ADDED, MODIFIED, DELETED) and triggers reconciliation.

    Args:
        apps_api: Kubernetes AppsV1Api client
        custom_api: Kubernetes CustomObjectsApi client
    """
    w = Watch()

    logger.info(f"Watching for LLMModel resources in namespace '{NAMESPACE}'...")

    stream = w.stream(
        custom_api.list_namespaced_custom_object,
        NAMESPACE,
        CRD_GROUP,
        CRD_VERSION,
        CRD_PLURAL,
        timeout_seconds=0  # Watch forever
    )

    for event in stream:
        event_type = event['type']
        llmmodel = event['object']

        name = llmmodel['metadata']['name']
        logger.info(f"Event: {event_type} - {name}")

        if event_type in ['ADDED', 'MODIFIED']:
            reconcile_llmmodel(llmmodel, apps_api, custom_api)
        elif event_type == 'DELETED':
            delete_deployment_for_llmmodel(llmmodel, apps_api)


def main():
    """
    Main entry point for the operator.

    Sets up Kubernetes clients and starts the reconciliation loop.
    """
    logger.info("🚀 LLM Model Operator starting...")

    # Load Kubernetes configuration from service account or in-cluster config
    try:
        config.load_incluster_config()
        logger.info("Loaded in-cluster configuration")
    except config.ConfigException:
        try:
            config.load_kube_config()
            logger.info("Loaded local kubeconfig configuration")
        except config.ConfigException:
            logger.error("Could not load Kubernetes configuration")
            return

    # Initialize API clients
    custom_api = client.CustomObjectsApi()
    apps_api = client.AppsV1Api()

    logger.info(f"Configuration:")
    logger.info(f"  Namespace: {NAMESPACE}")
    logger.info(f"  Group: {CRD_GROUP}")
    logger.info(f"  Version: {CRD_VERSION}")
    logger.info(f"  Plural: {CRD_PLURAL}")
    logger.info("")

    # Perform initial reconciliation
    do_initial_reconciliation(apps_api, custom_api)

    # Start watching and reconciling
    logger.info("Starting watch loop...")
    watch_and_reconcile(apps_api, custom_api)


if __name__ == "__main__":
    main()
