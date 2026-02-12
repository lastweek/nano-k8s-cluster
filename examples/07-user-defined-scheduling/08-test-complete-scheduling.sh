#!/bin/bash
# Test script for Complete LLM Model Scheduling (08-*.yaml)
#
# This script tests the complete production-ready LLM model serving
# configuration using all scheduling techniques.

set -e

# Color codes
CMD='\033[0;36m'
SUCCESS='\033[0;32m'
ERROR='\033[0;31m'
INFO='\033[0;33m'
WARN='\033[0;35m'
NC='\033[0m'

echo -e "${INFO}===========================================${NC}"
echo -e "${INFO}Complete LLM Scheduling Test${NC}"
echo -e "${INFO}===========================================${NC}"
echo ""
echo "This test demonstrates a complete production deployment:"
echo "  ✓ Combines ALL scheduling techniques"
echo "  ✓ Priority classes (production critical)"
echo "  ✓ Node selector + affinity (GPU type, zone)"
echo "  ✓ Pod affinity (co-locate with cache)"
echo "  ✓ Pod anti-affinity (spread across nodes)"
echo "  ✓ Tolerations (dedicated GPU nodes)"
echo "  ✓ Topology spread constraints (zone distribution)"
echo "  ✓ HPA + PDB (auto-scaling + HA)"
echo ""

# Prerequisites check
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}Prerequisites Check${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check node count
NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
echo "Available nodes: $NODE_COUNT"

if [ $NODE_COUNT -lt 3 ]; then
    echo -e "${WARN}⚠ Warning: You have less than 3 nodes${NC}"
    echo "This example works best with 3+ nodes for proper spreading."
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check for GPU nodes
GPU_NODES=$(kubectl get nodes -l gpu.node=true -o name 2>/dev/null | wc -l)
echo "GPU nodes labeled: $GPU_NODES"

if [ $GPU_NODES -lt 1 ]; then
    echo -e "${WARN}⚠ No GPU nodes labeled${NC}"
    echo "Please run ./01-gpu-node-labeling.sh first"
    exit 1
fi
echo ""

# Deploy the complete stack
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}Step 1: Deploy Complete Stack${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo "Deploying production LLM serving stack..."
echo -e "${CMD}$ kubectl apply -f 08-llm-model-scheduling.yaml${NC}"
kubectl apply -f 08-llm-model-scheduling.yaml
echo ""

# Wait for initial pods
echo "Waiting for cache pods..."
kubectl wait --for=condition=ready pod -l app=llama-3-70b-cache --timeout=90s 2>/dev/null || {
    echo -e "${WARN}Some cache pods not ready yet${NC}"
}
echo ""

# Show all created resources
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}Step 2: Created Resources${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo "Deployments:"
kubectl get deployments -l app=llama-3-70b
echo ""

echo "Services:"
kubectl get svc -l app=llama-3-70b
echo ""

echo "Priority Classes:"
kubectl get priorityclass llm-production
echo ""

echo "PodDisruptionBudget:"
kubectl get pdb -l app=llama-3-70b
echo ""

echo "HorizontalPodAutoscaler:"
kubectl get hpa llama-3-70b-hpa
echo ""

# Check pod scheduling
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}Step 3: Verify Scheduling${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo "All pods:"
kubectl get pods -l app=llama-3-70b -o wide
echo ""

# Show detailed pod information
echo "Pod details (node, priority, phase):"
kubectl get pods -l app=llama-3-70b -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,PRIORITY:.spec.priorityClassName,PHASE:.status.phase
echo ""

# Verify cache co-location
echo "Cache + Model co-location verification:"
for MODEL_POD in $(kubectl get pods -l app=llama-3-70b -o name); do
    POD_NAME=$(echo $MODEL_POD | cut -d'/' -f2)
    if [[ $POD_NAME == *"cache"* ]]; then
        continue
    fi

    NODE=$(kubectl get pod $POD_NAME -o jsonpath='{.spec.nodeName}')
    CACHE=$(kubectl get pods -l app=llama-3-70b-cache -o wide | grep $NODE | awk '{print $1}')

    echo "$POD_NAME → Node: $NODE"
    if [ -n "$CACHE" ]; then
        echo -e "  ${SUCCESS}✓ Co-located with cache: $CACHE${NC}"
    else
        echo -e "  ${WARN}⚠ No cache on same node${NC}"
    fi
    echo ""
done

# Check distribution
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}Step 4: Distribution Analysis${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo "Distribution by node:"
kubectl get pods -l app=llama-3-70b -o wide | awk 'NR>1 {print $7}' | sort | uniq -c | sort -rn
echo ""

# Check zone distribution if available
echo "Distribution by zone (if labeled):"
kubectl get pods -l app=llama-3-70b -o wide -o custom-columns=NAME:.metadata.name,ZONE:.metadata.labels.topology\.kubernetes\.io/zone | grep -v "none" | awk 'NR>1 {print $2}' | sort | uniq -c
echo ""

# Show scheduling configuration
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}Step 5: Scheduling Configuration${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo "Node selector:"
kubectl get deployment llama-3-70b -o jsonpath='{.spec.template.spec.nodeSelector}' | jq '.'
echo ""

echo "Tolerations:"
kubectl get deployment llama-3-70b -o jsonpath='{.spec.template.spec.tolerations}' | jq '.'
echo ""

echo "Priority class:"
kubectl get deployment llama-3-70b -o jsonpath='{.spec.template.spec.priorityClassName}'
echo ""

echo "Topology spread constraints:"
kubectl get deployment llama-3-70b -o jsonpath='{.spec.template.spec.topologySpreadConstraints}' | jq '.'
echo ""

echo "Pod affinity (sample):"
kubectl get deployment llama-3-70b -o jsonpath='{.spec.template.spec.affinity.podAffinity}' | jq '.'
echo ""

echo "Pod anti-affinity (sample):"
kubectl get deployment llama-3-70b -o jsonpath='{.spec.template.spec.affinity.podAntiAffinity}' | jq '.'
echo ""

# Show complete scheduling strategy
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}Complete Scheduling Strategy${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

cat <<'EOF'
┌─────────────────────────────────────────────────────────────────┐
│  Llama-3-70B Production Scheduling Strategy                    │
├─────────────────────────────────────────────────────────────────┤
│  1. Priority: 1000 (production-critical)                       │
│     → Schedules first, never preempted                         │
│                                                                 │
│  2. Node Selector: gpu.node=true                               │
│     → Must have GPU                                            │
│                                                                 │
│  3. Node Affinity (Required):                                  │
│     → Must be GPU node                                         │
│                                                                 │
│  4. Node Affinity (Preferred):                                 │
│     → Prefer H100 (weight: 100)                                │
│     → Prefer zone us-west-1a (weight: 50)                      │
│                                                                 │
│  5. Pod Affinity (Required):                                   │
│     → Co-locate with cache on same node                        │
│                                                                 │
│  6. Pod Anti-Affinity (Required):                              │
│     → Spread across different nodes                            │
│                                                                 │
│  7. Pod Anti-Affinity (Preferred):                             │
│     → Spread across zones (weight: 100)                        │
│                                                                 │
│  8. Topology Spread:                                           │
│     → Balance across zones (maxSkew: 1)                        │
│                                                                 │
│  9. Tolerations:                                               │
│     → Can use dedicated GPU nodes                              │
│     → Can use H100-only nodes                                  │
│                                                                 │
│  10. PodDisruptionBudget:                                      │
│      → Minimum 2 pods always available                         │
│                                                                 │
│  11. HorizontalPodAutoscaler:                                  │
│      → Auto-scale based on CPU/memory                          │
└─────────────────────────────────────────────────────────────────┘
EOF
echo ""

# Test endpoints
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}Step 6: Service Endpoint${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

SERVICE_IP=$(kubectl get svc llama-3-70b-service -o jsonpath='{.spec.clusterIP}')
echo "Service: llama-3-70b-service"
echo "Cluster IP: $SERVICE_IP"
echo "Port: 8000"
echo ""
echo "To test (once pods are ready):"
echo -e "${CMD}kubectl port-forward svc/llama-3-70b-service 8000:8000${NC}"
echo "Then: curl http://localhost:8000/v1/models"
echo ""

# Summary
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Complete LLM Scheduling Test Complete!                     ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "You learned:"
echo "  ✓ How to combine ALL scheduling techniques"
echo "  ✓ Production-ready LLM serving configuration"
echo "  ✓ High availability + performance strategy"
echo "  ✓ Auto-scaling with HPA"
echo "  ✓ Pod disruption budgets for safety"
echo ""
echo "Monitoring commands:"
echo -e "${CMD}kubectl top pods -l app=llama-3-70b${NC}"
echo -e "${CMD}kubectl get hpa${NC}"
echo -e "${CMD}kubectl get pdb${NC}"
echo -e "${CMD}kubectl describe deployment llama-3-70b${NC}"
echo ""
echo "To clean up:"
echo -e "${CMD}$ kubectl delete -f 08-llm-model-scheduling.yaml${NC}"
echo ""
