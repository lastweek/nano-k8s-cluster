#!/bin/bash
# Test script for Taints and Tolerations (06-*.yaml)
#
# This script tests taints and tolerations for dedicating nodes to specific workloads.

set -e

# Color codes
CMD='\033[0;36m'
SUCCESS='\033[0;32m'
ERROR='\033[0;31m'
INFO='\033[0;33m'
WARN='\033[0;35m'
NC='\033[0m'

echo -e "${INFO}===========================================${NC}"
echo -e "${INFO}Taints and Tolerations Test${NC}"
echo -e "${INFO}===========================================${NC}"
echo ""
echo "This test demonstrates taints and tolerations:"
echo "  ✓ Dedicate nodes to specific workloads"
echo "  ✓ NoSchedule vs NoExecute effects"
echo "  ✓ Exclude unwanted pods from nodes"
echo ""

# Select a node to taint
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}Step 1: Select and Taint a Node${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo "Available nodes:"
kubectl get nodes
echo ""

echo "Enter the name of a node to taint (or press Enter to skip tainting):"
read TEST_NODE

if [ -n "$TEST_NODE" ]; then
    # Verify node exists
    if ! kubectl get node $TEST_NODE &>/dev/null; then
        echo -e "${ERROR}✗ Node $TEST_NODE not found${NC}"
        exit 1
    fi

    echo ""
    echo "Tainting node: $TEST_NODE"
    echo -e "${CMD}$ kubectl taint nodes $TEST_NODE gpu-only=true:NoSchedule${NC}"
    kubectl taint nodes $TEST_NODE gpu-only=true:NoSchedule
    echo -e "${SUCCESS}✓ Node tainted${NC}"
    echo ""
else
    echo "Skipping node tainting. Make sure you have tainted nodes already."
fi

# Deploy workloads
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}Step 2: Deploy Workloads${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo "Deploying workloads with tolerations..."
echo -e "${CMD}$ kubectl apply -f 06-taints-tolerations-dedicated-nodes.yaml${NC}"
kubectl apply -f 06-taints-tolerations-dedicated-nodes.yaml
echo ""

# Wait for scheduling
echo "Waiting for pods to schedule..."
sleep 5
echo ""

# Show all pods
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}Step 3: Check Scheduling${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo "All pods:"
echo -e "${CMD}$ kubectl get pods -l 'app in (gpu-model-serving,dev-model)' -o wide${NC}"
kubectl get pods -l 'app in (gpu-model-serving,dev-model)' -o wide 2>/dev/null || true
echo ""

# Check taints on nodes
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}Step 4: Verify Taints${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo "Node taints:"
echo -e "${CMD}$ kubectl describe nodes | grep -A 3 \"Taints:\"${NC}"
kubectl describe nodes | grep -A 3 "Taints:"
echo ""

# Show pod tolerations
echo "Pod tolerations:"
echo ""
echo "GPU model serving tolerations:"
kubectl get pod -l app=gpu-model-serving -o jsonpath='{.items[0].spec.tolerations}' 2>/dev/null | jq '.' || echo "  (pod not found)"
echo ""

echo "Dev model tolerations (none - should not schedule to tainted nodes):"
kubectl get pod -l app=dev-model -o jsonpath='{.items[0].spec.tolerations}' 2>/dev/null | jq '.' || echo "  (pod not found)"
echo ""

# Check if dev pods are on tainted nodes
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}Step 5: Verify Isolation${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ -n "$TEST_NODE" ]; then
    echo "Checking if dev pods scheduled to tainted node ($TEST_NODE)..."
    DEV_ON_TAINTED=$(kubectl get pods -l app=dev-model -o wide | grep $TEST_NODE | wc -l)
    if [ $DEV_ON_TAINTED -eq 0 ]; then
        echo -e "${SUCCESS}✓ Dev pods correctly excluded from tainted node${NC}"
    else
        echo -e "${WARN}⚠ Dev pods found on tainted node!${NC}"
    fi
    echo ""

    echo "Checking if GPU pods on tainted node ($TEST_NODE)..."
    GPU_ON_TAINTED=$(kubectl get pods -l app=gpu-model-serving -o wide | grep $TEST_NODE | wc -l)
    if [ $GPU_ON_TAINTED -gt 0 ]; then
        echo -e "${SUCCESS}✓ GPU pods correctly scheduled to tainted node${NC}"
    else
        echo -e "${INFO}No GPU pods on tainted node (may not have toleration or not scheduled)${NC}"
    fi
    echo ""
fi

# Show pending pods
PENDING=$(kubectl get pods --field-selector=status.phase=Pending -o name | wc -l)
if [ $PENDING -gt 0 ]; then
    echo -e "${WARN}⚠ Pending pods (cannot schedule - no untainted nodes):${NC}"
    kubectl get pods --field-selector=status.phase=Pending
    echo ""
fi

echo "┌───────────────────────────────────────────────────────────┐"
echo "│  Taints and Tolerations Explained                          │"
echo "│  ┌─────────────────────────────────────────────────────┐ │"
echo "│  │ 1. Taint the node:                                   │ │"
echo "│  │    kubectl taint nodes node-1 gpu-only:NoSchedule   │ │"
echo "│  │    → Node now has a \"repelling force\"              │ │"
echo "│  │                                                      │ │"
echo "│  │ 2. Pod WITHOUT toleration:                           │ │"
echo "│  │    → Sees taint → \"Can't go here!\"                 │ │"
echo "│  │    → Tries next node                                 │ │"
echo "│  │                                                      │ │"
echo "│  │ 3. Pod WITH toleration:                              │ │"
echo "│  │    → Sees taint → \"I'm allowed!\"                   │ │"
echo "│  │    → Schedules to tainted node                       │ │"
echo "│  └─────────────────────────────────────────────────────┘ │"
echo "└───────────────────────────────────────────────────────────┘"
echo ""

# Summary
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Taints and Tolerations Test Complete!                      ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "You learned:"
echo "  ✓ How to taint nodes"
echo "  ✓ How to tolerate taints"
echo "  ✓ How to dedicate nodes to specific workloads"
echo "  ✓ NoSchedule vs NoExecute effects"
echo ""
echo "To remove taint:"
if [ -n "$TEST_NODE" ]; then
    echo -e "${CMD}$ kubectl taint nodes $TEST_NODE gpu-only=true:NoSchedule-${NC}"
fi
echo ""
echo "To clean up workloads:"
echo -e "${CMD}$ kubectl delete -f 06-taints-tolerations-dedicated-nodes.yaml${NC}"
echo ""
