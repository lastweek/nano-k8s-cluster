#!/bin/bash
# Test script for Priority Classes (07-*.yaml)
#
# This script tests priority classes and preemption behavior.

set -e

# Color codes
CMD='\033[0;36m'
SUCCESS='\033[0;32m'
ERROR='\033[0;31m'
INFO='\033[0;33m'
WARN='\033[0;35m'
NC='\033[0m'

echo -e "${INFO}===========================================${NC}"
echo -e "${INFO}Priority Classes Test${NC}"
echo -e "${INFO}===========================================${NC}"
echo ""
echo "This test demonstrates priority classes:"
echo "  ✓ Create priority classes"
echo "  ✓ Assign priorities to pods"
echo "  ✓ Observe scheduling order"
echo "  ✓ Demonstrate preemption"
echo ""

# Deploy priority classes first
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}Step 1: Create Priority Classes${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo "Creating priority classes..."
echo -e "${CMD}$ kubectl apply -f 07-priority-classes.yaml --selector=\"kubernetes.io/meta.kind==PriorityClass\"${NC}"
# We'll apply everything, but focus on priority classes
kubectl apply -f 07-priority-classes.yaml
echo ""

# Show priority classes
echo "All priority classes:"
echo -e "${CMD}$ kubectl get priorityclasses${NC}"
kubectl get priorityclasses
echo ""

# Deploy workloads
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}Step 2: Deploy Workloads${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo "Deploying workloads with different priorities..."
echo "  - Critical production (priority: 1000)"
echo "  - Normal production (priority: 600)"
echo "  - Development (priority: 400)"
echo "  - Batch job (priority: 100)"
echo ""

# Wait a bit
sleep 3
echo ""

# Show pods with priorities
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}Step 3: Check Pod Priorities${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo "Pods sorted by priority:"
echo -e "${CMD}$ kubectl get pods -o custom-columns=NAME:.metadata.name,PRIORITY:.spec.priorityClassName,PHASE:.status.phase --sort-by=.spec.priorityClassName${NC}"
kubectl get pods -o custom-columns=NAME:.metadata.name,PRIORITY:.spec.priorityClassName,PHASE:.status.phase --sort-by=.spec.priorityClassName | grep -E 'NAME|production|development|batch|default'
echo ""

# Show detailed priority values
echo "Priority class values:"
kubectl get priorityclasses -o custom-columns=NAME:.metadata.name,VALUE:.value,DEFAULT:.globalDefault
echo ""

# Demo preemption scenario
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}Step 4: Preemption Demo${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo "Understanding preemption..."
echo ""
echo "┌───────────────────────────────────────────────────────────┐"
echo "│  Preemption Scenario                                      │"
echo "│  ┌─────────────────────────────────────────────────────┐ │"
echo "│  │ Scenario: Cluster full, high priority pod arrives   │ │"
echo "│  │                                                      │ │"
echo "│  │ Before:                                              │ │"
echo "│  │   [Batch Job - Priority 100] → GPU 1                │ │"
echo "│  │   [Batch Job - Priority 100] → GPU 2                │ │"
echo "│  │   [Dev Pod - Priority 400]    → GPU 3                │ │"
echo "│  │   [Normal Prod - Priority 600] → GPU 4               │ │"
echo "│  │                                                      │ │"
echo "│  │ Critical Prod (Priority 1000) arrives!               │ │"
echo "│  │           ↓                                          │ │"
echo "│  │ PREEMPTION: Lowest priority pods evicted              │ │"
echo "│  │           ↓                                          │ │"
echo "│  │ After:                                               │ │"
echo "│  │   [Batch Job] EVICTED! → (rescheduled later)         │ │"
echo "│  │   [Batch Job] EVICTED! → (rescheduled later)         │ │"
echo "│  │   [Critical Prod] → GPU 1 ✓                          │ │"
echo "│  │   [Critical Prod] → GPU 2 ✓                          │ │"
echo "│  └─────────────────────────────────────────────────────┘ │"
echo "└───────────────────────────────────────────────────────────┘"
echo ""

# Show pending pods (preemption in action)
PENDING=$(kubectl get pods --field-selector=status.phase=Pending -o name 2>/dev/null | wc -l)
if [ $PENDING -gt 0 ]; then
    echo "Pending pods (waiting for resources or preemption):"
    kubectl get pods --field-selector=status.phase=Pending
    echo ""
    echo "Check events for preemption:"
    kubectl get events --field-selectorreason=Preempting -o custom-columns=NAME:.metadata.message,TYPE:.type | tail -5
    echo ""
fi

# Show evicted pods
ELECTED=$(kubectl get pods --field-selector=status.phase=Failed -o jsonpath='{.items[*].status.containerStatuses[*].state.terminated.reason}' 2>/dev/null | grep -c "Evicted" || echo "0")
if [ $ELECTED -gt 0 ]; then
    echo -e "${WARN}⚠ Evicted pods (preempted):${NC}"
    kubectl get pods --field-selector=status.phase=Failed
    echo ""
fi

# Priority comparison
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}Priority Comparison${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo "Workload priority hierarchy:"
echo ""
echo "┌───────────────────────────────────────────────────────────┐"
echo "│  Production Critical (1000)                               │"
echo "│  └─ Never preempted, schedules first                      │"
echo "│                                                             │"
echo "│  Production Normal (600)                                   │"
echo "│  └─ Rarely preempted, only by critical                     │"
echo "│                                                             │"
echo "│  Development (400)                                         │"
echo "│  └─ Can be preempted by production                         │"
echo "│                                                             │"
echo "│  Batch Jobs (100)                                          │"
echo "│  └─ Always preemptible, lowest priority                    │"
echo "│                                                             │"
echo "│  Default (0)                                               │"
echo "│  └─ No explicit priority, goes last                        │"
echo "└───────────────────────────────────────────────────────────┘"
echo ""

# Summary
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Priority Classes Test Complete!                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "You learned:"
echo "  ✓ How to create priority classes"
echo "  ✓ How to assign priorities to pods"
echo "  ✓ How priority affects scheduling order"
echo "  ✓ How preemption works"
echo ""
echo "Next:"
echo "  → Try 08-llm-model-scheduling.yaml for complete example"
echo ""
echo "To clean up:"
echo -e "${CMD}$ kubectl delete -f 07-priority-classes.yaml${NC}"
echo ""
