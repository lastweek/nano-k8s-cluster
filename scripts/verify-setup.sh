#!/bin/bash
# Verify that all required tools are installed and configured

set -e

echo "🔍 Verifying Kubernetes development environment..."
echo ""

PASS_COUNT=0
FAIL_COUNT=0

# Function to check command exists
check_command() {
    if command -v $1 &> /dev/null; then
        VERSION=$($1 $2 2>&1 || echo "version unknown")
        echo "✅ $1: $VERSION"
        ((PASS_COUNT++))
        return 0
    else
        echo "❌ $1: NOT FOUND"
        ((FAIL_COUNT++))
        return 1
    fi
}

# Function to check running service
check_service() {
    SERVICE_NAME=$1
    CHECK_CMD=$2

    if eval $CHECK_CMD &> /dev/null; then
        echo "✅ $SERVICE_NAME: RUNNING"
        ((PASS_COUNT++))
        return 0
    else
        echo "❌ $SERVICE_NAME: NOT RUNNING"
        ((FAIL_COUNT++))
        return 1
    fi
}

echo "Checking required tools..."
echo ""

# Check required tools
check_command "docker" "--version"
check_command "kubectl" "version --client"
check_command "minikube" "version"

echo ""
echo "Checking optional tools..."
echo ""

# Check optional tools
check_command "kubectx" "-v"
check_command "stern" "--version"
check_command "k9s" "version"
check_command "helm" "version --short"
check_command "go" "version"

echo ""
echo "Checking services..."
echo ""

# Check Docker
check_service "Docker" "docker info"

# Check minikube
if minikube status &> /dev/null; then
    check_service "minikube" "minikube status"

    # Check kubectl can connect to cluster
    if kubectl cluster-info &> /dev/null; then
        echo "✅ kubectl: CAN CONNECT TO CLUSTER"
        ((PASS_COUNT++))
    else
        echo "❌ kubectl: CANNOT CONNECT TO CLUSTER"
        ((FAIL_COUNT++))
    fi

    # Check nodes are ready
    READY_NODES=$(kubectl get nodes --no-headers 2>/dev/null | grep -c "Ready" || echo "0")
    TOTAL_NODES=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')

    if [ "$TOTAL_NODES" -gt 0 ]; then
        echo "✅ Nodes: $READY_NODES/$TOTAL_NODES ready"
        ((PASS_COUNT++))
    else
        echo "❌ Nodes: No nodes found"
        ((FAIL_COUNT++))
    fi
else
    echo "⚠️  minikube: NOT STARTED (run ./scripts/setup-minikube.sh)"
    ((FAIL_COUNT++))
fi

echo ""
echo "========================================="
echo "✅ Passed: $PASS_COUNT"
echo "❌ Failed: $FAIL_COUNT"
echo "========================================="
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
    echo "🎉 All checks passed! Your environment is ready."
    echo ""
    echo "Next steps:"
    echo "  1. Try a basic example:"
    echo "     kubectl apply -f examples/01-basics/pods/simple-pod.yaml"
    echo ""
    echo "  2. Or start with the documentation:"
    echo "     docs/concepts/"
    exit 0
else
    echo "⚠️  Some checks failed. Please install missing tools."
    echo ""
    echo "Setup instructions:"
    echo "  macOS: brew install docker kubectl minikube"
    echo "  Linux: See docs/setup.md"
    echo ""
    exit 1
fi
