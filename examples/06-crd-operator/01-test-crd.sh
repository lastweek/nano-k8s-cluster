#!/bin/bash
# Test script for 01-what-is-crd.yaml
#
# This script demonstrates CRD basics.

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
echo -e "${INFO}Script: 01-test-crd.sh${NC}"
echo -e "${INFO}===================================${NC}"
echo ""
echo "==================================="
echo "Testing: Custom Resource Definition"
echo "==================================="
echo ""

# Create the CRD
echo -e "${INFO}Step 1: Creating CRD...${NC}"
echo -e "${CMD}$ kubectl apply -f 01-what-is-crd.yaml${NC}"
kubectl apply -f 01-what-is-crd.yaml
echo ""

# Wait for CRD to be ready
echo -e "${INFO}Step 2: Waiting for CRD to be ready...${NC}"
sleep 3
echo -e "${SUCCESS}   ✓ CRD created${NC}"
echo ""

# Show the CRD
echo -e "${INFO}Step 3: Show CRD...${NC}"
echo -e "${CMD}$ kubectl get crd llmmodels.ai.example.com${NC}"
kubectl get crd llmmodels.ai.example.com
echo ""

# Show CRD details
echo -e "${INFO}Step 4: Show CRD details...${NC}"
echo -e "${CMD}$ kubectl describe crd llmmodels.ai.example.com${NC}"
kubectl describe crd llmmodels.ai.example.com | head -40
echo ""

# Show all CRDs
echo -e "${INFO}Step 5: Show all CRDs in cluster...${NC}"
echo -e "${CMD}$ kubectl get crds${NC}"
kubectl get crds
echo ""

echo "  Notice our new CRD: llmmodels.ai.example.com"
echo ""

# Test the new API
echo -e "${INFO}Step 6: Test the new API endpoint...${NC}"
echo "  Available API endpoints:"
echo -e "${CMD}$ kubectl api-resources | grep llmmodel${NC}"
kubectl api-resources | grep llmmodel
echo ""

echo "  You can now use:"
echo "    kubectl get llmmodels"
echo "    kubectl get llm"
echo "    kubectl api-resources | grep llmmodel"
echo ""

# Create an instance of our custom resource
echo -e "${INFO}Step 7: Create an instance of LLMModel...${NC}"
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

echo "  Creating LLMModel instance:"
echo -e "${CMD}$ kubectl apply -f /tmp/my-llm-model.yaml${NC}"
kubectl apply -f /tmp/my-llm-model.yaml
echo ""

# List our custom resources
echo -e "${INFO}Step 8: List LLMModel resources...${NC}"
echo -e "${CMD}$ kubectl get llmmodels${NC}"
kubectl get llmmodels
echo ""

# Show our resource
echo -e "${INFO}Step 9: Show LLMModel details...${NC}"
echo -e "${CMD}$ kubectl describe llmmodel llama-3-70b-serving${NC}"
kubectl describe llmmodel llama-3-70b-serving
echo ""

# Show in YAML format
echo -e "${INFO}Step 10: Show LLMModel as YAML...${NC}"
echo -e "${CMD}$ kubectl get llmmodel llama-3-70b-serving -o yaml${NC}"
kubectl get llmmodel llama-3-70b-serving -o yaml
echo ""

# Explain the difference
echo -e "${INFO}Step 11: CRD vs Instance...${NC}"
echo ""
echo "  CRD (Definition):"
echo "    - Defines the schema/structure"
echo "    - Like a class in OOP"
echo "    - Created once"
echo ""
echo "  LLMModel (Instance):"
echo "    - Actual resource using the CRD"
echo "    - Like an object in OOP"
echo "    - Can create many instances"
echo ""

# Show what's missing (the operator!)
echo -e "${INFO}Step 12: What happens next?${NC}"
echo ""
echo "  Current state:"
echo "    - ✅ CRD created (API is extended)"
echo "    - ✅ LLMModel resource created"
echo "    - ❌ No operator running"
echo ""
echo "  Without an operator:"
echo "    - Resource sits in etcd"
echo "    - Nothing happens automatically"
echo "    - No deployments created"
echo "    - No pods started"
echo ""
echo "  With an operator:"
echo "    - Operator watches LLMModel resources"
echo "    - Creates deployments automatically"
echo "    - Manages the lifecycle"
echo "    - Updates status based on actual state"
echo ""
echo "  Next: See 02-simple-operator.yaml for the operator!"
echo ""

echo "==================================="
echo -e "${SUCCESS}Test Complete!${NC}"
echo "==================================="
echo ""
echo "Key concepts demonstrated:"
echo "  ✓ CRD extends Kubernetes API"
echo "  ✓ Define custom resources with schema"
echo "  ✓ Use kubectl to manage custom resources"
echo "  ✓ CRD alone doesn't DO anything (need operator)"
echo ""
echo "Why this matters for LLM serving:"
echo "  - Create domain-specific APIs (ModelDeployment, TrainingJob)"
echo "  - Use kubectl to deploy models like: kubectl apply -f model.yaml"
echo "  - Operators automate the complex parts"
echo "  - NVIDIA Dynamo uses CRDs + Operator pattern"
echo ""
echo "CRD and LLMModel resource are still running. To clean up:"
echo -e "${CMD}$ kubectl delete -f 01-what-is-crd.yaml${NC}"
echo -e "${CMD}$ kubectl delete -f /tmp/my-llm-model.yaml${NC}"
echo ""
echo "Or run: ./cleanup-all-crd-operator.sh"
echo ""
