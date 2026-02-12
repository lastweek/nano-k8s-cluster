#!/bin/bash
# Test script for Pod Affinity (04-*.yaml)
#
# This script tests pod affinity for co-locating pods on the same node.

set -e

# Color codes
CMD='\033[0;36m'
SUCCESS='\033[0;32m'
ERROR='\033[0;31m'
INFO='\033[0;33m'
WARN='\033[0;35m'
NC='\033[0m'

echo -e "${INFO}===========================================${NC}"
echo -e "${INFO}Pod Affinity Co-location Test${NC}"
echo -e "${INFO}===========================================${NC}"
echo ""
echo "This test demonstrates pod affinity:"
echo "  ✓ Co-locate pods on same node"
echo "  ✓ Model server + cache co-location"
echo "  ✓ Hard vs soft affinity requirements"
echo ""

# Deploy workloads
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}Step 1: Deploy Workloads${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo "Deploying cache + model servers with affinity..."
echo -e "${CMD}$ kubectl apply -f 04-pod-affinity-colocation.yaml${NC}"
kubectl apply -f 04-pod-affinity-colocation.yaml
echo ""

# Wait for pods to be ready
echo "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=redis-cache --timeout=60s 2>/dev/null || true
kubectl wait --for=condition=ready pod -l app=model-server-with-cache --timeout=90s 2>/dev/null || true
echo ""

# Show pod distribution
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}Step 2: Verify Co-location${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo "All pods with nodes:"
echo -e "${CMD}$ kubectl get pods -l 'app in (redis-cache,model-server-with-cache)' -o wide${NC}"
kubectl get pods -l 'app in (redis-cache,model-server-with-cache)' -o wide
echo ""

# Show cache pods and their nodes
echo "Redis cache pods:"
kubectl get pods -l app=redis-cache -o wide -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName
echo ""

# Show model pods that should be co-located
echo "Model server pods (should be co-located with cache):"
kubectl get pods -l app=model-server-with-cache -o wide -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName
echo ""

# Verify co-location
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}Step 3: Verify Affinity Rules${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo "Checking co-location..."
echo ""
for MODEL_POD in $(kubectl get pods -l app=model-server-with-cache -o name); do
    POD_NAME=$(echo $MODEL_POD | cut -d'/' -f2)
    NODE_NAME=$(kubectl get pod $POD_NAME -o jsonpath='{.spec.nodeName}')
    echo -e "${CMD}$MODEL_POD${NC} is on node: ${INFO}$NODE_NAME${NC}"

    # Find cache pod on same node
    CACHE_POD=$(kubectl get pods -l app=redis-cache -o wide | grep $NODE_NAME | awk '{print $1}')
    if [ -n "$CACHE_POD" ]; then
        echo -e "  ${SUCCESS}✓ Co-located with cache: $CACHE_POD${NC}"
    else
        echo -e "  ${WARN}⚠ No cache pod found on same node${NC}"
    fi
    echo ""
done

# Show affinity configuration
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}Affinity Configuration${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo "Model server affinity rules:"
kubectl get deployment model-server-with-cache -o jsonpath='{.spec.template.spec.affinity}' | jq '.'
echo ""

echo "┌───────────────────────────────────────────────────────────┐"
echo "│  Pod Affinity Explained                                    │"
echo "│  ┌─────────────────────────────────────────────────────┐ │"
echo "│  │ WITHOUT affinity:                                    │ │"
echo "│  │   [Cache Pod] → Node 1                               │ │"
echo "│  │   [Model Pod] → Node 2  (Network latency!)          │ │"
echo "│  │                                                      │ │"
echo "│  │ WITH affinity:                                       │ │"
echo "│  │   [Cache Pod] → Node 1                               │ │"
echo "│  │   [Model Pod] → Node 1  (Same node = fast!)         │ │"
echo "│  └─────────────────────────────────────────────────────┘ │"
echo "└───────────────────────────────────────────────────────────┘"
echo ""

# Summary
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Pod Affinity Test Complete!                                ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "You learned:"
echo "  ✓ How to use podAffinity for co-location"
echo "  ✓ How to co-locate with specific pods"
echo "  ✓ Hard vs soft affinity requirements"
echo "  ✓ Benefits: lower latency, shared resources"
echo ""
echo "Next:"
echo "  → Try 05-pod-anti-affinity-spreading.yaml for spreading"
echo ""
echo "To clean up:"
echo -e "${CMD}$ kubectl delete -f 04-pod-affinity-colocation.yaml${NC}"
echo ""
