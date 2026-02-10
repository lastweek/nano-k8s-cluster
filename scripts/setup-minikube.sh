#!/bin/bash
# Setup minikube for Kubernetes development

set -e

echo "🚀 Setting up minikube for Kubernetes development..."
echo ""

# Detect OS
OS="$(uname -s)"
echo "Detected OS: $OS"
echo ""

# Check if minikube is installed
if ! command -v minikube &> /dev/null; then
    echo "❌ minikube is not installed. Please install it first:"
    echo "   macOS: brew install minikube"
    echo "   Linux: See https://minikube.sigs.k8s.io/docs/start/"
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed. Please install it first:"
    echo "   macOS: brew install kubectl"
    echo "   Linux: See https://kubernetes.io/docs/tasks/tools/"
    exit 1
fi

# Check if Docker is running
if ! docker info &> /dev/null; then
    echo "❌ Docker is not running. Please start Docker:"
    echo "   macOS: Open Docker Desktop"
    echo "   Linux: sudo systemctl start docker"
    exit 1
fi

# Check available memory
if [[ "$OS" == "Darwin" ]]; then
    TOTAL_MEM=$(sysctl hw.memsize | awk '{print $2/1024/1024/1024}')
else
    TOTAL_MEM=$(free -g | awk '/^Mem:/{print $2}')
fi

# Determine resources based on available memory
if (( $(echo "$TOTAL_MEM >= 16" | bc -l) )); then
    CPUS=8
    MEMORY=16384
elif (( $(echo "$TOTAL_MEM >= 8" | bc -l) )); then
    CPUS=4
    MEMORY=8192
else
    CPUS=2
    MEMORY=4096
fi

echo "📊 Available Memory: ${TOTAL_MEM}GB"
echo "⚙️  Configuring minikube with: ${CPUS} CPUs, ${MEMORY}MB RAM"
echo ""

# Check if minikube is already running
if minikube status &> /dev/null; then
    echo "✅ minikube is already running"
    echo ""
    read -p "Do you want to delete and recreate it? (y/N) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🗑️  Deleting existing minikube cluster..."
        minikube delete
    else
        echo "Using existing minikube cluster"
    fi
fi

# Start minikube if not running
if ! minikube status &> /dev/null; then
    echo "🎯 Starting minikube..."
    minikube start --cpus=$CPUS --memory=$MEMORY --driver=docker
    echo ""
fi

# Enable useful addons
echo "🔌 Enabling minikube addons..."
minikube addons enable ingress
minikube addons enable metrics-server
echo ""

# Verify cluster is ready
echo "⏳ Waiting for cluster to be ready..."
kubectl wait --for=condition=ready node --all --timeout=5m
echo ""

# Display cluster info
echo "✅ Setup complete!"
echo ""
echo "Cluster Info:"
kubectl cluster-info
echo ""

echo "Nodes:"
kubectl get nodes
echo ""

echo "System Pods:"
kubectl get pods -n kube-system
echo ""

echo "🎉 minikube is ready!"
echo ""
echo "Useful commands:"
echo "  kubectl get pods              # List all pods"
echo "  kubectl get all               # List all resources"
echo "  minikube dashboard            # Open dashboard"
echo "  minikube tunnel               # Enable LoadBalancer (in another terminal)"
echo ""
