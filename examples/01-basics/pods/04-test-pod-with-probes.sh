#!/bin/bash
# Test script for 04-pod-with-probes.yaml
#
# This script demonstrates health probes (liveness, readiness, startup).

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
echo -e "${INFO}Script: test-pod-with-probes.sh${NC}"
echo -e "${INFO}===================================${NC}"
echo ""
echo "==================================="
echo "Testing: Pod with Health Probes"
echo "==================================="
echo ""

# Apply the pod
echo -e "${INFO}Step 1: Creating pod with health probes...${NC}"
echo -e "${CMD}$ kubectl apply -f 04-pod-with-probes.yaml${NC}"
kubectl apply -f 04-pod-with-probes.yaml
echo ""

# Watch startup (this is where startup probe is active)
echo -e "${INFO}Step 2: Watching pod startup (startup probe active)...${NC}"
echo "   The startup probe gives the container time to start."
echo ""

# Wait for startup probe to succeed
echo -e "${CMD}$ kubectl wait --for=condition=ready pod/pod-with-probes --timeout=60s${NC}"
kubectl wait --for=condition=ready pod/pod-with-probes --timeout=60s

echo -e "${SUCCESS}   ✓ Startup probe succeeded!${NC}"
echo ""

# Show pod status
echo -e "${INFO}Step 3: Pod status:${NC}"
echo -e "${CMD}$ kubectl get pods pod-with-probes${NC}"
kubectl get pods pod-with-probes
echo ""

# Show probe configuration
echo -e "${INFO}Step 4: Probe configuration:${NC}"
echo -e "${CMD}$ kubectl describe pod pod-with-probes | grep -A 15 'Liveness\|Readiness\|Startup'${NC}"
kubectl describe pod pod-with-probes | grep -A 15 "Liveness\|Readiness\|Startup"
echo ""

# Show recent events (probe checks)
echo -e "${INFO}Step 5: Recent probe events:${NC}"
echo -e "${CMD}$ kubectl get events --field-selector involvedObject.name=pod-with-probes --sort-by=.metadata.creationTimestamp | tail -20${NC}"
kubectl get events --field-selector involvedObject.name=pod-with-probes --sort-by=.metadata.creationTimestamp | tail -20
echo ""

# Explain each probe
echo -e "${INFO}Step 6: Probe types explained:${NC}"
echo ""
echo "   Startup Probe:"
echo "     - Runs first, before liveness/readiness"
echo "     - Extended failure threshold (30 attempts × 10s = 5 min)"
echo "     - Allows slow-starting apps (like large LLM model loading)"
echo "     - For LLMs: increase to 720 (720 × 10s = 2 hours!)"
echo ""
echo "   Liveness Probe:"
echo "     - Detects hung/dead containers"
echo "     - On failure: restart container"
echo "     - Shorter threshold (3 × 10s = 30s)"
echo ""
echo "   Readiness Probe:"
echo "     - Controls traffic routing"
echo "     - On failure: remove from service endpoints"
echo "     - Doesn't restart container"
echo "     - Shorter threshold (3 × 5s = 15s)"
echo ""

echo "==================================="
echo -e "${SUCCESS}Test complete!${NC}"
echo "==================================="
echo ""
echo "Key concepts demonstrated:"
echo "  ✓ Startup probe: Extended time for slow starts"
echo "  ✓ Liveness probe: Detect and restart hung containers"
echo "  ✓ Readiness probe: Control traffic routing"
echo ""
echo "For LLM workloads:"
echo "  - Large models (70B+) need 30+ minutes to load"
echo "  - Set startupProbe.failureThreshold to 720 (2 hours)"
echo "  - This prevents K8s from killing the pod during model load"
echo ""
echo "Pod is still running. To clean up:"
echo -e "${CMD}$ kubectl delete -f 04-pod-with-probes.yaml${NC}"
echo ""
