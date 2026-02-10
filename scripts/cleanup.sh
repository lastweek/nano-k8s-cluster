#!/bin/bash
# Cleanup script to remove all Kubernetes resources from default namespace

set -e

echo "🧹 Cleaning up Kubernetes resources..."
echo ""

# Confirm cleanup
read -p "This will delete all resources in the default namespace. Continue? (y/N) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "Deleting resources in default namespace..."

# Delete all resources
kubectl delete all --all -n default 2>/dev/null || true

# Delete configmaps
kubectl delete configmaps --all -n default 2>/dev/null || true

# Delete secrets (except default ones)
kubectl delete secrets --all -n default 2>/dev/null || true

# Delete PVCs
kubectl delete pvc --all -n default 2>/dev/null || true

echo ""
echo "✅ Cleanup complete!"
echo ""
echo "Remaining resources:"
kubectl get all -n default
echo ""
