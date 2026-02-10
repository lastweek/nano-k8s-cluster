#!/bin/bash
# Test script for 02-configmap-from-file.yaml
#
# This script demonstrates ConfigMap mounted as files.

# Color codes
CMD='\033[0;36m'      # Cyan for commands
OUT='\033[0;37m'      # White for output
SUCCESS='\033[0;32m'   # Green for success
ERROR='\033[0;31m'     # Red for errors
INFO='\033[0;33m'      # Yellow for info
NC='\033[0m'           # No Color

set -e

# Show script filename
echo -e "${INFO}===================================${NC}"
echo -e "${INFO}Script: 02-test-configmap-from-file.sh${NC}"
echo -e "${INFO}===================================${NC}"
echo ""
echo "==================================="
echo "Testing: ConfigMap from File (Volume Mount)"
echo "==================================="
echo ""

# Apply the ConfigMap and pod
echo -e "${INFO}Step 1: Creating ConfigMap and pod...${NC}"
echo -e "${CMD}$ kubectl apply -f 02-configmap-from-file.yaml${NC}"
kubectl apply -f 02-configmap-from-file.yaml
echo ""

# Wait for pod to be ready
echo -e "${INFO}Step 2: Waiting for pod to be ready...${NC}"
kubectl wait --for=condition=ready pod/configmap-volume-demo --timeout=60s > /dev/null
echo -e "${SUCCESS}   ✓ Pod ready${NC}"
echo ""

# Show ConfigMap
echo -e "${INFO}Step 3: Show ConfigMap...${NC}"
echo -e "${CMD}$ kubectl get configmap app-config${NC}"
kubectl get configmap app-config
echo ""

# Show ConfigMap keys
echo -e "${INFO}Step 4: Show ConfigMap keys...${NC}"
echo -e "${CMD}$ kubectl get configmap app-config -o jsonpath='{.data}' | jq -r 'keys[]'${NC}"
kubectl get configmap app-config -o jsonpath='{.data}' | jq -r 'keys[]' 2>/dev/null || echo "  (jq not available, showing raw output)"
kubectl get configmap app-config -o jsonpath='{.data}' | grep -o '"[^"]*":' | tr -d '":'
echo ""

# List files in config directory
echo -e "${INFO}Step 5: List files in /etc/config directory...${NC}"
echo -e "${CMD}$ kubectl exec configmap-volume-demo -- ls -la /etc/config${NC}"
kubectl exec configmap-volume-demo -- ls -la /etc/config
echo ""

# Show file contents
echo -e "${INFO}Step 6: Show file contents...${NC}"
echo ""
echo "  app.conf:"
echo -e "${CMD}$ kubectl exec configmap-volume-demo -- cat /etc/config/app.conf${NC}"
kubectl exec configmap-volume-demo -- cat /etc/config/app.conf
echo ""
echo "  model_config.json:"
echo -e "${CMD}$ kubectl exec configmap-volume-demo -- cat /etc/config/model_config.json${NC}"
kubectl exec configmap-volume-demo -- cat /etc/config/model_config.json | jq . 2>/dev/null || kubectl exec configmap-volume-demo -- cat /etc/config/model_config.json
echo ""
echo "  prompt_template.txt:"
echo -e "${CMD}$ kubectl exec configmap-volume-demo -- cat /etc/config/prompt_template.txt${NC}"
kubectl exec configmap-volume-demo -- cat /etc/config/prompt_template.txt
echo ""

# Show file permissions
echo -e "${INFO}Step 7: Show file permissions...${NC}"
echo -e "${CMD}$ kubectl exec configmap-volume-demo -- ls -l /etc/config${NC}"
kubectl exec configmap-volume-demo -- ls -l /etc/config
echo ""
echo "  Files are read-only (0444) as configured"
echo ""

# Demonstrate hot reload capability
echo -e "${INFO}Step 8: Demonstrate ConfigMap update (hot reload)...${NC}"
echo "  Updating app.conf in ConfigMap..."
echo ""

# Update ConfigMap
kubectl patch configmap app-config --type merge -p '{"data":{"app.conf":"server_port=9090\nmax_connections=2000\nupdated=true"}}'

echo "  Waiting for update to propagate to pod..."
sleep 3

echo "  Updated file content:"
echo -e "${CMD}$ kubectl exec configmap-volume-demo -- cat /etc/config/app.conf${NC}"
kubectl exec configmap-volume-demo -- cat /etc/config/app.conf
echo ""
echo -e "${SUCCESS}   ✓ File updated without pod restart!${NC}"
echo ""

# Show environment variable from ConfigMap
echo -e "${INFO}Step 9: Environment variable from ConfigMap...${NC}"
echo -e "${CMD}$ kubectl exec configmap-volume-demo -- env | grep SERVER_PORT${NC}"
kubectl exec configmap-volume-demo -- env | grep SERVER_PORT || echo "  (not set, or shows old value since env vars don't update)"
echo ""
echo "  Note: Environment variables don't auto-update"
echo "  But file-based configs do!"
echo ""

# Show volume mount info
echo -e "${INFO}Step 10: Volume mount information...${NC}"
echo -e "${CMD}$ kubectl exec configmap-volume-demo -- mount | grep config${NC}"
kubectl exec configmap-volume-demo -- mount | grep config || echo "  (mount info not available)"
echo ""

# Show all ConfigMaps
echo -e "${INFO}Step 11: Show all ConfigMaps...${NC}"
echo -e "${CMD}$ kubectl get configmaps${NC}"
kubectl get configmaps
echo ""

echo "==================================="
echo -e "${SUCCESS}Test Complete!${NC}"
echo "==================================="
echo ""
echo "Key concepts demonstrated:"
echo "  ✓ ConfigMap from file data"
echo "  ✓ Mount ConfigMap as volume"
echo "  ✓ Files appear in container filesystem"
echo "  ✓ Hot reload: File updates propagate without restart"
echo ""
echo "Why this matters for LLM serving:"
echo "  - Store model config files (config.json, tokenizer_config.json)"
echo "  - Store prompt templates, system prompts"
echo "  - Update configuration without rebuilding images or restarting pods"
echo ""
echo "Comparison with env vars:"
echo "  - Env vars: Simple, but require restart to update"
echo "  - Volume mount: Files, support hot reload"
echo ""
echo "Pod and ConfigMap are still running. To clean up:"
echo -e "${CMD}$ kubectl delete -f 02-configmap-from-file.yaml${NC}"
echo ""
echo "Or run: ./cleanup-all-config-secrets.sh"
echo ""
