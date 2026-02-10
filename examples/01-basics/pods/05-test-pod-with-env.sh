#!/bin/bash
# Test script for 05-pod-with-env.yaml
#
# This script demonstrates different ways to set environment variables.

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
echo -e "${INFO}Script: test-pod-with-env.sh${NC}"
echo -e "${INFO}===================================${NC}"
echo ""
echo "==================================="
echo "Testing: Pod with Environment Variables"
echo "==================================="
echo ""

# Apply the pod
echo -e "${INFO}Step 1: Creating pod with environment variables...${NC}"
echo -e "${CMD}$ kubectl apply -f 05-pod-with-env.yaml${NC}"
kubectl apply -f 05-pod-with-env.yaml
echo ""

# Wait for pod to be ready
echo -e "${INFO}Step 2: Waiting for pod to be ready...${NC}"
echo -e "${CMD}$ kubectl wait --for=condition=ready pod/pod-with-env --timeout=60s${NC}"
kubectl wait --for=condition=ready pod/pod-with-env --timeout=60s
echo ""

# Show pod status
echo -e "${INFO}Step 3: Pod status:${NC}"
echo -e "${CMD}$ kubectl get pods pod-with-env${NC}"
kubectl get pods pod-with-env
echo ""

# Show environment variables from pod metadata
echo -e "${INFO}Step 4: Environment variables from pod metadata:${NC}"
echo -e "${CMD}$ kubectl exec pod-with-env -- env | grep -E 'POD_NAME|POD_NAMESPACE|POD_IP'${NC}"
kubectl exec pod-with-env -- env | grep -E "POD_NAME|POD_NAMESPACE|POD_IP"
echo ""

# Show custom environment variables
echo -e "${INFO}Step 5: Custom environment variables:${NC}"
echo -e "${CMD}$ kubectl exec pod-with-env -- env | grep -E 'MODEL_NAME|MAX_TOKENS'${NC}"
kubectl exec pod-with-env -- env | grep -E "MODEL_NAME|MAX_TOKENS"
echo ""

# Show resource-based environment variables
echo -e "${INFO}Step 6: Environment variables from resource requests:${NC}"
echo -e "${CMD}$ kubectl exec pod-with-env -- env | grep -E 'CPU_REQUEST|MEMORY_LIMIT'${NC}"
kubectl exec pod-with-env -- env | grep -E "CPU_REQUEST|MEMORY_LIMIT"
echo ""

# Show all environment variables
echo -e "${INFO}Step 7: All environment variables in the pod:${NC}"
echo -e "${CMD}$ kubectl exec pod-with-env -- printenv | sort${NC}"
kubectl exec pod-with-env -- printenv | sort
echo ""

echo "==================================="
echo -e "${SUCCESS}Test complete!${NC}"
echo "==================================="
echo ""
echo "Key concepts demonstrated:"
echo "  ✓ Direct value assignment (MODEL_NAME, MAX_TOKENS)"
echo "  ✓ From pod metadata (POD_NAME, POD_NAMESPACE, POD_IP)"
echo "  ✓ From resource requests (CPU_REQUEST, MEMORY_LIMIT)"
echo ""
echo "For LLM workloads, common env vars:"
echo "  - MODEL_NAME: Which model to load"
echo "  - HF_TOKEN: HuggingFace authentication token"
echo "  - TENSOR_PARALLEL_SIZE: GPU parallelism"
echo "  - GPU_MEMORY_UTILIZATION: Fraction of GPU memory to use"
echo "  - MAX_MODEL_LEN: Maximum sequence length"
echo ""
echo "Pod is still running. To clean up:"
echo -e "${CMD}$ kubectl delete -f 05-pod-with-env.yaml${NC}"
echo ""
