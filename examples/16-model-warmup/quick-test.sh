#!/bin/bash
#
# Quick Test Script
#
# Quickly test a warm-up strategy without full benchmark.
# Useful for development and quick validation.
#
# Usage:
#   ./quick-test.sh [strategy]
#
# Examples:
#   ./quick-test.sh none              # Test no warm-up
#   ./quick-test.sh readiness-probe   # Test readiness probe
#
# Author: nano-k8s-cluster examples

set -e

NAMESPACE="${NAMESPACE:-default}"
STRATEGY="${1:-readiness-probe}"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $1"; }

header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Determine YAML file and deployment name
case "$STRATEGY" in
    none|no-warmup)
        YAML_FILE="01-no-warmup.yaml"
        DEPLOYMENT="vllm-no-warmup"
        SERVICE="vllm-no-warmup"
        ;;
    readiness-probe|readiness)
        YAML_FILE="02-readiness-probe-warmup.yaml"
        DEPLOYMENT="vllm-readiness-probe"
        SERVICE="vllm-readiness-probe"
        ;;
    init-container|init)
        YAML_FILE="03-init-container-warmup.yaml"
        DEPLOYMENT="vllm-init-container"
        SERVICE="vllm-init-container"
        ;;
    staged|staged-rollout)
        YAML_FILE="04-staged-rollout-warmup.yaml"
        DEPLOYMENT="vllm-staged"
        SERVICE="vllm-staged"
        ;;
    cached|model-cache)
        YAML_FILE="05-model-cache-daemonset.yaml"
        DEPLOYMENT="vllm-cached"
        SERVICE="vllm-cached"
        ;;
    *)
        log_error "Unknown strategy: $STRATEGY"
        echo ""
        echo "Available strategies:"
        echo "  none              - No warm-up (baseline)"
        echo "  readiness-probe   - Readiness probe warm-up"
        echo "  init-container    - Init container warm-up"
        echo "  staged            - Staged rollout"
        echo "  cached            - Model cache daemonset"
        exit 1
        ;;
esac

header "Quick Test: $STRATEGY"

log "Strategy: $STRATEGY"
log "YAML: $YAML_FILE"
log "Deployment: $DEPLOYMENT"
log "Namespace: $NAMESPACE"

# Check cluster access
if ! kubectl get nodes > /dev/null 2>&1; then
    log_error "Cannot access Kubernetes cluster"
    exit 1
fi

# Check if image exists
if ! docker images | grep -q "vllm-warmup-test"; then
    log_warning "Docker image not found, building..."
    cd docker
    docker build -t vllm-warmup-test:latest -f Dockerfile.vllm-sim .
    cd ..

    # Load into kind if needed
    if kubectl get nodes -o jsonpath='{.items[0].spec.providerID}' | grep -q "kind://"; then
        kind load docker-image vllm-warmup-test:latest > /dev/null 2>&1 || true
    fi
    log_success "Image built"
fi

# Clean up existing
log "Cleaning up existing deployment..."
kubectl delete deployment "$DEPLOYMENT" -n "$NAMESPACE" --ignore-not=true > /dev/null 2>&1 || true
kubectl delete pod -l app=vllm,warmup=$STRATEGY -n "$NAMESPACE" --ignore-not=true > /dev/null 2>&1 || true

# Apply deployment
log "Applying deployment..."
kubectl apply -f "$YAML_FILE"

# Wait for pod
log "Waiting for pod to be ready..."
kubectl wait deployment "$DEPLOYMENT" -n "$NAMESPACE" --for=condition=available --timeout=300s

# Get pod name
POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l app=vllm,warmup=$STRATEGY -o jsonpath='{.items[0].metadata.name}')
log_success "Pod ready: $POD_NAME"

# Show pod status
log "Pod status:"
kubectl get pod "$POD_NAME" -n "$NAMESPACE"

# Port forward to test
log ""
log "Setting up port-forward..."
kubectl port-forward "$POD_NAME" -n "$NAMESPACE" 8080:8000 > /dev/null 2>&1 &
PF_PID=$!
sleep 3

# Test health endpoint
log ""
log "Testing /health endpoint..."
HEALTH_RESPONSE=$(curl -s http://localhost:8080/health)
echo "$HEALTH_RESPONSE" | jq . 2>/dev/null || echo "$HEALTH_RESPONSE"

# Check if model is loaded
if echo "$HEALTH_RESPONSE" | grep -q '"model_loaded":true'; then
    log_success "Model is loaded!"
else
    log_warning "Model not loaded yet (this is expected for readiness-probe strategy)"
fi

# Test metrics
log ""
log "Testing /metrics endpoint..."
curl -s http://localhost:8080/metrics | jq . 2>/dev/null || curl -s http://localhost:8080/metrics

# Test completion endpoint
log ""
log "Testing /v1/completions endpoint..."
COMPLETION_RESPONSE=$(curl -s -X POST http://localhost:8080/v1/completions \
    -H "Content-Type: application/json" \
    -d '{"model":"meta-llama/Llama-3-70B","prompt":"Hello, world!","max_tokens":10}')
echo "$COMPLETION_RESPONSE" | jq . 2>/dev/null || echo "$COMPLETION_RESPONSE"

if echo "$COMPLETION_RESPONSE" | grep -q '"text"'; then
    log_success "Completion request successful!"
else
    log_error "Completion request failed"
fi

# Clean up port-forward
kill $PF_PID 2>/dev/null || true

log ""
log_success "Test complete!"
log ""
log "To clean up, run:"
log "  kubectl delete deployment $DEPLOYMENT -n $NAMESPACE"
