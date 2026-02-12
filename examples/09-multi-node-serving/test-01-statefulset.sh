#!/bin/bash
# Test script for Example 01: Basic StatefulSet

set -e

# Color codes
CMD='\033[0;36m'
SUCCESS='\033[0;32m'
ERROR='\033[0;31m'
INFO='\033[0;33m'
NC='\033[0m'

echo -e "${INFO}===========================================${NC}"
echo -e "${INFO}Test 01: Basic StatefulSet${NC}"
echo -e "${INFO}===========================================${NC}"
echo ""

echo "This test demonstrates:"
echo "  ✓ StatefulSet vs Deployment"
echo "  ✓ Stable pod identities"
echo "  ✓ Ordered startup"
echo ""

# Apply
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}Step 1: Deploy StatefulSet${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
kubectl apply -f 01-basic-statefulset.yaml
echo ""

# Watch startup
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}Step 2: Watch Ordered Startup${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Notice pods start ONE BY ONE (pod-0, then pod-1, then pod-2)"
echo "Press Ctrl+C after seeing all 3 pods are Ready"
echo ""
kubectl get pods -w -l app=llama-3-8b

echo ""
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}Step 3: Verify Pod Names${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Pod names have STABLE ORDINALS:"
kubectl get pods -l app=llama-3-8b -o custom-columns=NAME:.metadata.name

echo ""
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}Comparison: Deployment vs StatefulSet${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "┌───────────────────────────────────────────────────────────┐"
echo "│  Deployment:                                                  │"
echo "│  my-app-7d6f8b9c-xkp2z  ← Random hash                      │"
echo "│  my-app-7d6f8b9c-mn5qp  ← Random hash                      │"
echo "│                                                             │"
echo "│  If deleted: New random name (my-app-7d6f8b9c-xyz)      │"
echo "└───────────────────────────────────────────────────────────┘"
echo ""
echo "┌───────────────────────────────────────────────────────────┐"
echo "│  StatefulSet:                                                 │"
echo "│  llama-3-8b-0            ← Stable ordinal                  │"
echo "│  llama-3-8b-1            ← Stable ordinal                  │"
echo "│  llama-3-8b-2            ← Stable ordinal                  │"
echo "│                                                             │"
echo "│  If deleted: SAME NAME (llama-3-8b-1)                  │"
echo "└───────────────────────────────────────────────────────────┘"
echo ""

# Test DNS
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}Step 4: Test DNS Resolution${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Creating test pod to check DNS..."
kubectl run dns-test --image=nicolaka/netshoot --restart=Never --command -- sleep 3600 > /dev/null 2>&1 &
TEST_PID=$!

# Wait for test pod to be ready
echo "Waiting for test pod to be ready..."
kubectl wait --for=condition=ready pod/dns-test --timeout=60s

echo ""
echo "Testing DNS for each pod..."
for i in 0 1 2; do
  echo ""
  echo "Checking llama-3-8b-$i.llama-3-8b.default.svc.cluster.local:"
  kubectl exec dns-test -- nslookup llama-3-8b-$i.llama-3-8b.default.svc.cluster.local || true
done

# Clean up test pod
echo ""
echo "Cleaning up test pod..."
kubectl delete pod dns-test --ignore-not-found=true

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Test Complete!                                              ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "You learned:"
echo "  ✓ StatefulSet provides stable pod identities"
echo "  ✓ Pods start in order (not parallel)"
echo "  ✓ Each pod gets predictable DNS name"
echo "  ✓ This is critical for distributed systems!"
echo ""
echo "To clean up:"
echo -e "${CMD}kubectl delete -f 01-basic-statefulset.yaml${NC}"
echo ""
