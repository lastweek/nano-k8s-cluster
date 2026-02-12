#!/bin/bash
#
# Cleanup Script
#
# Remove all warm-up test resources from the cluster.
#
# Usage: ./cleanup.sh

set -e

NAMESPACE="${NAMESPACE:-default}"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }

header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

header "Cleaning up warm-up test resources"

log "Namespace: $NAMESPACE"
log ""

# Delete deployments
log "Deleting deployments..."
kubectl delete deployment vllm-no-warmup -n "$NAMESPACE" --ignore-not=true > /dev/null 2>&1 || true
kubectl delete deployment vllm-readiness-probe -n "$NAMESPACE" --ignore-not=true > /dev/null 2>&1 || true
kubectl delete deployment vllm-init-container -n "$NAMESPACE" --ignore-not=true > /dev/null 2>&1 || true
kubectl delete deployment vllm-staged -n "$NAMESPACE" --ignore-not=true > /dev/null 2>&1 || true
kubectl delete deployment vllm-cached -n "$NAMESPACE" --ignore-not=true > /dev/null 2>&1 || true
log_success "Deployments deleted"

# Delete daemonsets
log "Deleting daemonsets..."
kubectl delete daemonset model-cacher -n "$NAMESPACE" --ignore-not=true > /dev/null 2>&1 || true
log_success "Daemonsets deleted"

# Delete services
log "Deleting services..."
kubectl delete service vllm-no-warmup -n "$NAMESPACE" --ignore-not=true > /dev/null 2>&1 || true
kubectl delete service vllm-readiness-probe -n "$NAMESPACE" --ignore-not=true > /dev/null 2>&1 || true
kubectl delete service vllm-init-container -n "$NAMESPACE" --ignore-not=true > /dev/null 2>&1 || true
kubectl delete service vllm-staged -n "$NAMESPACE" --ignore-not=true > /dev/null 2>&1 || true
kubectl delete service vllm-cached -n "$NAMESPACE" --ignore-not=true > /dev/null 2>&1 || true
log_success "Services deleted"

# Delete cronjobs
log "Deleting cronjobs..."
kubectl delete cronjob morning-scale-up -n "$NAMESPACE" --ignore-not=true > /dev/null 2>&1 || true
kubectl delete cronjob evening-scale-down -n "$NAMESPACE" --ignore-not=true > /dev/null 2>&1 || true
log_success "Cronjobs deleted"

# Delete RBAC
log "Deleting RBAC..."
kubectl delete serviceaccount scaler -n "$NAMESPACE" --ignore-not=true > /dev/null 2>&1 || true
kubectl delete role deployment-scaler -n "$NAMESPACE" --ignore-not=true > /dev/null 2>&1 || true
kubectl delete rolebinding deployment-scaler -n "$NAMESPACE" --ignore-not=true > /dev/null 2>&1 || true
log_success "RBAC deleted"

# Delete pods
log "Deleting pods..."
kubectl delete pods -l app=vllm -n "$NAMESPACE" --ignore-not=true > /dev/null 2>&1 || true
kubectl delete pods -l app=model-cacher -n "$NAMESPACE" --ignore-not=true > /dev/null 2>&1 || true
log_success "Pods deleted"

log ""
log_success "Cleanup complete!"
log ""
log "All warm-up test resources have been removed."
