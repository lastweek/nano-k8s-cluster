#!/bin/bash
# Test script for 01-what-is-crd.yaml
#
# This script demonstrates CRD basics following the gradual learning approach.
# See CRD-GUIDE.md for detailed explanation.

# Color codes
CMD='\033[0;36m'      # Cyan for commands
OUT='\033[0;37m'      # White for output
SUCCESS='\033[0;32m'   # Green for success
ERROR='\033[0;31m'     # Red for errors
INFO='\033[0;33m'      # Yellow for info
WARN='\033[0;35m'      # Magenta for warnings
NC='\033[0m'           # No Color

set -e

# ==============================================================================
# INTRODUCTION
# ==============================================================================

echo -e "${INFO}===========================================${NC}"
echo -e "${INFO}Script: 01-test-crd.sh${NC}"
echo -e "${INFO}===========================================${NC}"
echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║           LAYER 1: CRD - The Definition                       ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "In this script, you will learn:"
echo "  1. What a CRD is (and what it's NOT)"
echo "  2. How to define a custom API resource"
echo " 3. How to use kubectl with custom resources"
echo ""
echo "Key concept to remember:"
echo -e "${WARN}  CRD = API Definition (just a schema, NOTHING runs yet)${NC}"
echo ""

# ==============================================================================
# STEP 1: Understanding what we're about to create
# ==============================================================================

echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}STEP 1: Understanding the CRD Concept${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Think of a CRD like a CLASS definition in programming:"
echo ""
echo "  ╔═══════════════════════════════════════════════════════════╗"
echo "  ║  CRD defines:                                            ║"
echo "  ║    - What fields exist (modelName, replicas, gpuType)    ║"
echo "  ║    - What types they are (string, integer, boolean)      ║"
echo "  ║    - Validation rules (min: 1, default: A100)            ║"
echo "  ╠═══════════════════════════════════════════════════════════╣"
echo "  ║  Like a Python class:                                     ║"
echo "  ║    class LLMModel:                                        ║"
echo "  ║        def __init__(self, modelName, replicas, gpuType)  ║"
echo "  ║            ...                                            ║"
echo "  ╚═══════════════════════════════════════════════════════════╝"
echo ""
echo "Press Enter to continue..."
read

# ==============================================================================
# STEP 2: Creating the CRD
# ==============================================================================

echo ""
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}STEP 2: Creating the CRD${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Running:"
echo -e "${CMD}$ kubectl apply -f 01-what-is-crd.yaml${NC}"
echo ""
kubectl apply -f 01-what-is-crd.yaml
echo ""

# Wait for CRD to be ready
echo -e "${INFO}Waiting for CRD to be ready...${NC}"
sleep 3
echo -e "${SUCCESS}✓ CRD created successfully!${NC}"
echo ""

# ==============================================================================
# STEP 3: Verifying the CRD exists
# ==============================================================================

echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}STEP 3: Verifying the CRD${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Let's see our new CRD in the cluster:"
echo ""
echo -e "${CMD}$ kubectl get crd llmmodels.ai.example.com${NC}"
kubectl get crd llmmodels.ai.example.com
echo ""

echo "Also notice it in the list of all CRDs:"
echo ""
echo -e "${CMD}$ kubectl get crds${NC}"
kubectl get crds
echo ""

echo -e "${SUCCESS}✓ Our CRD 'llmmodels.ai.example.com' is now in Kubernetes!${NC}"
echo ""

# ==============================================================================
# STEP 4: Examining the CRD structure
# ==============================================================================

echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}STEP 4: Examining the CRD Structure${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Let's look at the detailed information:"
echo ""
echo -e "${CMD}$ kubectl describe crd llmmodels.ai.example.com${NC}"
kubectl describe crd llmmodels.ai.example.com | head -50
echo ""
echo "...(output truncated)"
echo ""

# ==============================================================================
# STEP 5: Understanding the API extension
# ==============================================================================

echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}STEP 5: Understanding the API Extension${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "The CRD extended the Kubernetes API! You can now use:"
echo ""
echo -e "${CMD}$ kubectl api-resources | grep llmmodel${NC}"
kubectl api-resources | grep llmmodel
echo ""
echo "This means you can now use kubectl commands like:"
echo "  • kubectl get llmmodels"
echo "  • kubectl get llm        (short name)"
echo "  • kubectl describe llmmodel <name>"
echo "  • kubectl delete llmmodel <name>"
echo ""

# ==============================================================================
# STEP 6: Creating an instance (Layer 2)
# ==============================================================================

echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}STEP 6: Creating an Instance (Layer 2)${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Now we'll create an INSTANCE of our CRD."
echo ""
echo "Think of it like creating an object from a class:"
echo ""
echo "  ╔═══════════════════════════════════════════════════════════╗"
echo "  ║  CRD (Class):                                             ║"
echo "  ║    class LLMModel: ...                                    ║"
echo "  ╠═══════════════════════════════════════════════════════════╣"
echo "  ║  Instance (Object):                                        ║"
echo "  ║    my_model = LLMModel(                                   ║"
echo "  ║        modelName='llama-3-70b',                           ║"
echo "  ║        replicas=3,                                        ║"
echo "  ║        gpuType='H100'                                     ║"
echo "  ║    )                                                      ║"
echo "  ╚═══════════════════════════════════════════════════════════╝"
echo ""

cat > /tmp/my-llm-model.yaml <<EOF
apiVersion: ai.example.com/v1
kind: LLMModel
metadata:
  name: llama-3-70b-serving
spec:
  modelName: llama-3-70b
  modelPath: /models/llama-3-70b
  replicas: 3
  gpuType: H100
  gpuMemory: 80Gi
  maxTokens: 4096
  temperature: 0.7
  enableStreaming: true
  enableCache: true
EOF

echo "Here's the YAML we're applying:"
cat /tmp/my-llm-model.yaml
echo ""
echo "Creating the instance:"
echo -e "${CMD}$ kubectl apply -f /tmp/my-llm-model.yaml${NC}"
kubectl apply -f /tmp/my-llm-model.yaml
echo ""
echo -e "${SUCCESS}✓ LLMModel resource created!${NC}"
echo ""

# ==============================================================================
# STEP 7: Viewing the instance
# ==============================================================================

echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}STEP 7: Viewing the Instance${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "List all LLMModel resources:"
echo -e "${CMD}$ kubectl get llmmodels${NC}"
kubectl get llmmodels
echo ""

echo "Get details of our specific resource:"
echo -e "${CMD}$ kubectl get llmmodel llama-3-70b-serving${NC}"
kubectl get llmmodel llama-3-70b-serving
echo ""

# ==============================================================================
# STEP 8: Understanding what's NOT happening
# ==============================================================================

echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}STEP 8: The Important Part - What's NOT Happening${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${WARN}❗ CRUCIAL UNDERSTANDING ❗${NC}"
echo ""
echo "Let's check if anything is actually RUNNING:"
echo ""
echo -e "${CMD}$ kubectl get deployments${NC}"
kubectl get deployments 2>&1 | grep -v "No resources" || echo "  (No deployments found)"
echo ""

echo -e "${CMD}$ kubectl get pods${NC}"
kubectl get pods 2>&1 | grep -v "No resources" || echo "  (No pods found)"
echo ""

echo -e "${ERROR}❌ NO CONTAINERS ARE RUNNING!${NC}"
echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Remember:                                                    ║"
echo "║                                                               ║"
echo "║  Layer 1: CRD (Definition)  ✅ DONE                           ║"
echo "║    - Defines the schema                                       ║"
echo "║    - Stored in Kubernetes API                                 ║"
echo "║    - NOTHING runs                                             ║"
echo "║                                                               ║"
echo "║  Layer 2: Instance (Data)  ✅ DONE                            ║"
echo "║    - Your YAML file                                          ║"
echo "║    - Stored in etcd                                           ║"
echo "║    - STILL nothing runs                                       ║"
echo "║                                                               ║"
echo "║  Layer 3: Operator (Engine)  ❌ NOT YET                       ║"
echo "║    - Watches for instances                                    ║"
echo "║    - Creates actual deployments/pods                          ║"
echo "║    - THIS is where containers get created                     ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# ==============================================================================
# ANALOGY
# ==============================================================================

echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}ANALOGY: The Restaurant Order${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Think of it like a restaurant:"
echo ""
echo "  ┌──────────────────────────────────────────────────────────┐"
echo "  │  CRD = The menu format                                   │"
echo "  │    \"We serve: burgers, fries, drinks\"                   │"
echo "  │    (Just defines what's possible)                        │"
echo "  ├──────────────────────────────────────────────────────────┤"
echo "  │  LLMModel instance = Your order ticket                   │"
echo "  │    \"Table 5: 1 burger, 2 fries, 1 coke\"                │"
echo "  │    (Just data, written on paper)                         │"
echo "  ├──────────────────────────────────────────────────────────┤"
echo "  │  Operator = The chef                                     │"
echo "  │    Reads the ticket and COOKS THE FOOD                  │"
echo "  │    (Actually makes things happen!)                       │"
echo "  └──────────────────────────────────────────────────────────┘"
echo ""
echo "Right now, we have:"
echo "  ✅ Menu (CRD)"
echo "  ✅ Order ticket (LLMModel)"
echo "  ❌ Chef (Operator) ← This is why nothing is cooking!"
echo ""

# ==============================================================================
# SUMMARY
# ==============================================================================

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                       SUMMARY                                ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "You learned:"
echo ""
echo "  ✓ CRD extends Kubernetes API with new resource types"
echo "  ✓ CRD is just a schema definition (like a class)"
echo "  ✓ You can create instances of the CRD"
echo "  ✓ CRD + Instance = Still NO containers running"
echo ""
echo -e "${WARN}Key takeaway:${NC}"
echo "  CRDs do NOT create containers. Operators do!"
echo ""
echo "Next steps:"
echo "  → Run: ./02-test-operator.sh"
echo "  → This deploys the operator that will CREATE CONTAINERS"
echo ""

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Test Complete!                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "To clean up:"
echo -e "${CMD}$ kubectl delete -f 01-what-is-crd.yaml${NC}"
echo -e "${CMD}$ kubectl delete -f /tmp/my-llm-model.yaml${NC}"
echo ""
echo "Or run: ./cleanup-all-crd-operator.sh"
echo ""
