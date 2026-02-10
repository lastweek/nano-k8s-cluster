#!/bin/bash
# Test script for 03-rolling-update.yaml
#
# This script demonstrates rolling updates.

# Color codes
CMD='\033[0;36m'      # Cyan for commands
OUT='\033[0;37m'      # White for output
SUCCESS='\033[0;32m'   # Green for success
ERROR='\033[0;31m'     # Red for errors
INFO='\033[0;33m'      # Yellow for info
WARN='\033[0;35m'      # Magenta for warnings
NC='\033[0m'           # No Color

set -e

# Show script filename
echo -e "${INFO}===================================${NC}"
echo -e "${INFO}Script: 03-test-rolling-update.sh${NC}"
echo -e "${INFO}===================================${NC}"
echo ""
echo "==================================="
echo "Testing: Rolling Updates"
echo "==================================="
echo ""

# Apply the deployment
echo -e "${INFO}Step 1: Creating deployment (nginx:1.25)...${NC}"
echo -e "${CMD}$ kubectl apply -f 03-rolling-update.yaml${NC}"
kubectl apply -f 03-rolling-update.yaml
echo ""

# Wait for deployment to be ready
kubectl rollout status deployment/nginx-rolling --timeout=60s > /dev/null
echo -e "${SUCCESS}   ✓ Deployment ready (3 replicas of nginx:1.25)${NC}"
echo ""

# Show initial pods
echo -e "${INFO}Step 2: Initial pods (all running nginx:1.25)...${NC}"
echo -e "${CMD}$ kubectl get pods -l app=nginx-rolling -o custom-columns='NAME:.metadata.name,IMAGE:.spec.containers[0].image'${NC}"
kubectl get pods -l app=nginx-rolling -o custom-columns='NAME:.metadata.name,IMAGE:.spec.containers[0].image'
echo ""

# Show rollout history
echo -e "${INFO}Step 3: Current rollout history...${NC}"
echo -e "${CMD}$ kubectl rollout history deployment/nginx-rolling${NC}"
kubectl rollout history deployment/nginx-rolling
echo ""

# Update to new image
echo -e "${INFO}Step 4: Updating to nginx:1.26 (rolling update)...${NC}"
echo -e "${CMD}$ kubectl set image deployment/nginx-rolling nginx=nginx:1.26${NC}"
kubectl set image deployment/nginx-rolling nginx=nginx:1.26
echo ""

# Watch the rolling update
echo -e "${INFO}Step 5: Watching rolling update...${NC}"
echo "   This creates new pods before terminating old ones (maxSurge: 1)"
echo "   Zero pods unavailable (maxUnavailable: 0)"
echo ""

kubectl rollout status deployment/nginx-rolling --timeout=60s
echo -e "${SUCCESS}   ✓ Rolling update complete!${NC}"
echo ""

# Show pods after update
echo -e "${INFO}Step 6: Pods after update (all running nginx:1.26)...${NC}"
echo -e "${CMD}$ kubectl get pods -l app=nginx-rolling -o custom-columns='NAME:.metadata.name,IMAGE:.spec.containers[0].image'${NC}"
kubectl get pods -l app=nginx-rolling -o custom-columns='NAME:.metadata.name,IMAGE:.spec.containers[0].image'
echo ""

# Show updated rollout history
echo -e "${INFO}Step 7: Rollout history (2 revisions)...${NC}"
echo -e "${CMD}$ kubectl rollout history deployment/nginx-rolling${NC}"
kubectl rollout history deployment/nginx-rolling
echo ""

# Pause briefly, then rollback
echo -e "${INFO}Step 8: Rolling back to previous version...${NC}"
sleep 2
echo -e "${CMD}$ kubectl rollout undo deployment/nginx-rolling${NC}"
kubectl rollout undo deployment/nginx-rolling
echo ""

# Wait for rollback
kubectl rollout status deployment/nginx-rolling --timeout=60s > /dev/null
echo -e "${SUCCESS}   ✓ Rollback complete!${NC}"
echo ""

# Show pods after rollback
echo -e "${INFO}Step 9: Pods after rollback (back to nginx:1.25)...${NC}"
echo -e "${CMD}$ kubectl get pods -l app=nginx-rolling -o custom-columns='NAME:.metadata.name,IMAGE:.spec.containers[0].image'${NC}"
kubectl get pods -l app=nginx-rolling -o custom-columns='NAME:.metadata.name,IMAGE:.spec.containers[0].image'
echo ""

# Show final rollout history
echo -e "${INFO}Step 10: Final rollout history (3 revisions)...${NC}"
echo -e "${CMD}$ kubectl rollout history deployment/nginx-rolling${NC}"
kubectl rollout history deployment/nginx-rolling
echo ""

echo "==================================="
echo -e "${SUCCESS}Test Complete!${NC}"
echo "==================================="
echo ""
echo "Key concepts demonstrated:"
echo "  ✓ RollingUpdate strategy (gradual pod replacement)"
echo "  ✓ Zero downtime: maxUnavailable: 0, maxSurge: 1"
echo "  ✓ Image update with kubectl set image"
echo "  ✓ Rollback with kubectl rollout undo"
echo "  ✓ Revision history maintained"
echo ""
echo "Why this matters for LLM serving:"
echo "  - Update model without downtime"
echo "  - Rollback if new model has issues"
echo "  - Gradual rollout prevents cluster-wide failures"
echo ""
echo "Pods are still running. To clean up:"
echo -e "${CMD}$ kubectl delete -f 03-rolling-update.yaml${NC}"
echo ""
echo "Or run: ./cleanup-all-deployments.sh"
echo ""
