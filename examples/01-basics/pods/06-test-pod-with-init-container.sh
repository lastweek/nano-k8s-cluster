#!/bin/bash
# Test script for 06-pod-with-init-container.yaml
#
# This script demonstrates init containers that run before the main container.

# Color codes
CMD='\033[0;36m'      # Cyan for commands
OUT='\033[0;37m'      # White for output
SUCCESS='\033[0;32m'   # Green for success
ERROR='\033[0;31m'     # Red for errors
INFO='\033[0;33m'      # Yellow for info
NC='\033[0m'           # No Color

set -e

echo "==================================="
echo "Testing: Pod with Init Container"
echo "==================================="
echo ""

# Apply the pod
echo -e "${INFO}Step 1: Creating pod with init container...${NC}"
echo -e "${CMD}$ kubectl apply -f 06-pod-with-init-container.yaml${NC}"
kubectl apply -f 06-pod-with-init-container.yaml
echo ""

# Show initial pod status (Init container running)
echo -e "${INFO}Step 2: Initial pod status (init container running):${NC}"
echo -e "${CMD}$ kubectl get pods pod-with-init${NC}"
kubectl get pods pod-with-init
echo ""
echo "   STATUS: Init:0/1 - means init container is running"
echo ""

# Wait for init container to complete (watch the status change)
echo -e "${INFO}Step 3: Waiting for init container to complete...${NC}"
echo "   (This simulates downloading a model file)"
echo ""

# Wait for pod to be ready (both init and main complete)
echo -e "${CMD}$ kubectl wait --for=condition=ready pod/pod-with-init --timeout=60s${NC}"
kubectl wait --for=condition=ready pod/pod-with-init --timeout=60s

echo -e "${SUCCESS}   ✓ Init container completed!${NC}"
echo -e "${SUCCESS}   ✓ Main container is now running${NC}"
echo ""

# Show final pod status
echo -e "${INFO}Step 4: Final pod status:${NC}"
echo -e "${CMD}$ kubectl get pods pod-with-init${NC}"
kubectl get pods pod-with-init
echo ""

# Show init container logs
echo -e "${INFO}Step 5: Init container logs (model download):${NC}"
echo -e "${CMD}$ kubectl logs pod-with-init -c init-model-downloader${NC}"
kubectl logs pod-with-init -c init-model-downloader
echo ""

# Show main container logs
echo -e "${INFO}Step 6: Main container logs:${NC}"
echo -e "${CMD}$ kubectl logs pod-with-init -c main-app${NC}"
kubectl logs pod-with-init -c main-app
echo ""

# Verify the model file was created
echo -e "${INFO}Step 7: Verifying shared volume worked:${NC}"
echo -e "${CMD}$ kubectl exec pod-with-init -c main-app -- ls -lh /models/${NC}"
kubectl exec pod-with-init -c main-app -- ls -lh /models/
echo ""

# Show pod phases
echo -e "${INFO}Step 8: Pod lifecycle phases:${NC}"
echo "   Phase 1: Pending → Init container starts"
echo "   Phase 2: InitRunning → Init container running"
echo "   Phase 3: Running → Main container starts after init succeeds"
echo ""

echo -e "Current phase: ${CMD}$(kubectl get pod pod-with-init -o jsonpath='{.status.phase}')${NC}"
echo ""

echo "==================================="
echo -e "${SUCCESS}Test complete!${NC}"
echo "==================================="
echo ""
echo "Key concepts demonstrated:"
echo "  ✓ Init containers run BEFORE main containers"
echo "  ✓ Multiple init containers run sequentially"
echo "  ✓ Init and main containers share volumes"
echo "  ✓ Main container waits for init to succeed"
echo "  ✓ If init fails, pod restarts (re-runs init)"
echo ""
echo "For LLM workloads:"
echo "  - Download models from S3/HuggingFace before serving"
echo "  - Validate model files exist"
echo "  - Generate config files based on available GPUs"
echo "  - Setup/check dependencies (database, cache)"
echo ""
echo "Pod is still running. To clean up:"
echo -e "${CMD}$ kubectl delete -f 06-pod-with-init-container.yaml${NC}"
echo ""
