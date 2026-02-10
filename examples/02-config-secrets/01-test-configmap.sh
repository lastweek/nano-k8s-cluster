#!/bin/bash
# Test script for 01-configmap.yaml
#
# This script demonstrates basic ConfigMap usage.

# Color codes
CMD='\033[0;36m'      # Cyan for commands
OUT='\033[0;37m'      # White for output
SUCCESS='\033[0;32m'   # Green for success
ERROR='\033[0;31m'     # Red for errors
INFO='\033[0;33m'      # Yellow for info
NC='\033[0m'           # No Color

set -e

# Show script filename
echo -e "${INFO}===================================${NC}"
echo -e "${INFO}Script: 01-test-configmap.sh${NC}"
echo -e "${INFO}===================================${NC}"
echo ""
echo "==================================="
echo "Testing: ConfigMap (Basic)"
echo "==================================="
echo ""

# Apply the ConfigMap and pod
echo -e "${INFO}Step 1: Creating ConfigMap and pod...${NC}"
echo -e "${CMD}$ kubectl apply -f 01-configmap.yaml${NC}"
kubectl apply -f 01-configmap.yaml
echo ""

# Wait for pod to be ready
echo -e "${INFO}Step 2: Waiting for pod to be ready...${NC}"
kubectl wait --for=condition=ready pod/configmap-demo --timeout=60s > /dev/null
echo -e "${SUCCESS}   ✓ Pod ready${NC}"
echo ""

# Show ConfigMap
echo -e "${INFO}Step 3: Show ConfigMap...${NC}"
echo -e "${CMD}$ kubectl get configmap model-config${NC}"
kubectl get configmap model-config
echo ""

# Show ConfigMap data
echo -e "${INFO}Step 4: Show ConfigMap data...${NC}"
echo -e "${CMD}$ kubectl describe configmap model-config${NC}"
kubectl describe configmap model-config
echo ""

# Show ConfigMap in YAML format
echo -e "${INFO}Step 5: Show ConfigMap YAML...${NC}"
echo -e "${CMD}$ kubectl get configmap model-config -o yaml${NC}"
kubectl get configmap model-config -o yaml
echo ""

# Show pod
echo -e "${INFO}Step 6: Show pod...${NC}"
echo -e "${CMD}$ kubectl get pod configmap-demo${NC}"
kubectl get pod configmap-demo
echo ""

# Check environment variables in pod
echo -e "${INFO}Step 7: Check environment variables in pod...${NC}"
echo ""
echo "  Model configuration:"
echo -e "${CMD}$ kubectl exec configmap-demo -- env | grep MODEL${NC}"
kubectl exec configmap-demo -- env | grep MODEL
echo ""
echo "  Serving configuration:"
echo -e "${CMD}$ kubectl exec configmap-demo -- env | grep BATCH_SIZE${NC}"
kubectl exec configmap-demo -- env | grep BATCH_SIZE
kubectl exec configmap-demo -- env | grep MAX_TOKENS
kubectl exec configmap-demo -- env | grep TEMPERATURE
echo ""
echo "  Logging configuration:"
echo -e "${CMD}$ kubectl exec configmap-demo -- env | grep LOG_LEVEL${NC}"
kubectl exec configmap-demo -- env | grep LOG_LEVEL
echo ""

# Demonstrate ConfigMap update
echo -e "${INFO}Step 8: Demonstrate ConfigMap update...${NC}"
echo "  Updating model.name to 'llama-3-70b-tuned'..."
echo ""

# Update ConfigMap
kubectl patch configmap model-config --type merge -p '{"data":{"model.name":"llama-3-70b-tuned"}}'

echo "  Updated ConfigMap:"
echo -e "${CMD}$ kubectl get configmap model-config -o jsonpath='{.data.model\.name}'${NC}"
kubectl get configmap model-config -o jsonpath='{.data.model\.name}'
echo ""
echo "  Note: Pod environment variable still shows old value"
echo "  Environment variables are set at pod startup"
echo "  Pod must be restarted to pick up ConfigMap changes"
echo ""

# Show how to restart pod to pick up changes
echo -e "${INFO}Step 9: Restart pod to pick up ConfigMap changes...${NC}"
echo "  Deleting pod to recreate it with new ConfigMap..."
echo ""
echo -e "${CMD}$ kubectl delete pod configmap-demo${NC}"
kubectl delete pod configmap-demo --ignore-not-found=true > /dev/null

# Wait for new pod to be ready
echo "  Waiting for new pod..."
kubectl wait --for=condition=ready pod/configmap-demo --timeout=60s > /dev/null
echo -e "${SUCCESS}   ✓ New pod ready${NC}"
echo ""

echo "  Updated environment variable:"
echo -e "${CMD}$ kubectl exec configmap-demo -- env | grep MODEL_NAME${NC}"
kubectl exec configmap-demo -- env | grep MODEL_NAME
echo ""

# Show ConfigMap usage patterns
echo -e "${INFO}Step 10: ConfigMap usage patterns...${NC}"
echo ""
echo "  1. Environment variables (shown in this example)"
echo "     - Good for simple key-value pairs"
echo "     - Set at pod startup"
echo ""
echo "  2. Mounted as files (shown in next example)"
echo "     - Good for config files"
echo "     - Updates propagate without restart"
echo ""
echo "  3. Command-line arguments"
echo "     - Use ConfigMap values in container commands"
echo ""

echo "==================================="
echo -e "${SUCCESS}Test Complete!${NC}"
echo "==================================="
echo ""
echo "Key concepts demonstrated:"
echo "  ✓ ConfigMap stores configuration data"
echo "  ✓ ConfigMap as environment variables"
echo "  ✓ ConfigMap updates require pod restart for env vars"
echo "  ✓ Configuration separated from pod spec"
echo ""
echo "Why this matters for LLM serving:"
echo "  - Store model configuration (name, path, batch size)"
echo "  - Store hyperparameters (temperature, top_k, top_p)"
echo "  - Update configuration without rebuilding images"
echo ""
echo "Pod and ConfigMap are still running. To clean up:"
echo -e "${CMD}$ kubectl delete -f 01-configmap.yaml${NC}"
echo ""
echo "Or run: ./cleanup-all-config-secrets.sh"
echo ""
