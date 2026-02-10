#!/bin/bash
# Test script for 02-simple-operator.yaml
#
# This script demonstrates a simple operator.

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
echo -e "${INFO}Script: 02-test-operator.sh${NC}"
echo -e "${INFO}===================================${NC}"
echo ""
echo "==================================="
echo "Testing: Simple Operator"
echo "==================================="
echo ""

# Apply the operator
echo -e "${INFO}Step 1: Creating operator...${NC}"
echo -e "${CMD}$ kubectl apply -f 02-simple-operator.yaml${NC}"
kubectl apply -f 02-simple-operator.yaml
echo ""

# Wait for operator pod to start
echo -e "${INFO}Step 2: Waiting for operator to start...${NC}"
kubectl wait --for=condition=ready pod -l app=llm-operator --timeout=120s > /dev/null
echo -e "${SUCCESS}   ✓ Operator running${NC}"
echo ""

# Show operator pod
echo -e "${INFO}Step 3: Show operator pod...${NC}"
echo -e "${CMD}$ kubectl get pods -l app=llm-operator${NC}"
kubectl get pods -l app=llm-operator
echo ""

# Show operator logs
echo -e "${INFO}Step 4: Show operator logs...${NC}"
echo -e "${CMD}$ kubectl logs -l app=llm-operator --tail=30${NC}"
kubectl logs -l app=llm-operator --tail=30
echo ""

# Show LLMModel resource
echo -e "${INFO}Step 5: Show LLMModel resource...${NC}"
echo -e "${CMD}$ kubectl get llmmodel llama-3-70b-serving${NC}"
kubectl get llmmodel llama-3-70b-serving
echo ""

# Wait for deployment to be created
echo -e "${INFO}Step 6: Waiting for operator to create deployment...${NC}"
sleep 5
echo ""

# Show deployment created by operator
echo -e "${INFO}Step 7: Show deployment created by operator...${NC}"
echo -e "${CMD}$ kubectl get deployment llmmodel-llama-3-70b-serving${NC}"
kubectl get deployment llmmodel-llama-3-70b-serving
echo ""

# Show pods
echo -e "${INFO}Step 8: Show pods created by operator...${NC}"
echo -e "${CMD}$ kubectl get pods -l llmmodel=llama-3-70b-serving${NC}"
kubectl get pods -l llmmodel=llama-3-70b-serving
echo ""

# Show LLMModel status (updated by operator)
echo -e "${INFO}Step 9: Show LLMModel status (updated by operator)...${NC}"
echo -e "${CMD}$ kubectl get llmmodel llama-3-70b-serving -o jsonpath='{.status}'${NC}"
kubectl get llmmodel llama-3-70b-serving -o jsonpath='{.status}'
echo ""
echo ""

# Show full LLMModel YAML
echo -e "${INFO}Step 10: Show full LLMModel with status...${NC}"
echo -e "${CMD}$ kubectl get llmmodel llama-3-70b-serving -o yaml${NC}"
kubectl get llmmodel llama-3-70b-serving -o yaml
echo ""

# Explain what happened
echo -e "${INFO}Step 11: What just happened?${NC}"
echo ""
echo "  1. Operator pod started"
echo "  2. Operator watched for LLMModel resources"
echo "  3. Found llama-3-70b-serving"
echo "  4. Created deployment: llmmodel-llama-3-70b-serving"
echo "  5. Updated LLMModel status"
echo ""

# Show the reconciliation in action
echo -e "${INFO}Step 12: Reconciliation in action...${NC}"
echo "  Let's update the LLMModel replicas and watch the operator react"
echo ""
echo -e "${CMD}$ kubectl patch llmmodel llama-3-70b-serving -p '{\"spec\":{\"replicas\":3}}'${NC}"
kubectl patch llmmodel llama-3-70b-serving -p '{"spec":{"replicas":3}}' > /dev/null
echo ""
echo "  Waiting for operator to reconcile..."
sleep 5
echo ""
echo "  Deployment after reconciliation:"
echo -e "${CMD}$ kubectl get deployment llmmodel-llama-3-70b-serving${NC}"
kubectl get deployment llmmodel-llama-3-70b-serving
echo ""
echo -e "${SUCCESS}   ✓ Operator reconciled automatically!${NC}"
echo ""

# Show operator logs during reconciliation
echo -e "${INFO}Step 13: Operator logs showing reconciliation...${NC}"
echo -e "${CMD}$ kubectl logs -l app=llm-operator --tail=10${NC}"
kubectl logs -l app=llm-operator --tail=10
echo ""

# Explain the operator pattern
echo -e "${INFO}Step 14: The Operator Pattern${NC}"
echo ""
echo "  ┌────────────────────────────────────────────────────────────┐"
echo "  │  Control Loop (Reconciliation)                              │"
echo "  ├────────────────────────────────────────────────────────────┤"
echo "  │                                                             │"
echo "  │  while True:                                               │"
echo "  │      desired = get_llmmodel_spec()                         │"
echo "  │      actual = get_deployment_status()                      │"
echo "  │                                                             │"
echo "  │      if desired != actual:                                 │"
echo "  │          reconcile()                                       │"
echo "  │                                                             │"
echo "  │      sleep()                                               │"
echo "  │                                                             │"
echo "  └────────────────────────────────────────────────────────────┘"
echo ""
echo "  The operator:"
echo "    - Watches LLMModel resources (via Kubernetes watch API)"
echo "    - Compares desired state (spec) with actual state (deployment)"
echo "    - Takes action to make actual match desired"
echo "    - Updates status with current state"
echo "    - Runs continuously, always watching and fixing"
echo ""

# Compare with manual deployment
echo -e "${INFO}Step 15: CRD + Operator vs Manual Deployment${NC}"
echo ""
echo "  ❌ Manual (without CRD + Operator):"
echo "     kubectl create deployment llama ..."
echo "     kubectl scale deployment llama --replicas=3"
echo "     kubectl set image deployment llama ..."
echo "     (Repetitive, error-prone, yaml-heavy)"
echo ""
echo "  ✅ With CRD + Operator:"
echo "     kubectl apply -f model.yaml  # One simple spec!"
echo "     operator handles everything else"
echo "     (Declarative, consistent, self-healing)"
echo ""

echo "==================================="
echo -e "${SUCCESS}Test Complete!${NC}"
echo "==================================="
echo ""
echo "Key concepts demonstrated:"
echo "  ✓ CRD defines custom API"
echo "  ✓ Operator watches and reconciles"
echo "  ✓ Desired state (LLMModel spec) vs Actual state (Deployment)"
echo "  ✓ Continuous reconciliation loop"
echo "  ✓ Status updated by operator"
echo ""
echo "Why this matters for LLM serving:"
echo "  - NVIDIA Dynamo uses this exact pattern!"
echo "  - Define model deployment once (DynamoGraphDeployment)"
echo "  - Operator handles complexity (GPU scheduling, scaling, etc.)"
echo "  - Self-healing: operator fixes drift automatically"
echo ""
echo "Resources are still running. To clean up:"
echo -e "${CMD}$ kubectl delete -f 02-simple-operator.yaml${NC}"
echo ""
echo "Or run: ./cleanup-all-crd-operator.sh"
echo ""
