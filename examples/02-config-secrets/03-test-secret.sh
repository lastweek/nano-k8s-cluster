#!/bin/bash
# Test script for 03-secret.yaml
#
# This script demonstrates basic Secret usage.

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
echo -e "${INFO}Script: 03-test-secret.sh${NC}"
echo -e "${INFO}===================================${NC}"
echo ""
echo "==================================="
echo "Testing: Secret (Basic)"
echo "==================================="
echo ""

# Apply the Secret and pod
echo -e "${INFO}Step 1: Creating Secret and pod...${NC}"
echo -e "${CMD}$ kubectl apply -f 03-secret.yaml${NC}"
kubectl apply -f 03-secret.yaml
echo ""

# Wait for pod to be ready
echo -e "${INFO}Step 2: Waiting for pod to be ready...${NC}"
kubectl wait --for=condition=ready pod/secret-demo --timeout=60s > /dev/null
echo -e "${SUCCESS}   ✓ Pod ready${NC}"
echo ""

# Show Secret (data is base64 encoded)
echo -e "${INFO}Step 3: Show Secret...${NC}"
echo -e "${CMD}$ kubectl get secret api-keys${NC}"
kubectl get secret api-keys
echo ""

# Show Secret details (encoded)
echo -e "${INFO}Step 4: Show Secret data (encoded)...${NC}"
echo -e "${CMD}$ kubectl describe secret api-keys${NC}"
kubectl describe secret api-keys
echo ""

# Show Secret in YAML format
echo -e "${INFO}Step 5: Show Secret YAML...${NC}"
echo -e "${CMD}$ kubectl get secret api-keys -o yaml${NC}"
kubectl get secret api-keys -o yaml
echo ""

# Decode and show Secret data
echo -e "${INFO}Step 6: Decode Secret data...${NC}"
echo ""
echo "  Decoding secret values (base64):"
echo ""
echo "  openai.api.key:"
echo -e "${CMD}$ kubectl get secret api-keys -o jsonpath='{.data.openai\.api\.key}' | base64 -d${NC}"
kubectl get secret api-keys -o jsonpath='{.data.openai\.api\.key}' | base64 -d
echo ""
echo "  huggingface.token:"
echo -e "${CMD}$ kubectl get secret api-keys -o jsonpath='{.data.huggingface\.token}' | base64 -d${NC}"
kubectl get secret api-keys -o jsonpath='{.data.huggingface\.token}' | base64 -d
echo ""
echo "  database.password:"
echo -e "${CMD}$ kubectl get secret api-keys -o jsonpath='{.data.database\.password}' | base64 -d${NC}"
kubectl get secret api-keys -o jsonpath='{.data.database\.password}' | base64 -d
echo ""

# Show pod
echo -e "${INFO}Step 7: Show pod...${NC}"
echo -e "${CMD}$ kubectl get pod secret-demo${NC}"
kubectl get pod secret-demo
echo ""

# Check environment variables in pod
echo -e "${INFO}Step 8: Check environment variables in pod...${NC}"
echo ""
echo "  API keys in pod environment:"
echo -e "${CMD}$ kubectl exec secret-demo -- env | grep -E 'API_KEY|TOKEN|PASSWORD'${NC}"
kubectl exec secret-demo -- env | grep -E 'API_KEY|TOKEN|PASSWORD'
echo ""

# Show that secrets are not visible in pod describe
echo -e "${INFO}Step 9: Secret values in pod spec...${NC}"
echo -e "${CMD}$ kubectl describe pod secret-demo | grep -A 10 'Environment:'${NC}"
kubectl describe pod secret-demo | grep -A 10 'Environment:' | head -20
echo ""
echo "  Note: Secret values are shown as references, not actual values"
echo ""

# Security warning
echo -e "${WARN}Step 10: Security considerations...${NC}"
echo ""
echo "  ⚠️  Secrets are base64 encoded, NOT encrypted!"
echo ""
echo "  Security best practices:"
echo "    1. Enable encryption at rest (EncryptionConfiguration)"
echo "    2. Use RBAC to control secret access"
echo "    3. Don't commit secrets to git"
echo "    4. Use external secret stores (Vault, AWS Secrets Manager)"
echo "    5. Rotate secrets regularly"
echo ""
echo "  Production options:"
echo "    - Sealed Secrets (bitnami-labs/sealed-secrets)"
echo "    - External Secrets Operator (external-secrets)"
echo "    - HashiCorp Vault integration"
echo "    - Cloud provider secret management"
echo ""

# Show secret types
echo -e "${INFO}Step 11: Secret types...${NC}"
echo ""
echo "  Common secret types:"
echo "    - Opaque: Arbitrary user data (default)"
echo "    - kubernetes.io/service-account-token: Service account tokens"
echo "    - kubernetes.io/dockercfg: Docker registry credentials"
echo "    - kubernetes.io/dockerconfigjson: Docker config.json"
echo "    - kubernetes.io/basic-auth: Basic authentication"
echo "    - kubernetes.io/ssh-auth: SSH authentication"
echo "    - kubernetes.io/tls: TLS certificate data"
echo "    - bootstrap.kubernetes.io/token: Bootstrap tokens"
echo ""

# Compare Secret vs ConfigMap
echo -e "${INFO}Step 12: Secret vs ConfigMap...${NC}"
echo ""
echo "  ┌──────────────┬─────────────────────┬─────────────────────┐"
echo "  │ Feature      │ ConfigMap           │ Secret              │"
echo "  ├──────────────┼─────────────────────┼─────────────────────┤"
echo "  │ Use case     │ Non-sensitive data  │ Sensitive data      │"
echo "  │ Encoding     │ Plain text          │ Base64              │"
echo "  │ Encryption   │ No                  │ Optional (at rest)  │"
echo "  │ Etcd storage │ Unencrypted         │ Can be encrypted    │"
echo "  │ RBAC         │ Less restricted     │ More restricted     │"
echo "  └──────────────┴─────────────────────┴─────────────────────┘"
echo ""

echo "==================================="
echo -e "${SUCCESS}Test Complete!${NC}"
echo "==================================="
echo ""
echo "Key concepts demonstrated:"
echo "  ✓ Secret stores sensitive data"
echo "  ✓ Secret as environment variables"
echo "  ✓ Secret data is base64 encoded (not encrypted by default)"
echo "  ✓ Need encryption at rest for production"
echo ""
echo "Why this matters for LLM serving:"
echo "  - Store API keys (OpenAI, Anthropic, HuggingFace)"
echo "  - Store database credentials"
echo "  - Store model API tokens"
echo "  - Store TLS certificates"
echo ""
echo "Pod and Secret are still running. To clean up:"
echo -e "${CMD}$ kubectl delete -f 03-secret.yaml${NC}"
echo ""
echo "Or run: ./cleanup-all-config-secrets.sh"
echo ""
