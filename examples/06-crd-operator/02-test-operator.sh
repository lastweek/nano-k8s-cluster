#!/bin/bash
# Test script for 02-simple-operator.yaml
#
# This script demonstrates the operator pattern following the gradual learning approach.
# See CRD-GUIDE.md for detailed explanation.

# Color codes
CMD='\033[0;36m'      # Cyan for commands
OUT='\033[0;37m'      # White for output
SUCCESS='\033[0;32m'   # Green for success
ERROR='\033[0;31m'     # Red for errors
INFO='\033[0;33m'      # Yellow for info
WARN='\033[0;35m'      # Magenta for warnings
NC='\033[0m'           # No Color

set -e

# ==============================================================================
# INTRODUCTION
# ==============================================================================

echo -e "${INFO}===========================================${NC}"
echo -e "${INFO}Script: 02-test-operator.sh${NC}"
echo -e "${INFO}===========================================${NC}"
echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║         LAYER 3: Operator - The Engine                        ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "In this script, you will learn:"
echo "  1. What an operator is (and what it does)"
echo "  2. How the operator watches custom resources"
echo "  3. How the operator creates actual containers"
echo ""
echo "Key concept to remember:"
echo -e "${WARN}  Operator = Controller that watches and reconciles${NC}"
echo ""
echo "Prerequisites:"
echo "  - You should have run ./01-test-crd.sh first"
echo "  - CRD and LLMModel should already exist"
echo ""

# ==============================================================================
# PRE-CHECK: Verify CRD exists
# ==============================================================================

echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}PRE-CHECK: Verifying Prerequisites${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if ! kubectl get crd llmmodels.ai.example.com &>/dev/null; then
    echo -e "${ERROR}❌ CRD not found!${NC}"
    echo ""
    echo "Please run ./01-test-crd.sh first to create the CRD."
    exit 1
fi

echo -e "${SUCCESS}✓ CRD exists${NC}"

if ! kubectl get llmmodel llama-3-70b-serving &>/dev/null; then
    echo -e "${WARN}⚠ LLMModel 'llama-3-70b-serving' not found${NC}"
    echo ""
    echo "Creating it now..."
    cat > /tmp/my-llm-model.yaml <<EOF
apiVersion: ai.example.com/v1
kind: LLMModel
metadata:
  name: llama-3-70b-serving
spec:
  modelName: llama-3-70b
  modelPath: /models/llama-3-70b
  replicas: 3
  gpuType: H100
  gpuMemory: 80Gi
  maxTokens: 4096
  temperature: 0.7
  enableStreaming: true
  enableCache: true
EOF
    kubectl apply -f /tmp/my-llm-model.yaml
fi

echo -e "${SUCCESS}✓ LLMModel exists${NC}"
echo ""

# Show current state (nothing running!)
echo "Current state BEFORE operator:"
echo ""
echo -e "${CMD}$ kubectl get llmmodels${NC}"
kubectl get llmmodels
echo ""

echo -e "${CMD}$ kubectl get deployments${NC}"
kubectl get deployments 2>&1 | grep -v "No resources" || echo "  (No deployments found)"
echo ""

echo -e "${ERROR}❌ Remember: LLMModel exists but nothing is running!${NC}"
echo ""

# ==============================================================================
# STEP 1: Understanding the operator concept
# ==============================================================================

echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}STEP 1: Understanding the Operator Concept${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "What is an operator?"
echo ""
echo "  ╔═══════════════════════════════════════════════════════════╗"
echo "  ║  Operator = Controller + Automation Logic               ║"
echo "  ╠═══════════════════════════════════════════════════════════╣"
echo "  ║  It does:                                                ║"
echo "  ║    1. WATCH  → Watch for changes to LLMModel resources  ║"
echo "  ║    2. READ   → Read the spec (what you want)             ║"
echo "  ║    3. COMPARE→ Compare with actual state                ║"
echo "  ║    4. CREATE → Create/Update Deployments                ║"
echo "  ║    5. UPDATE → Update status                             ║"
echo "  ║    6. REPEAT→ Do this forever (the reconciliation loop) ║"
echo "  ╚═══════════════════════════════════════════════════════════╝"
echo ""
echo "Press Enter to continue..."
read

# ==============================================================================
# STEP 2: Deploying the operator
# ==============================================================================

echo ""
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}STEP 2: Deploying the Operator${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "The operator is deployed as a Deployment (it runs in a pod!)"
echo ""
echo "Running:"
echo -e "${CMD}$ kubectl apply -f 02-simple-operator.yaml${NC}"
echo ""
kubectl apply -f 02-simple-operator.yaml
echo ""
echo -e "${SUCCESS}✓ Operator deployment created!${NC}"
echo ""

# ==============================================================================
# STEP 3: Waiting for operator to start
# ==============================================================================

echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}STEP 3: Waiting for Operator Pod to Start${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "The operator needs to:"
echo "  1. Pull the container image (python:3.11-slim)"
echo "  2. Install kubectl and Python dependencies"
echo "  3. Start the reconciliation loop"
echo ""
echo "Waiting for pod to be ready..."
kubectl wait --for=condition=ready pod -l app=llm-operator --timeout=120s > /dev/null 2>&1 || {
    echo -e "${WARN}Pod not ready yet, but continuing...${NC}"
}
echo ""
echo -e "${SUCCESS}✓ Operator pod is running!${NC}"
echo ""

# ==============================================================================
# STEP 4: Viewing the operator pod
# ==============================================================================

echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}STEP 4: Viewing the Operator Pod${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "The operator itself runs in a pod:"
echo ""
echo -e "${CMD}$ kubectl get pods -l app=llm-operator${NC}"
kubectl get pods -l app=llm-operator
echo ""

# ==============================================================================
# STEP 5: Seeing the operator in action (logs)
# ==============================================================================

echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}STEP 5: Operator Logs - The Reconciliation Loop${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Let's see what the operator is doing:"
echo ""
echo -e "${CMD}$ kubectl logs -l app=llm-operator --tail=20${NC}"
kubectl logs -l app=llm-operator --tail=20
echo ""
echo "Notice:"
echo "  - 🚀 Operator started"
echo "  - Watching for LLMModel resources"
echo "  - Initial reconcile of existing resources"
echo "  - Creating/updating deployments"
echo ""

# ==============================================================================
# STEP 6: The magic moment - containers are created!
# ==============================================================================

echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}STEP 6: The Magic - Containers Are Created!${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Let's check what happened. Remember, before we had NO deployments."
echo "Now let's check:"
echo ""
echo -e "${CMD}$ kubectl get deployments${NC}"
kubectl get deployments
echo ""

if kubectl get deployment llmmodel-llama-3-70b-serving &>/dev/null; then
    echo -e "${SUCCESS}✓ Deployment created by operator!${NC}"
    echo ""
    echo "Let's see the pods:"
    echo ""
    echo -e "${CMD}$ kubectl get pods -l llmmodel=llama-3-70b-serving${NC}"
    kubectl get pods -l llmmodel=llama-3-70b-serving
    echo ""
    echo -e "${SUCCESS}✓✓✓ CONTAINERS ARE NOW RUNNING! ✓✓✓${NC}"
else
    echo -e "${WARN}⚠ Deployment not found yet. Let's wait a bit...${NC}"
    sleep 5
    echo ""
    echo -e "${CMD}$ kubectl get deployments${NC}"
    kubectl get deployments
fi
echo ""

# ==============================================================================
# STEP 7: Understanding the flow
# ==============================================================================

echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}STEP 7: Understanding the Complete Flow${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Here's what just happened:"
echo ""
echo "  ┌────────────────────────────────────────────────────────────┐"
echo "  │  1. You created LLMModel (in script 01)                     │"
echo "  │     ┌──────────────────────────────────────────────────┐  │"
echo "  │     │ kind: LLMModel                                     │  │"
echo "  │     │ metadata:                                          │  │"
echo "  │     │   name: llama-3-70b-serving                        │  │"
echo "  │     │ spec:                                              │  │"
echo "  │     │   replicas: 3                                      │  │"
echo "  │     │   modelName: llama-3-70b                           │  │"
echo "  │     └──────────────────────────────────────────────────┘  │"
echo "  ├────────────────────────────────────────────────────────────┤"
echo "  │  2. Operator noticed (via watch API)                       │"
echo "  │     Event: ADDED llama-3-70b-serving                       │"
echo "  ├────────────────────────────────────────────────────────────┤"
echo "  │  3. Operator's reconciliation loop:                        │"
echo "  │     ┌──────────────────────────────────────────────────┐  │"
echo "  │     │ def reconcile():                                  │  │"
echo "  │     │     spec = get_llmmodel_spec()                   │  │"
echo "  │     │     deployment = create_deployment_from(spec)    │  │"
echo "  │     │     kubectl.create(deployment)                   │  │"
echo "  │     │     update_llmmodel_status()                     │  │"
echo "  │     └──────────────────────────────────────────────────┘  │"
echo "  ├────────────────────────────────────────────────────────────┤"
echo "  │  4. Kubernetes creates Deployment                          │"
echo "  │     Name: llmmodel-llama-3-70b-serving                     │"
echo "  ├────────────────────────────────────────────────────────────┤"
echo "  │  5. Deployment creates Pods                                │"
echo "  │     llmmodel-llama-3-70b-serving-xxx-0                     │"
echo "  │     llmmodel-llama-3-70b-serving-xxx-1                     │"
echo "  │     llmmodel-llama-3-70b-serving-xxx-2                     │"
echo "  ├────────────────────────────────────────────────────────────┤"
echo "  │  6. Pods run CONTAINERS                                    │"
echo "  │     Container: nginx:1.25 (placeholder for vLLM)          │"
echo "  └────────────────────────────────────────────────────────────┘"
echo ""

# ==============================================================================
# STEP 8: Viewing the LLMModel status
# ==============================================================================

echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}STEP 8: LLMModel Status (Updated by Operator)${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "The operator updates the LLMModel status with actual state:"
echo ""
echo -e "${CMD}$ kubectl get llmmodel llama-3-70b-serving -o yaml${NC}"
kubectl get llmmodel llama-3-70b-serving -o yaml | grep -A 10 "status:"
echo ""
echo "Notice the status shows:"
echo "  - phase: Running"
echo "  - replicas: Actual number of replicas"
echo "  - readyReplicas: Number of ready replicas"
echo "  - message: Status message"
echo ""

# ==============================================================================
# STEP 9: The reconciliation loop in action
# ==============================================================================

echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}STEP 9: The Reconciliation Loop in Action${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Now let's see the operator react to changes!"
echo ""
echo "We'll change the replicas from 3 to 5..."
echo ""
echo -e "${CMD}$ kubectl patch llmmodel llama-3-70b-serving -p '{\"spec\":{\"replicas\":5}}'${NC}"
kubectl patch llmmodel llama-3-70b-serving -p '{"spec":{"replicas":5}}' > /dev/null
echo ""
echo "Waiting for operator to reconcile..."
sleep 5
echo ""

echo "Deployment after operator reconciliation:"
echo -e "${CMD}$ kubectl get deployment llmmodel-llama-3-70b-serving${NC}"
kubectl get deployment llmmodel-llama-3-70b-serving
echo ""

echo "Pods created:"
echo -e "${CMD}$ kubectl get pods -l llmmodel=llama-3-70b-serving${NC}"
kubectl get pods -l llmmodel=llama-3-70b-serving
echo ""

echo -e "${SUCCESS}✓ Operator automatically scaled to 5 replicas!${NC}"
echo ""

# ==============================================================================
# STEP 10: Operator logs during reconciliation
# ==============================================================================

echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}STEP 10: Operator Logs During Reconciliation${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "See what the operator logged:"
echo ""
echo -e "${CMD}$ kubectl logs -l app=llm-operator --tail=15${NC}"
kubectl logs -l app=llm-operator --tail=15
echo ""

# ==============================================================================
# SUMMARY
# ==============================================================================

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                       SUMMARY                                ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "You learned:"
echo ""
echo "  ✓ Operator watches custom resources"
echo "  ✓ Operator reads spec and creates deployments"
echo "  ✓ Operator updates status based on actual state"
echo "  ✓ Operator continuously reconciles (the control loop)"
echo "  ✓ Changes to spec trigger automatic reconciliation"
echo ""
echo -e "${WARN}Key takeaways:${NC}"
echo ""
echo "  1. CRD defines the API (like a class)"
echo "  2. Instance stores your desired state (like an object)"
echo "  3. Operator watches and makes it happen (the engine)"
echo ""
echo "  ┌──────────────────────────────────────────────────────────┐"
echo "  │  CRD + Operator Pattern:                                 │"
echo "  │                                                           │"
echo "  │  You write:                                               │"
echo "  │    kind: LLMModel                                         │"
echo "  │    spec:                                                  │"
echo "  │      modelName: llama-3-70b                              │"
echo "  │      replicas: 3                                          │"
echo "  │                                                           │"
echo "  │  Operator creates automatically:                          │"
echo "  │    - Deployment with pods                                 │"
echo "  │    - Services                                             │"
echo "  │    - ConfigMaps                                           │"
echo "  │    - Anything else needed!                                │"
echo "  └──────────────────────────────────────────────────────────┘"
echo ""

echo "Why this matters for LLM serving:"
echo ""
echo "  • NVIDIA Dynamo uses this pattern!"
echo "  • You define model deployment once"
echo "  • Operator handles:"
echo "    - GPU scheduling and allocation"
echo "    - Tensor parallelism setup"
echo "    - Autoscaling based on SLA"
echo "    - Model loading and checkpointing"
echo "    - Self-healing and recovery"
echo ""

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Test Complete!                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "To clean up:"
echo -e "${CMD}$ kubectl delete -f 02-simple-operator.yaml${NC}"
echo -e "${CMD}$ kubectl delete -f 01-what-is-crd.yaml${NC}"
echo ""
echo "Or run: ./cleanup-all-crd-operator.sh"
echo ""
echo "For more details, see: CRD-GUIDE.md"
echo ""
