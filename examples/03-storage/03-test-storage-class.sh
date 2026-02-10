#!/bin/bash
# Test script for 03-storage-class.yaml
#
# This script demonstrates StorageClass and dynamic provisioning.

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
echo -e "${INFO}Script: 03-test-storage-class.sh${NC}"
echo -e "${INFO}===================================${NC}"
echo ""
echo "==================================="
echo "Testing: StorageClass and Dynamic Provisioning"
echo "==================================="
echo ""

# Apply the StorageClasses and PVCs
echo -e "${INFO}Step 1: Creating StorageClasses, PVCs, and pod...${NC}"
echo -e "${CMD}$ kubectl apply -f 03-storage-class.yaml${NC}"
kubectl apply -f 03-storage-class.yaml
echo ""

# Show StorageClasses
echo -e "${INFO}Step 2: Show StorageClasses...${NC}"
echo -e "${CMD}$ kubectl get storageclass${NC}"
kubectl get storageclass
echo ""

# Show default StorageClass
echo -e "${INFO}Step 3: Show default StorageClass...${NC}"
DEFAULT_SC=$(kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}')
if [ -n "$DEFAULT_SC" ]; then
    echo "  Default StorageClass: $DEFAULT_SC"
else
    echo "  No default StorageClass set"
fi
echo ""

# Wait for PVCs to be bound
echo -e "${INFO}Step 4: Waiting for PVCs to be bound...${NC}"
sleep 5
kubectl get pvc -l app=storage-demo
echo ""

# Show PVC details
echo -e "${INFO}Step 5: Show PVC details...${NC}"
echo ""
echo "  PVC with 'standard' storage class:"
echo -e "${CMD}$ kubectl describe pvc pvc-standard${NC}"
kubectl describe pvc pvc-standard | head -20
echo ""
echo "  PVC with 'fast-ssd' storage class:"
echo -e "${CMD}$ kubectl describe pvc pvc-fast${NC}"
kubectl describe pvc pvc-fast | head -20
echo ""

# Wait for pod to be ready
echo -e "${INFO}Step 6: Waiting for pod to be ready...${NC}"
kubectl wait --for=condition=ready pod/storage-class-demo --timeout=60s > /dev/null
echo -e "${SUCCESS}   ✓ Pod ready${NC}"
echo ""

# Show pod logs
echo -e "${INFO}Step 7: Pod logs (storage class comparison)...${NC}"
echo -e "${CMD}$ kubectl logs storage-class-demo${NC}"
kubectl logs storage-class-demo
echo ""

# Show dynamically provisioned PVs
echo -e "${INFO}Step 8: Show dynamically provisioned PVs...${NC}"
echo -e "${CMD}$ kubectl get pv${NC}"
kubectl get pv
echo ""

# Show PV details
echo -e "${INFO}Step 9: Show PV details...${NC}"
for pv in $(kubectl get pv -o jsonpath='{.items[*].metadata.name}'); do
    echo "  PV: $pv"
    kubectl describe pv $pv | grep -E "Name:|StorageClass:|Claim:|Status:|Source:"
    echo ""
done

# Show reclaim policy
echo -e "${INFO}Step 10: StorageClass reclaim policies...${NC}"
echo -e "${CMD}$ kubectl get storageclass -o custom-columns='NAME:.metadata.name,RECLAIM_POLICY:.reclaimPolicy'${NC}"
kubectl get storageclass -o custom-columns='NAME:.metadata.name,RECLAIM_POLICY:.reclaimPolicy'
echo ""

# Explain reclaim policies
echo "  Reclaim Policies:"
echo "    - Delete: PV automatically deleted when PVC is deleted (default for dynamic provisioning)"
echo "    - Retain: PV remains after PVC deletion (manual cleanup required)"
echo ""
echo "  For this example:"
echo "    - Delete policy: PVs will be cleaned up automatically"
echo ""

# Demonstrate volume expansion (if supported)
echo -e "${INFO}Step 11: Volume expansion (if supported)...${NC}"
echo "  Checking if allowVolumeExpansion is enabled..."
kubectl get storageclass fast-ssd -o jsonpath='{.allowVolumeExpansion}'
echo ""
if kubectl get storageclass fast-ssd -o jsonpath='{.allowVolumeExpansion}' | grep -q "true"; then
    echo "  Volume expansion is enabled on fast-ssd storage class"
    echo "  You can expand PVC size with:"
    echo "    kubectl patch pvc pvc-fast -p '{\"spec\":{\"resources\":{\"requests\":{\"storage\":\"200Mi\"}}}}'"
else
    echo "  Volume expansion not enabled"
fi
echo ""

# Show storage class provisioners
echo -e "${INFO}Step 12: StorageClass provisioners...${NC}"
echo -e "${CMD}$ kubectl get storageclass -o custom-columns='NAME:.metadata.name,PROVISIONER:.provisioner'${NC}"
kubectl get storageclass -o custom-columns='NAME:.metadata.name,PROVISIONER:.provisioner'
echo ""

# Explain different provisioners
echo "  Common Provisioners:"
echo "    - kubernetes.io/host-path: For local testing (minikube, kind)"
echo "    - kubernetes.io/aws-ebs: AWS EBS volumes"
echo "    - kubernetes.io/gce-pd: Google Compute Engine persistent disks"
echo "    - kubernetes.io/azure-disk: Azure Disk storage"
echo "    - kubernetes.io/cephfs: CephFS file system"
echo "    - nfs.csi.k8s.io: NFS storage (via CSI driver)"
echo ""

# For LLM serving storage recommendations
echo -e "${INFO}Step 13: Storage recommendations for LLM serving...${NC}"
echo ""
echo "  Use Case              │ Storage Class      │ Reason"
echo "  ──────────────────────┼────────────────────┼──────────────────────────────"
echo "  Model Checkpoints     │ Standard (HDD)     │ Cost-effective, write-once"
echo "  Model Serving         │ Fast (SSD/NVMe)    │ Low latency read access"
echo "  Training Data         │ Standard (HDD)     │ Large capacity, cost-effective"
echo "  Cache / Temporary     │ Memory (tmpfs)     │ Fastest, but volatile"
echo "  Long-term Archive     │ Cloud (S3/GCS)     │ Cheapest, object storage"
echo ""

# Show volume binding modes
echo -e "${INFO}Step 14: Volume binding modes...${NC}"
echo -e "${CMD}$ kubectl get storageclass -o custom-columns='NAME:.metadata.name,VOLUME_BINDING_MODE:.volumeBindingMode'${NC}"
kubectl get storageclass -o custom-columns='NAME:.metadata.name,VOLUME_BINDING_MODE:.volumeBindingMode'
echo ""
echo "  Volume Binding Modes:"
echo "    - Immediate: PV provisioned immediately when PVC is created"
echo "    - WaitForFirstConsumer: PV provisioned after pod scheduled (better for topology-aware storage)"
echo ""

echo "==================================="
echo -e "${SUCCESS}Test Complete!${NC}"
echo "==================================="
echo ""
echo "Key concepts demonstrated:"
echo "  ✓ StorageClass defines storage types"
echo "  ✓ Dynamic provisioning: PVs created automatically"
echo "  ✓ Multiple storage classes for different needs"
echo "  ✓ Reclaim policy controls PV lifecycle"
echo ""
echo "Why this matters for LLM serving:"
echo "  - Use fast SSD for low-latency model serving"
echo "  - Use standard HDD for cost-effective checkpoint storage"
echo "  - Use memory-backed storage for high-performance caching"
echo ""
echo "Pod, PVCs, and StorageClasses are still running. To clean up:"
echo -e "${CMD}$ kubectl delete -f 03-storage-class.yaml${NC}"
echo ""
echo "Or run: ./cleanup-all-storage.sh"
echo ""
