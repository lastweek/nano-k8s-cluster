#!/bin/bash
# Test script for 04-update-strategies.yaml
#
# This script compares RollingUpdate vs Recreate strategies.

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
echo -e "${INFO}Script: 04-test-update-strategies.sh${NC}"
echo -e "${INFO}===================================${NC}"
echo ""
echo "==================================="
echo "Testing: Update Strategies (RollingUpdate vs Recreate)"
echo "==================================="
echo ""

# Apply both deployments
echo -e "${INFO}Step 1: Creating two deployments with different strategies...${NC}"
echo -e "${CMD}$ kubectl apply -f 04-update-strategies.yaml${NC}"
kubectl apply -f 04-update-strategies.yaml
echo ""

# Wait for both to be ready
echo -e "${INFO}Step 2: Waiting for deployments to be ready...${NC}"
kubectl rollout status deployment/nginx-rolling --timeout=60s > /dev/null &
kubectl rollout status deployment/nginx-recreate --timeout=60s > /dev/null &
wait
echo -e "${SUCCESS}   ✓ Both deployments ready${NC}"
echo ""

# Show both deployments
echo -e "${INFO}Step 3: Show both deployments...${NC}"
echo -e "${CMD}$ kubectl get deployments -l app=nginx${NC}"
kubectl get deployments -l app=nginx
echo ""

# Show strategy types
echo -e "${INFO}Step 4: Strategy comparison...${NC}"
echo ""
echo "RollingUpdate deployment:"
echo -e "${CMD}$ kubectl get deployment nginx-rolling -o jsonpath='{.spec.strategy.type}'${NC}"
STRATEGY1=$(kubectl get deployment nginx-rolling -o jsonpath='{.spec.strategy.type}')
echo "  Strategy: $STRATEGY1"
echo -e "${CMD}$ kubectl get deployment nginx-rolling -o jsonpath='{.spec.strategy.rollingUpdate.maxUnavailable}/{.spec.strategy.rollingUpdate.maxSurge}'${NC}"
kubectl get deployment nginx-rolling -o jsonpath='{.spec.strategy.rollingUpdate.maxUnavailable}/{.spec.strategy.rollingUpdate.maxSurge}'
echo ""

echo "Recreate deployment:"
echo -e "${CMD}$ kubectl get deployment nginx-recreate -o jsonpath='{.spec.strategy.type}'${NC}"
STRATEGY2=$(kubectl get deployment nginx-recreate -o jsonpath='{.spec.strategy.type}')
echo "  Strategy: $STRATEGY2"
echo "  All pods terminated before new pods start"
echo ""

# Demonstrate RollingUpdate update
echo -e "${INFO}Step 5: Demonstrating RollingUpdate update...${NC}"
echo "  Updating nginx-rolling to nginx:1.26..."
echo ""
echo -e "  ${CMD}$ kubectl set image deployment/nginx-rolling nginx=nginx:1.26${NC}"
kubectl set image deployment/nginx-rolling nginx=nginx:1.26 > /dev/null

echo "  Watching pods during rolling update:"
echo "  ${CMD}$ kubectl get pods -l strategy=rolling -w${NC}"
echo ""

# Run a background process to watch pods
(kubectl get pods -l strategy=rolling -w &
WATCH_PID=$!
sleep 5
kill $WATCH_PID 2>/dev/null || true) &

# Wait for rollout
kubectl rollout status deployment/nginx-rolling --timeout=60s > /dev/null
echo -e "${SUCCESS}  ✓ RollingUpdate: Zero downtime${NC}"
echo ""

# Show pods after update
echo -e "${CMD}$ kubectl get pods -l strategy=rolling -o custom-columns='NAME:.metadata.name,READY:.status.readyReplicas/.status.replicas,IMAGE:.spec.containers[0].image'${NC}"
kubectl get pods -l strategy=rolling -o custom-columns='NAME:.metadata.name,READY:.status.readyReplicas/.status.replicas,IMAGE:.spec.containers[0].image'
echo ""

# Demonstrate Recreate update
echo -e "${INFO}Step 6: Demonstrating Recreate update...${NC}"
echo "  Updating nginx-recreate to nginx:1.26..."
echo ""
echo -e "  ${CMD}$ kubectl set image deployment/nginx-recreate nginx=nginx:1.26${NC}"
kubectl set image deployment/nginx-recreate nginx=nginx:1.26 > /dev/null

echo "  Watching pods during recreate update:"
echo "  ${CMD}$ kubectl get pods -l strategy=recreate -w${NC}"
echo ""

# Run a background process to watch pods
(kubectl get pods -l strategy=recreate -w &
WATCH_PID=$!
sleep 5
kill $WATCH_PID 2>/dev/null || true) &

# Wait for rollout
kubectl rollout status deployment/nginx-recreate --timeout=60s > /dev/null
echo -e "${WARN}  ✓ Recreate: Brief downtime (all pods down at once)${NC}"
echo ""

# Show pods after update
echo -e "${CMD}$ kubectl get pods -l strategy=recreate -o custom-columns='NAME:.metadata.name,READY:.status.readyReplicas/.status.replicas,IMAGE:.spec.containers[0].image'${NC}"
kubectl get pods -l strategy=recreate -o custom-columns='NAME:.metadata.name,READY:.status.readyReplicas/.status.replicas,IMAGE:.spec.containers[0].image'
echo ""

# Comparison table
echo -e "${INFO}Step 7: Strategy comparison summary:${NC}"
echo ""
echo "┌─────────────┬────────────────────┬───────────────┬─────────────────┐"
echo "│ Strategy    │ Downtime          │ Speed         │ Use Case        │"
echo "├─────────────┼────────────────────┼───────────────┼─────────────────┤"
echo "│ RollingUpdate│ None (maxUnavailable: 0) │ Slower        │ Production      │"
echo "│ Recreate    │ Brief (all pods down)   │ Faster        │ Non-critical    │"
echo "└─────────────┴────────────────────┴───────────────┴─────────────────┘"
echo ""

echo -e "${INFO}Step 8: Rollback both deployments...${NC}"
kubectl rollout undo deployment/nginx-rolling > /dev/null
kubectl rollout undo deployment/nginx-recreate > /dev/null
echo -e "${SUCCESS}   ✓ Rollback complete${NC}"
echo ""

echo "==================================="
echo -e "${SUCCESS}Test Complete!${NC}"
echo "==================================="
echo ""
echo "Key concepts demonstrated:"
echo "  ✓ RollingUpdate: Zero downtime, gradual rollout"
echo "  ✓ Recreate: Brief downtime, faster rollout"
echo "  ✓ maxUnavailable: How many pods can be down"
echo "  ✓ maxSurge: How many extra pods during update"
echo ""
echo "For LLM serving:"
echo "  - Use RollingUpdate for production serving"
echo "  - maxUnavailable: 0 maintains availability"
echo "  - Recreate might work for non-critical batch jobs"
echo ""
echo "Pods are still running. To clean up:"
echo -e "${CMD}$ kubectl delete -f 04-update-strategies.yaml${NC}"
echo ""
echo "Or run: ./cleanup-all-deployments.sh"
echo ""
