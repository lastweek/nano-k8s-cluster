#!/bin/bash
# Test script for 01-basic-deployment.yaml
#
# This script demonstrates a basic Kubernetes deployment.

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
echo -e "${INFO}Script: 01-test-basic-deployment.sh${NC}"
echo -e "${INFO}===================================${NC}"
echo ""
echo "==================================="
echo "Testing: Basic Deployment"
echo "==================================="
echo ""

# Apply the deployment
echo -e "${INFO}Step 1: Creating deployment...${NC}"
echo -e "${CMD}$ kubectl apply -f 01-basic-deployment.yaml${NC}"
kubectl apply -f 01-basic-deployment.yaml
echo ""

# Watch rollout status
echo -e "${INFO}Step 2: Watching rollout status...${NC}"
echo -e "${CMD}$ kubectl rollout status deployment/nginx-deployment${NC}"
kubectl rollout status deployment/nginx-deployment --timeout=60s
echo ""

# Show all resources created
echo -e "${INFO}Step 3: Show all resources created...${NC}"
echo -e "${CMD}$ kubectl get all -l app=nginx${NC}"
kubectl get all -l app=nginx
echo ""

# Show deployment details
echo -e "${INFO}Step 4: Deployment details...${NC}"
echo -e "${CMD}$ kubectl describe deployment nginx-deployment | head -30${NC}"
kubectl describe deployment nginx-deployment | head -30
echo ""

# Show replicaset
echo -e "${INFO}Step 5: ReplicaSet created by deployment...${NC}"
echo -e "${CMD}$ kubectl get replicaset -l app=nginx${NC}"
kubectl get replicaset -l app=nginx
echo ""

# Show pods
echo -e "${INFO}Step 6: Pods created by deployment...${NC}"
echo -e "${CMD}$ kubectl get pods -l app=nginx${NC}"
kubectl get pods -l app=nginx
echo ""

# Test self-healing (delete a pod and watch it recreate)
echo -e "${INFO}Step 7: Testing self-healing (delete one pod)...${NC}"
POD_NAME=$(kubectl get pods -l app=nginx -o jsonpath='{.items[0].metadata.name}')
echo "   Deleting pod: $POD_NAME"
echo -e "${CMD}$ kubectl delete pod $POD_NAME${NC}"
kubectl delete pod "$POD_NAME" --ignore-not-found=true

echo "   Waiting for pod to be recreated..."
sleep 3
echo -e "${CMD}$ kubectl get pods -l app=nginx${NC}"
kubectl get pods -l app=nginx
echo ""

# Show pod age (new pod should be younger)
echo -e "${INFO}Step 8: Verify new pod was created...${NC}"
echo -e "${CMD}$ kubectl get pods -l app=nginx -o custom-columns='NAME:.metadata.name,AGE:.metadata.creationTimestamp'${NC}"
kubectl get pods -l app=nginx -o custom-columns='NAME:.metadata.name,AGE:.metadata.creationTimestamp'
echo ""

echo "==================================="
echo -e "${SUCCESS}Test Complete!${NC}"
echo "==================================="
echo ""
echo "Key concepts demonstrated:"
echo "  ✓ Deployment creates ReplicaSet"
echo "  ✓ ReplicaSet manages pod replicas"
echo "  ✓ Self-healing: deleted pod was automatically recreated"
echo "  ✓ Desired state: 3 replicas maintained"
echo ""
echo "Pod is still running. To clean up:"
echo -e "${CMD}$ kubectl delete -f 01-basic-deployment.yaml${NC}"
echo ""
echo "Or run: ./cleanup-all-deployments.sh"
echo ""
