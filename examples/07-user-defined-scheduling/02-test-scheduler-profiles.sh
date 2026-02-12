#!/bin/bash
# Test script for Scheduler Profiles (02-*.yaml)
#
# This script tests custom scheduler profiles using ConfigMaps.

set -e

# Color codes
CMD='\033[0;36m'
SUCCESS='\033[0;32m'
ERROR='\033[0;31m'
INFO='\033[0;33m'
WARN='\033[0;35m'
NC='\033[0m'

echo -e "${INFO}===========================================${NC}"
echo -e "${INFO}Scheduler Profiles Test${NC}"
echo -e "${INFO}===========================================${NC}"
echo ""
echo "This test demonstrates scheduler profiles:"
echo "  ✓ Multiple scheduler configurations"
echo "  ✓ Different scheduling strategies"
echo "  ✓ Profile selection via schedulerName"
echo ""

# Apply scheduler configuration
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}Step 1: Deploy Scheduler Configuration${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Creating scheduler ConfigMap..."
echo -e "${CMD}$ kubectl apply -f 02-scheduler-profile-configmap.yaml${NC}"
kubectl apply -f 02-scheduler-profile-configmap.yaml
echo ""

# Verify ConfigMap created
echo "Verifying ConfigMap..."
echo -e "${CMD}$ kubectl get configmap scheduler-config -n kube-system${NC}"
kubectl get configmap scheduler-config -n kube-system
echo ""

# Deploy test pods
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}Step 2: Deploy Test Pods${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo "Deploying pods with different scheduler profiles..."
echo "  - example-default-scheduler (default profile)"
echo "  - example-gpu-scheduler (binpack GPU profile)"
echo "  - example-spread-scheduler (spread HA profile)"
echo ""

# Wait for pods to schedule
echo "Waiting for pods to schedule..."
kubectl wait --for=condition=ready pod -l app=example-scheduler --timeout=120s 2>/dev/null || {
    echo -e "${WARN}Some pods may still be scheduling...${NC}"
}
echo ""

# Show scheduled pods
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}Step 3: Verify Pod Scheduling${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo "Pods and their schedulers:"
echo -e "${CMD}$ kubectl get pods -l app=example-scheduler -o wide${NC}"
kubectl get pods -l app=example-scheduler -o wide
echo ""

# Show scheduler profile assignment
echo "Scheduler profiles in use:"
echo -e "${CMD}$ kubectl get pods -l app=example-scheduler -o custom-columns=NAME:.metadata.name,SCHEDULER:.spec.schedulerName,NODE:.spec.nodeName${NC}"
kubectl get pods -l app=example-scheduler -o custom-columns=NAME:.metadata.name,SCHEDULER:.spec.schedulerName,NODE:.spec.nodeName
echo ""

# Explain scheduler strategies
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}Scheduler Strategy Comparison${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo "┌───────────────────────────────────────────────────────────┐"
echo "│  default-scheduler                                          │"
echo "│  Strategy: LeastAllocated                                   │"
echo "│  Goal: Balance resources across nodes                       │"
echo "│  Result: Spreads workload evenly                            │"
echo "└───────────────────────────────────────────────────────────┘"
echo ""
echo "┌───────────────────────────────────────────────────────────┐"
echo "│  gpu-scheduler                                              │"
echo "│  Strategy: MostAllocated (Binpack)                          │"
echo "│  Goal: Fill GPU nodes first                                 │"
echo "│  Result: Consolidates on fewer nodes                        │"
echo "└───────────────────────────────────────────────────────────┘"
echo ""
echo "┌───────────────────────────────────────────────────────────┐"
echo "│  spread-scheduler                                           │"
echo "│  Strategy: High topology spread weight                      │"
echo "│  Goal: Spread across zones/nodes                            │"
echo "│  Result: Maximum high availability                         │"
echo "└───────────────────────────────────────────────────────────┘"
echo ""

# Summary
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Scheduler Profiles Test Complete!                          ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "You learned:"
echo "  ✓ How to configure scheduler profiles"
echo "  ✓ Different scheduling strategies (binpack vs spread)"
echo "  ✓ How to specify schedulerName in pods"
echo "  ✓ How profiles affect scheduling decisions"
echo ""
echo "Next:"
echo "  → Try 03-gpu-node-selector.yaml for GPU-specific scheduling"
echo ""
echo "To clean up:"
echo -e "${CMD}$ kubectl delete -f 02-scheduler-profile-configmap.yaml${NC}"
echo ""
