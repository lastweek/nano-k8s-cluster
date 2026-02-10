#!/bin/bash
# Test script for 01-statefulset.yaml
#
# This script demonstrates StatefulSet usage.

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
echo -e "${INFO}Script: 01-test-statefulset.sh${NC}"
echo -e "${INFO}===================================${NC}"
echo ""
echo "==================================="
echo "Testing: StatefulSet"
echo "==================================="
echo ""

# Apply the StatefulSet
echo -e "${INFO}Step 1: Creating StatefulSet and headless service...${NC}"
echo -e "${CMD}$ kubectl apply -f 01-statefulset.yaml${NC}"
kubectl apply -f 01-statefulset.yaml
echo ""

# Show StatefulSet
echo -e "${INFO}Step 2: Show StatefulSet...${NC}"
echo -e "${CMD}$ kubectl get statefulset web${NC}"
kubectl get statefulset web
echo ""

# Wait for pods to be ready (ordered deployment)
echo -e "${INFO}Step 3: Waiting for StatefulSet pods (ordered deployment)...${NC}"
echo "  StatefulSet creates pods in order: web-0 → web-1 → web-2"
echo ""
kubectl wait --for=condition=ready pod -l app=nginx-stateful --timeout=120s > /dev/null
echo -e "${SUCCESS}   ✓ All pods ready${NC}"
echo ""

# Show pods (note the naming)
echo -e "${INFO}Step 4: Show pods (note ordered naming)...${NC}"
echo -e "${CMD}$ kubectl get pods -l app=nginx-stateful -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,IP:.status.podIP${NC}"
kubectl get pods -l app=nginx-stateful -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,IP:.status.podIP
echo ""
echo "  Note: Pods are named web-0, web-1, web-2 (ordered)"
echo ""

# Show headless service
echo -e "${INFO}Step 5: Show headless service...${NC}"
echo -e "${CMD}$ kubectl get service nginx-headless${NC}"
kubectl get service nginx-headless
echo ""
echo "  Note: clusterIP is None (headless service)"
echo ""

# Show PVCs (one per pod)
echo -e "${INFO}Step 6: Show PVCs (one per pod)...${NC}"
echo -e "${CMD}$ kubectl get pvc -l app=nginx-stateful${NC}"
kubectl get pvc -l app=nginx-stateful
echo ""
echo "  Note: Each pod has its own PVC (www-web-0, www-web-1, www-web-2)"
echo ""

# Test DNS resolution
echo -e "${INFO}Step 7: Test DNS resolution (stable network identity)...${NC}"
echo ""
echo "  Resolving StatefulSet pods via DNS:"
for i in 0 1 2; do
    echo "    web-$i.nginx-headless.default.svc.cluster.local"
    kubectl run dns-test-$i --rm -it --image=nicolaka/netshoot --restart=Never -- nslookup web-$i.nginx-headless > /tmp/dns$sf.txt 2>&1 || true
    echo "      IP: $(kubectl get pod web-$i -o jsonpath='{.status.podIP}')"
    echo ""
done

# Test stable network identity
echo -e "${INFO}Step 8: Demonstrate stable network identity...${NC}"
echo "  Each pod has a stable DNS name that persists across restarts"
echo ""
for i in 0 1 2; do
    POD_IP=$(kubectl get pod web-$i -o jsonpath='{.status.podIP}')
    echo "  web-$i: $POD_IP"
done
echo ""

# Access each pod
echo -e "${INFO}Step 9: Access each pod to see unique content...${NC}"
echo ""
for i in 0 1 2; do
    echo "  Accessing web-$i:"
    echo -e "${CMD}$ kubectl exec web-$i -- curl http://localhost${NC}"
    kubectl exec web-$i -- curl -s http://localhost
    echo ""
done

# Demonstrate stable storage
echo -e "${INFO}Step 10: Demonstrate stable storage...${NC}"
echo ""
echo "  Writing unique data to each pod's PVC..."
for i in 0 1 2; do
    kubectl exec web-$i -- sh -c "echo 'Data from pod web-$i at $(date)' >> /usr/share/nginx/html/data.txt"
    echo "  web-$i: Data written"
done
echo ""

# Delete a pod to show data persistence
echo -e "${INFO}Step 11: Delete a pod to demonstrate stable storage...${NC}"
echo "  Deleting web-1..."
echo ""
WEB_1_IP_BEFORE=$(kubectl get pod web-1 -o jsonpath='{.status.podIP}')
echo "  IP before deletion: $WEB_1_IP_BEFORE"
echo ""
echo -e "${CMD}$ kubectl delete pod web-1${NC}"
kubectl delete pod web-1 --ignore-not-found=true > /dev/null

sleep 5

echo "  Waiting for web-1 to be recreated..."
kubectl wait --for=condition=ready pod/web-1 --timeout=60s > /dev/null
echo -e "${SUCCESS}   ✓ web-1 recreated${NC}"
echo ""

WEB_1_IP_AFTER=$(kubectl get pod web-1 -o jsonpath='{.status.podIP}')
echo "  IP after recreation: $WEB_1_IP_AFTER"
echo ""
echo "  Checking if data persists:"
echo -e "${CMD}$ kubectl exec web-1 -- cat /usr/share/nginx/html/data.txt${NC}"
kubectl exec web-1 -- cat /usr/share/nginx/html/data.txt
echo ""
echo -e "${SUCCESS}   ✓ Data persisted! Storage is stable.${NC}"
echo ""

# Show StatefulSet update strategy
echo -e "${INFO}Step 12: StatefulSet update strategy...${NC}"
echo -e "${CMD}$ kubectl get statefulset web -o jsonpath='{.spec.updateStrategy.type}'${NC}"
UPDATE_STRATEGY=$(kubectl get statefulset web -o jsonpath='{.spec.updateStrategy.type}')
echo "  Update strategy: $UPDATE_STRATEGY"
echo ""
echo "  Update strategies:"
echo "    - RollingUpdate: Ordered update (highest index first)"
echo "    - OnDelete: Manual update (delete pods to update)"
echo ""

# Compare with Deployment
echo -e "${INFO}Step 13: StatefulSet vs Deployment...${NC}"
echo ""
echo "  ┌─────────────────┬─────────────────────┬──────────────────────┐"
echo "  │ Feature         │ Deployment          │ StatefulSet          │"
echo "  ├─────────────────┼─────────────────────┼──────────────────────┤"
echo "  │ Pod names       │ Random hash         │ Ordered (web-0, 1, 2) │"
echo "  │ Network         │ Unstable            │ Stable DNS names     │"
echo "  │ Storage         │ Shared PVC          │ Per-pod PVCs         │"
echo "  │ Ordering        │ Unordered           │ Ordered deployment   │"
echo "  │ Use case        │ Stateless apps      │ Stateful apps        │"
echo "  └─────────────────┴─────────────────────┴──────────────────────┘"
echo ""

echo "==================================="
echo -e "${SUCCESS}Test Complete!${NC}"
echo "==================================="
echo ""
echo "Key concepts demonstrated:"
echo "  ✓ StatefulSet provides stable network identity"
echo "  ✓ Pods have ordered names (web-0, web-1, web-2)"
echo "  ✓ Each pod gets its own PVC for stable storage"
echo "  ✓ Ordered deployment and scaling"
echo "  ✓ Data persists across pod restarts"
echo ""
echo "Why this matters for LLM serving:"
echo "  - Distributed training requires stable pod identity"
echo "  - Each pod has a fixed rank (from pod name)"
echo "  - Checkpoints stored on per-pod PVCs"
echo "  - Pods communicate via stable DNS names"
echo ""
echo "StatefulSet and pods are still running. To clean up:"
echo -e "${CMD}$ kubectl delete -f 01-statefulset.yaml${NC}"
echo ""
echo "Or run: ./cleanup-all-stateful-apps.sh"
echo ""
