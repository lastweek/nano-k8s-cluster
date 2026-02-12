#!/bin/bash
# Test script for GPU Node Selector (03-*.yaml)
#
# This script tests nodeSelector for scheduling to specific GPU types.

set -e

# Color codes
CMD='\033[0;36m'
SUCCESS='\033[0;32m'
ERROR='\033[0;31m'
INFO='\033[0;33m'
WARN='\033[0;35m'
NC='\033[0m'

echo -e "${INFO}===========================================${NC}"
echo -e "${INFO}GPU Node Selector Test${NC}"
echo -e "${INFO}===========================================${NC}"
echo ""
echo "This test demonstrates nodeSelector:"
echo "  ✓ Schedule to specific GPU types (H100, A100, L40S)"
echo "  ✓ Hard scheduling requirements"
echo "  ✓ Combine multiple node selectors"
echo ""

# Prerequisites check
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}Prerequisites Check${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if nodes are labeled
GPU_NODES=$(kubectl get nodes -l gpu.node=true -o name 2>/dev/null || echo "")
if [ -z "$GPU_NODES" ]; then
    echo -e "${WARN}⚠ No GPU nodes found${NC}"
    echo "Please run ./01-gpu-node-labeling.sh first"
    exit 1
fi

echo -e "${SUCCESS}✓ Found GPU nodes${NC}"
kubectl get nodes -l gpu.node=true
echo ""

# Ask user to label nodes with GPU types
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}Step 1: Label Nodes with GPU Types${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo "For testing, we need to label nodes with GPU types."
echo ""
echo "Example commands:"
echo "  kubectl label node <node-name> nvidia.com/gpu.product=H100"
echo "  kubectl label node <node-name> nvidia.com/gpu.product=A100-80GB"
echo "  kubectl label node <node-name> nvidia.com/gpu.product=L40S"
echo ""
echo "Your current GPU nodes:"
kubectl get nodes -l gpu.node=true -o custom-columns=NAME:.metadata.name,GPU:.metadata.labels.nvidia\.com/gpu\.product
echo ""

read -p "Have you labeled your nodes with GPU types? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Please label nodes first, then run this script again."
    exit 1
fi

# Deploy workloads
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}Step 2: Deploy GPU Workloads${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo "Deploying workloads with different GPU requirements..."
echo -e "${CMD}$ kubectl apply -f 03-gpu-node-selector.yaml${NC}"
kubectl apply -f 03-gpu-node-selector.yaml
echo ""

# Wait for pods to schedule (or get stuck)
echo "Waiting for pods to schedule..."
sleep 5
echo ""

# Show pod status
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}Step 3: Check Pod Scheduling${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo "All pods:"
echo -e "${CMD}$ kubectl get pods -l gpu-type -o wide${NC}"
kubectl get pods -l gpu-type -o wide 2>/dev/null || echo "No pods with GPU type labels found"
echo ""

# Show pending pods (if any)
PENDING_PODS=$(kubectl get pods -l gpu-type --field-selector=status.phase=Pending -o name 2>/dev/null || echo "")
if [ -n "$PENDING_PODS" ]; then
    echo -e "${WARN}⚠ Pending pods (no matching nodes):${NC}"
    kubectl get pods -l gpu-type --field-selector=status.phase=Pending
    echo ""
    echo "These pods are pending because no nodes match their GPU type requirement."
    echo ""
fi

# Show scheduled pods by GPU type
echo "Scheduled pods by GPU type:"
for GPU_TYPE in H100 A100 L40S; do
    echo ""
    echo -e "${INFO}$GPU_TYPE pods:${NC}"
    kubectl get pods -l gpu-type=$GPU_TYPE -o wide 2>/dev/null || echo "  None"
done
echo ""

# Show node distribution
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}Step 4: Node Distribution${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo "Pods grouped by node:"
kubectl get pods -l gpu-type -o wide --sort-by=.spec.nodeName | \
    awk 'NR==1 || last!=$7 {print ""; last=$7} {print}'

echo ""
echo ""
echo "┌───────────────────────────────────────────────────────────┐"
echo "│  How nodeSelector Works                                    │"
echo "│  ┌─────────────────────────────────────────────────────┐ │"
echo "│  │ 1. You label nodes:                                  │ │"
echo "│  │    kubectl label node node-1 nvidia.com/gpu.product=H100│ │"
echo "│  │                                                      │ │"
echo "│  │ 2. Pod specifies nodeSelector:                       │ │"
echo "│  │    nodeSelector:                                     │ │"
echo "│  │      nvidia.com/gpu.product: H100                    │ │"
echo "│  │                                                      │ │"
echo "│  │ 3. Scheduler ONLY considers matching nodes           │ │"
echo "│  │    → Pod goes to H100 nodes ONLY                     │ │"
echo "│  └─────────────────────────────────────────────────────┘ │"
echo "└───────────────────────────────────────────────────────────┘"
echo ""

# Summary
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  GPU Node Selector Test Complete!                          ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "You learned:"
echo "  ✓ How to use nodeSelector for hard requirements"
echo "  ✓ How to schedule to specific GPU types"
echo "  ✓ What happens when no matching nodes exist (Pending)"
echo "  ✓ How to combine multiple node selectors"
echo ""
echo "Next:"
echo "  → Try 04-pod-affinity-colocation.yaml for co-location"
echo ""
echo "To clean up:"
echo -e "${CMD}$ kubectl delete -f 03-gpu-node-selector.yaml${NC}"
echo ""
