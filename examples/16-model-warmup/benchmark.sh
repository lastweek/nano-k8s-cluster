#!/bin/bash
#
# Warm-up Strategy Performance Benchmark
#
# This script benchmarks different warm-up strategies by measuring:
# 1. Pod start time (container running)
# 2. Time to Ready (pod marked Ready)
# 3. First request latency (time to first token)
# 4. Second request latency (warm cache)
#
# Usage:
#   ./benchmark.sh [strategy_name]
#
# Examples:
#   ./benchmark.sh                    # Benchmark all strategies
#   ./benchmark.sh none               # Benchmark only "no warm-up"
#   ./benchmark.sh readiness-probe    # Benchmark only "readiness probe"
#
# Author: nano-k8s-cluster examples

set -e

# Configuration
NAMESPACE="${NAMESPACE:-default}"
RESULTS_DIR="${RESULTS_DIR:-./results}"
MODEL_LOADING_TIME="${MODEL_LOADING_TIME:-30}"  # Simulated loading time
WARMUP_REQUEST_TIME="${WARMUP_REQUEST_TIME:-1}"  # Simulated warmup time

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Deployments to test
DEPLOYMENTS=(
    "none:vllm-no-warmup"
    "readiness-probe:vllm-readiness-probe"
    "init-container:vllm-init-container"
    "staged:vllm-staged"
    "cached:vllm-cached"
)

# Functions
log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Create results directory
mkdir -p "$RESULTS_DIR"

# Clean up any existing deployments
cleanup() {
    local strategy=$1
    local deployment=$2

    log "Cleaning up: $deployment"

    # Delete deployment
    kubectl delete deployment "$deployment" -n "$NAMESPACE" --ignore-not=true > /dev/null 2>&1 || true

    # Wait for pods to be deleted
    kubectl wait --for=delete pods -l app=vllm,warmup=$strategy -n "$NAMESPACE" --timeout=60s > /dev/null 2>&1 || true
}

# Wait for pod to be created
wait_for_pod_creation() {
    local strategy=$1
    local timeout=60

    log "Waiting for pod to be created..."

    local start_time=$(date +%s)
    while true; do
        local pod_name=$(kubectl get pods -n "$NAMESPACE" -l app=vllm,warmup=$strategy -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

        if [ -n "$pod_name" ]; then
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            log_success "Pod created: $pod_name (${duration}s)"
            echo "$pod_name"
            return
        fi

        local current_time=$(date +%s)
        if [ $((current_time - start_time)) -gt $timeout ]; then
            log_error "Timeout waiting for pod creation"
            return 1
        fi

        sleep 1
    done
}

# Get pod start time (when container was running)
measure_pod_start_time() {
    local pod_name=$1
    local strategy=$2

    log "Measuring pod start time..."

    # Wait for pod to be running
    kubectl wait pod "$pod_name" -n "$NAMESPACE" --for=condition=Ready --timeout=300s > /dev/null 2>&1

    # Get the actual start time from pod events
    local start_time=$(kubectl get pod "$pod_name" -n "$NAMESPACE" -o jsonpath='{.status.startTime}')

    # Get the current time (pod is ready now)
    local current_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Calculate duration
    local start_epoch=$(date -d "$start_time" +%s)
    local current_epoch=$(date -d "$current_time" +%s)
    local pod_ready_duration=$((current_epoch - start_epoch))

    log_success "Pod start time: ${pod_ready_duration}s"

    echo "$pod_ready_duration"
}

# Measure time to first successful request
measure_first_request_latency() {
    local service=$1
    local pod_name=$2

    log "Measuring first request latency..."

    local start_time=$(date +%s)

    # Try to make a request until it succeeds
    local max_attempts=300  # 5 minutes
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        # Make a request
        local response=$(kubectl exec "$pod_name" -n "$NAMESPACE" -c vllm -- curl -s -X POST http://localhost:8000/v1/completions -H "Content-Type: application/json" -d '{"model":"meta-llama/Llama-3-70B","prompt":"test","max_tokens":10}' 2>/dev/null || echo "")

        if [ -n "$response" ] && echo "$response" | grep -q '"text"'; then
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            log_success "First request latency: ${duration}s"
            echo "$duration"
            return
        fi

        attempt=$((attempt + 1))
        sleep 1
    done

    log_error "Timeout waiting for first request"
    echo "999"  # Error value
}

# Measure time to second request (warm cache)
measure_second_request_latency() {
    local service=$1
    local pod_name=$2

    log "Measuring second request latency..."

    local start_time=$(date +%s)

    # Make a request (should be fast)
    local response=$(kubectl exec "$pod_name" -n "$NAMESPACE" -c vllm -- curl -s -X POST http://localhost:8000/v1/completions -H "Content-Type: application/json" -d '{"model":"meta-llama/Llama-3-70B","prompt":"test2","max_tokens":10}' 2>/dev/null || echo "")

    if [ -n "$response" ] && echo "$response" | grep -q '"text"'; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_success "Second request latency: ${duration}s"
        echo "$duration"
    else
        log_error "Second request failed"
        echo "999"
    fi
}

# Get actual pod ready time from kubectl
get_pod_ready_time() {
    local pod_name=$1

    # Get pod creation time
    local creation_time=$(kubectl get pod "$pod_name" -n "$NAMESPACE" -o jsonpath='{.metadata.creationTimestamp}')

    # Get current time (should be ready now)
    local current_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Get ready condition time
    local ready_time=$(kubectl get pod "$pod_name" -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].lastTransitionTime}')

    # Calculate duration from creation to ready
    local creation_epoch=$(date -d "$creation_time" +%s 2>/dev/null || date -jf "%Y-%m-%dT%H:%M:%SZ" "$creation_time" +%s)
    local ready_epoch=$(date -d "$ready_time" +%s 2>/dev/null || date -jf "%Y-%m-%dT%H:%M:%SZ" "$ready_time" +%s)

    if [ -n "$ready_epoch" ] && [ "$ready_epoch" -gt "$creation_epoch" ]; then
        local duration=$((ready_epoch - creation_epoch))
        echo "$duration"
    else
        echo "0"
    fi
}

# Benchmark a single strategy
benchmark_strategy() {
    local strategy=$1
    local deployment=$2
    local yaml_file=$3

    header "Benchmarking: $strategy"

    local result_file="$RESULTS_DIR/${strategy}-results.txt"
    local csv_file="$RESULTS_DIR/results.csv"

    log "Strategy: $strategy"
    log "Deployment: $deployment"
    log "YAML: $yaml_file"
    log "Results: $result_file"

    # Clean up first
    cleanup "$strategy" "$deployment"

    # Apply deployment
    log "Applying deployment..."
    kubectl apply -f "$yaml_file" > /dev/null

    # Wait for pod creation
    local pod_name=$(wait_for_pod_creation "$strategy")

    if [ -z "$pod_name" ]; then
        log_error "Failed to create pod"
        return 1
    fi

    # Measure metrics
    log "Collecting metrics..."

    # Pod start time (container running)
    local pod_start_time=0
    local start_measurement=$(date +%s)

    # Wait for pod to be ready (different for each strategy)
    if [ "$strategy" = "none" ]; then
        # No warm-up: pod becomes ready quickly
        kubectl wait pod "$pod_name" -n "$NAMESPACE" --for=condition=Ready --timeout=120s > /dev/null 2>&1
    else
        # With warm-up: pod takes longer to be ready
        kubectl wait pod "$pod_name" -n "$NAMESPACE" --for=condition=Ready --timeout=300s > /dev/null 2>&1
    fi

    local end_measurement=$(date +%s)
    local time_to_ready=$((end_measurement - start_measurement))

    # Get service name
    local service="vllm-${strategy}"
    if [ "$strategy" = "none" ]; then
        service="vllm-no-warmup"
    elif [ "$strategy" = "readiness-probe" ]; then
        service="vllm-readiness-probe"
    elif [ "$strategy" = "init-container" ]; then
        service="vllm-init-container"
    elif [ "$strategy" = "staged" ]; then
        service="vllm-staged"
    elif [ "$strategy" = "cached" ]; then
        service="vllm-cached"
    fi

    # Wait a bit for service to be ready
    sleep 5

    # First request latency
    local first_request_latency=$(measure_first_request_latency "$service" "$pod_name")

    # Second request latency
    local second_request_latency=$(measure_second_request_latency "$service" "$pod_name")

    # Total user-perceived latency (time to ready + first request)
    local total_latency=$((time_to_ready + first_request_latency))

    # Calculate "time to useful" - when the user actually gets a response
    # For "none": time to ready is fast but first request is slow
    # For others: time to ready includes model loading, so first request is fast
    local time_to_useful
    if [ "$strategy" = "none" ]; then
        time_to_useful=$((time_to_ready + first_request_latency))
    else
        time_to_useful=$time_to_ready
    fi

    # Save results
    cat > "$result_file" <<EOF
Warm-up Strategy Benchmark Results
====================================
Strategy:        $strategy
Deployment:      $deployment
Timestamp:       $(date)

Metrics:
--------
Time to Ready:           ${time_to_ready}s
First Request Latency:   ${first_request_latency}s
Second Request Latency:  ${second_request_latency}s
Total Latency:           ${total_latency}s
Time to Useful:          ${time_to_useful}s

Configuration:
-------------
Model Loading Time:  ${MODEL_LOADING_TIME}s
Warmup Request Time: ${WARMUP_REQUEST_TIME}s
EOF

    # Append to CSV
    if [ ! -f "$csv_file" ]; then
        echo "strategy,time_to_ready,first_request,second_request,total_latency,time_to_useful" > "$csv_file"
    fi
    echo "$strategy,$time_to_ready,$first_request_latency,$second_request_latency,$total_latency,$time_to_useful" >> "$csv_file"

    # Print results
    cat "$result_file"

    log_success "Results saved to $result_file"

    # Clean up
    cleanup "$strategy" "$deployment"
}

# Main benchmark
main() {
    local target_strategy="${1:-}"

    header "Warm-up Strategy Performance Benchmark"

    log "Configuration:"
    log "  Namespace: $NAMESPACE"
    log "  Results dir: $RESULTS_DIR"
    log "  Model loading time: ${MODEL_LOADING_TIME}s"
    log "  Warmup request time: ${WARMUP_REQUEST_TIME}s"
    log ""

    # Check if cluster is accessible
    if ! kubectl get nodes > /dev/null 2>&1; then
        log_error "Cannot access Kubernetes cluster"
        exit 1
    fi

    # Check if Docker image exists
    if ! docker images | grep -q "vllm-warmup-test"; then
        log_warning "Docker image 'vllm-warmup-test:latest' not found"
        log "Building image..."
        cd docker
        docker build -t vllm-warmup-test:latest -f Dockerfile.vllm-sim .
        cd ..
        log_success "Image built"
    fi

    # Load image into kind/minikube if needed
    if kubectl get nodes -o jsonpath='{.items[0].spec.providerID}' | grep -q "kind://"; then
        log "Detected kind cluster, loading image..."
        kind load docker-image vllm-warmup-test:latest > /dev/null 2>&1 || true
    fi

    # Benchmark strategies
    for entry in "${DEPLOYMENTS[@]}"; do
        IFS=':' read -r strategy deployment <<< "$entry"

        if [ -n "$target_strategy" ] && [ "$strategy" != "$target_strategy" ]; then
            continue
        fi

        local yaml_file="$(dirname "$0")/${strategy#vllm-}-*.yaml"
        if [ "$strategy" = "none" ]; then
            yaml_file="$(dirname "$0")/01-no-warmup.yaml"
        elif [ "$strategy" = "readiness-probe" ]; then
            yaml_file="$(dirname "$0")/02-readiness-probe-warmup.yaml"
        elif [ "$strategy" = "init-container" ]; then
            yaml_file="$(dirname "$0")/03-init-container-warmup.yaml"
        elif [ "$strategy" = "staged" ]; then
            yaml_file="$(dirname "$0")/04-staged-rollout-warmup.yaml"
        elif [ "$strategy" = "cached" ]; then
            yaml_file="$(dirname "$0")/05-model-cache-daemonset.yaml"
        fi

        benchmark_strategy "$strategy" "$deployment" "$yaml_file"
        echo ""
    done

    # Print summary
    header "Summary"

    if [ -f "$RESULTS_DIR/results.csv" ]; then
        column -t -s',' "$RESULTS_DIR/results.csv" | while read -r line; do
            echo "  $line"
        done
    fi

    log_success "Benchmark complete! Results saved to $RESULTS_DIR/"
}

# Run main
main "$@"
