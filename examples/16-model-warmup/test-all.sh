#!/bin/bash
#
# Test All Warm-up Strategies
#
# Runs quick tests for all warm-up strategies and compares results.
# This is faster than the full benchmark but gives you a quick comparison.
#
# Usage: ./test-all.sh

set -e

NAMESPACE="${NAMESPACE:-default}"
RESULTS_DIR="${RESULTS_DIR:-./results}"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }

header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Strategies to test
STRATEGIES=(
    "none"
    "readiness-probe"
    "init-container"
)

# Create results directory
mkdir -p "$RESULTS_DIR"

# CSV file for results
CSV_FILE="$RESULTS_DIR/quick-test-results.csv"
echo "strategy,time_to_ready_sec,first_request_latency_sec,time_to_useful_sec" > "$CSV_FILE"

header "Testing All Warm-up Strategies"

log "This will test each strategy sequentially and compare results."
log ""

# Check cluster access
if ! kubectl get nodes > /dev/null 2>&1; then
    log_error "Cannot access Kubernetes cluster"
    exit 1
fi

# Check if image exists
if ! docker images | grep -q "vllm-warmup-test"; then
    log "Docker image not found, building..."
    cd docker
    docker build -t vllm-warmup-test:latest -f Dockerfile.vllm-sim . > /dev/null
    cd ..

    # Load into kind if needed
    if kubectl get nodes -o jsonpath='{.items[0].spec.providerID}' | grep -q "kind://"; then
        kind load docker-image vllm-warmup-test:latest > /dev/null 2>&1 || true
    fi
    log_success "Image built"
fi

# Test each strategy
for STRATEGY in "${STRATEGIES[@]}"; do
    header "Testing: $STRATEGY"

    # Determine deployment name
    case "$STRATEGY" in
        none) DEPLOYMENT="vllm-no-warmup" ;;
        readiness-probe) DEPLOYMENT="vllm-readiness-probe" ;;
        init-container) DEPLOYMENT="vllm-init-container" ;;
        staged) DEPLOYMENT="vllm-staged" ;;
        cached) DEPLOYMENT="vllm-cached" ;;
    esac

    # Clean up existing
    log "Cleaning up..."
    kubectl delete deployment "$DEPLOYMENT" -n "$NAMESPACE" --ignore-not=true > /dev/null 2>&1 || true

    # Apply deployment
    log "Applying deployment..."
    kubectl apply -f "$(dirname "$0")/$STRATEGY"*.yaml > /dev/null

    # Record start time
    START_TIME=$(date +%s)

    # Wait for pod to be ready
    log "Waiting for pod to be ready..."

    if [ "$STRATEGY" = "none" ]; then
        # No warm-up: ready quickly
        kubectl wait deployment "$DEPLOYMENT" -n "$NAMESPACE" --for=condition=available --timeout=120s > /dev/null 2>&1
    else
        # With warm-up: ready after model loads
        kubectl wait deployment "$DEPLOYMENT" -n "$NAMESPACE" --for=condition=available --timeout=300s > /dev/null 2>&1
    fi

    END_TIME=$(date +%s)
    TIME_TO_READY=$((END_TIME - START_TIME))

    log_success "Pod ready in ${TIME_TO_READY}s"

    # Get pod name
    POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l app=vllm,warmup=$STRATEGY -o jsonpath='{.items[0].metadata.name}')

    # Port forward
    kubectl port-forward "$POD_NAME" -n "$NAMESPACE" 8080:8000 > /dev/null 2>&1 &
    PF_PID=$!
    sleep 3

    # Test first request latency
    log "Testing first request..."
    FIRST_REQUEST_START=$(date +%s)

    # Try request until it succeeds
    MAX_ATTEMPTS=120
    ATTEMPT=0
    FIRST_REQUEST_LATENCY=0

    while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
        RESPONSE=$(curl -s -X POST http://localhost:8080/v1/completions \
            -H "Content-Type: application/json" \
            -d '{"model":"meta-llama/Llama-3-70B","prompt":"test","max_tokens":10}' 2>/dev/null || echo "")

        if echo "$RESPONSE" | grep -q '"text"'; then
            FIRST_REQUEST_END=$(date +%s)
            FIRST_REQUEST_LATENCY=$((FIRST_REQUEST_END - FIRST_REQUEST_START))
            log_success "First request completed in ${FIRST_REQUEST_LATENCY}s"
            break
        fi

        ATTEMPT=$((ATTEMPT + 1))
        sleep 1
    done

    if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
        log_error "First request timed out"
        FIRST_REQUEST_LATENCY=999
    fi

    # Clean up port-forward
    kill $PF_PID 2>/dev/null || true

    # Calculate time to useful (when user actually gets a response)
    if [ "$STRATEGY" = "none" ]; then
        # For "none", user waits time_to_ready + first_request
        TIME_TO_USEFUL=$((TIME_TO_READY + FIRST_REQUEST_LATENCY))
    else
        # For others, model is loaded when ready, so first_request is fast
        TIME_TO_USEFUL=$TIME_TO_READY
    fi

    # Save results
    echo "$STRATEGY,$TIME_TO_READY,$FIRST_REQUEST_LATENCY,$TIME_TO_USEFUL" >> "$CSV_FILE"

    log "Results:"
    log "  Time to Ready: ${TIME_TO_READY}s"
    log "  First Request: ${FIRST_REQUEST_LATENCY}s"
    log "  Time to Useful: ${TIME_TO_USEFUL}s"

    # Clean up deployment
    kubectl delete deployment "$DEPLOYMENT" -n "$NAMESPACE" --ignore-not=true > /dev/null 2>&1 || true
    sleep 2
done

# Print summary
header "Results Summary"

column -t -s',' "$CSV_FILE" | while read -r line; do
    echo "  $line"
done

log ""
log_success "All tests complete! Results saved to $CSV_FILE"
log ""

# Print analysis
header "Analysis"

log "Key Observations:"
log ""

while IFS=',' read -r strategy time_to_ready first_request time_to_useful; do
    if [ "$strategy" = "strategy" ]; then
        continue
    fi

    case "$strategy" in
        none)
            log "none (no warm-up):"
            log "  - Pod becomes Ready quickly (${time_to_ready}s)"
            log "  - BUT first request is SLOW (${first_request}s)"
            log "  - Total user wait: ${time_to_useful}s"
            ;;
        readiness-probe)
            log "readiness-probe:"
            log "  - Pod takes longer to be Ready (${time_to_ready}s)"
            log "  - BUT first request is FAST (${first_request}s)"
            log "  - Total user wait: ${time_to_useful}s"
            ;;
        init-container)
            log "init-container:"
            log "  - Pod takes longer to be Ready (${time_to_ready}s)"
            log "  - First request is FAST (${first_request}s)"
            log "  - Total user wait: ${time_to_useful}s"
            ;;
    esac
    log ""
done < "$CSV_FILE"

log "Recommendation:"
log "  Use 'readiness-probe' strategy for production."
log "  It guarantees model is loaded before traffic is sent."
