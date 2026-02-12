#!/bin/bash
# Test script for Pod Anti-Affinity (05-*.yaml)
#
# This script tests pod anti-affinity for spreading pods across nodes.

set -e

# Color codes
CMD='\033[0;36m'
SUCCESS='\033[0;32m'
ERROR='\033[0;31m'
INFO='\033[0;33m'
WARN='\033[0;35m'
NC='\033[0m'

echo -e "${INFO}===========================================${NC}"
echo -e "${INFO}Pod Anti-Affinity Spreading Test${NC}"
echo -e "${INFO}===========================================${NC}"
echo ""
echo "This test demonstrates pod anti-affinity:"
echo "  ✓ Spread pods across different nodes"
echo "  ✓ High availability pattern"
echo "  ✓ Zone-aware spreading"
echo ""

# Check node count
NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
echo -e "${INFO}Available nodes: $NODE_COUNT${NC}"
if [ $NODE_COUNT -lt 2 ]; then
    echo -e "${WARN}⚠ Warning: You have less than 2 nodes${NC}"
    echo "Anti-affinity works best with multiple nodes."
fi
echo ""

# Deploy workloads
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}Step 1: Deploy Workloads${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo "Deploying pods with anti-affinity..."
echo -e "${CMD}$ kubectl apply -f 05-pod-anti-affinity-spreading.yaml${NC}"
kubectl apply -f 05-pod-anti-affinity-spreading.yaml
echo ""

# Wait for pods
echo "Waiting for pods to schedule..."
sleep 5
echo ""

# Show pod distribution
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}Step 2: Verify Pod Distribution${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo "HA model pods (should be on different nodes):"
echo -e "${CMD}$ kubectl get pods -l app=model-server-ha -o wide${NC}"
kubectl get pods -l app=model-server-ha -o wide
echo ""

# Check distribution by node
echo "Distribution by node:"
kubectl get pods -l app=model-server-ha -o wide | awk 'NR>1 {print $7}' | sort | uniq -c
echo ""

# Verify spreading
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}Step 3: Verify Spreading${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

NODES_USED=$(kubectl get pods -l app=model-server-ha -o wide | awk 'NR>1 {print $7}' | sort -u | wc -l)
PODS_RUNNING=$(kubectl get pods -l app=model-server-ha --field-selector=status.phase=Running -o name | wc -l)

echo "Pods running: $PODS_RUNNING"
echo "Unique nodes used: $NODES_USED"
echo ""

if [ $PODS_RUNNING -eq $NODES_USED ]; then
    echo -e "${SUCCESS}✓ Perfect spread! Each pod on different node${NC}"
else
    echo -e "${INFO}Pod distribution:${NC}"
    kubectl get pods -l app=model-server-ha -o wide | awk 'NR>1 {print $1 " → " $7}'
fi
echo ""

# Show pending pods
PENDING=$(kubectl get pods -l app=model-server-ha --field-selector=status.phase=Pending -o name | wc -l)
if [ $PENDING -gt 0 ]; then
    echo -e "${WARN}⚠ $PENDING pod(s) pending${NC}"
    echo "This is normal with hard anti-affinity when replicas > nodes"
    echo ""
fi

# Show anti-affinity configuration
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}Anti-Affinity Configuration${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

kubectl get deployment model-server-ha -o jsonpath='{.spec.template.spec.affinity}' | jq '.podAntiAffinity'
echo ""

echo "┌───────────────────────────────────────────────────────────┐"
echo "│  Pod Anti-Affinity Explained                               │"
echo "│  ┌─────────────────────────────────────────────────────┐ │"
echo "│  │ WITHOUT anti-affinity:                               │ │"
echo "│  │   Node 1: [Pod A, Pod B, Pod C]  ← Single point!    │ │"
echo "│  │   Node 2: [Pod D]                                    │ │"
echo "│  │                                                      │ │"
echo "│  │ WITH anti-affinity:                                   │ │"
echo "│  │   Node 1: [Pod A]                                    │ │"
echo "│  │   Node 2: [Pod B]                                    │ │"
echo "│  │   Node 3: [Pod C]  ← Survive node failures!         │ │"
echo "│  │   Node 4: [Pod D]                                    │ │"
echo "│  └─────────────────────────────────────────────────────┘ │"
echo "└───────────────────────────────────────────────────────────┘"
echo ""

# Demo: What happens with soft anti-affinity
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}Step 4: Soft vs Hard Anti-Affinity${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo "Soft anti-affinity (prefer-spread):"
echo -e "${CMD}$ kubectl get pods -l app=model-server-prefer-spread -o wide | head -10${NC}"
kubectl get pods -l app=model-server-prefer-spread -o wide | head -10
echo ""

PODS_PER_NODE=$(kubectl get pods -l app=model-server-prefer-spread -o wide | awk 'NR>1 {print $7}' | sort | uniq -c | head -1 | awk '{print $1}')
echo "Max pods per node (soft anti-affinity allows stacking): $PODS_PER_NODE"
echo ""

# Summary
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Pod Anti-Affinity Test Complete!                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "You learned:"
echo "  ✓ How to use podAntiAffinity for spreading"
echo "  ✓ Hard vs soft anti-affinity"
echo "  ✓ High availability pattern"
echo "  ✓ What happens when replicas > nodes (hard: pending, soft: stack)"
echo ""
echo "Next:"
echo "  → Try 06-taints-tolerations-dedicated-nodes.yaml for node isolation"
echo ""
echo "To clean up:"
echo -e "${CMD}$ kubectl delete -f 05-pod-anti-affinity-spreading.yaml${NC}"
echo ""
