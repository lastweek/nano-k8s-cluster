#!/bin/bash
# GPU Node Labeling Script
#
# This script labels nodes with GPU information for user-defined scheduling.
#
# Labels created:
# - gpu.node=true                        (marks as GPU node)
# - nvidia.com/gpu.product=H100/A100/etc (GPU type)
# - nvidia.com/gpu.memory=80Gi          (GPU memory)
# - nvidia.com/gpu.count=4               (GPU count)
# - gpu.nvlink=true                     (NVLink support)
# - gpu.ib=true                         (InfiniBand support)
# - topology.kubernetes.io/zone=zone-a   (Zone info)

set -e

# Color codes
CMD='\033[0;36m'      # Cyan for commands
SUCCESS='\033[0;32m'   # Green for success
ERROR='\033[0;31m'     # Red for errors
INFO='\033[0;33m'      # Yellow for info
WARN='\033[0;35m'      # Magenta for warnings
NC='\033[0m'           # No Color

echo -e "${INFO}===========================================${NC}"
echo -e "${INFO}GPU Node Labeling${NC}"
echo -e "${INFO}===========================================${NC}"
echo ""
echo "This script labels nodes with GPU information."
echo "These labels are used by user-defined scheduling."
echo ""

# Check for nodes
echo -e "${INFO}Checking for nodes...${NC}"
NODES=$(kubectl get nodes -o json | jq -r '.items[].metadata.name')
NODE_COUNT=$(echo "$NODES" | wc -l)
echo "Found $NODE_COUNT nodes"
echo ""

# For each node, detect GPU info
for NODE in $NODES; do
    echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${INFO}Node: $NODE${NC}"
    echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # Check if node has GPUs
    GPU_COUNT=$(kubectl get node "$NODE" -o jsonpath='{.status.capacity.nvidia\.com/gpu}' 2>/dev/null || echo "0")

    if [ "$GPU_COUNT" = "0" ] || [ -z "$GPU_COUNT" ]; then
        echo -e "${WARN}⚠ No GPUs found on $NODE${NC}"
        # Still label as non-GPU
        kubectl label node "$NODE" gpu.node=false --overwrite
        echo ""
        continue
    fi

    echo -e "${SUCCESS}✓ Found $GPU_COUNT GPUs${NC}"

    # Label as GPU node
    kubectl label node "$NODE" gpu.node=true --overwrite
    echo -e "${CMD}  kubectl label node $NODE gpu.node=true${NC}"

    # Try to get more GPU info using kubectl/nvidia-smi
    # Note: This requires nvidia-device-plugin and nvidia-smi

    # Get GPU memory (approximate)
    # You would typically query nvidia-smi for this
    kubectl label node "$NODE" nvidia.com/gpu.count="$GPU_COUNT" --overwrite 2>/dev/null || true

    # Try to detect GPU type from common patterns
    # In production, you'd query nvidia-smi or use a tool
    echo ""
    echo "For manual GPU type labeling, run on the node:"
    echo "  # Detect GPU type"
    echo "  nvidia-smi --query-gpu=name --format=csv,noheader | head -1"
    echo ""
    echo "Then label accordingly:"
    echo "  kubectl label node $NODE nvidia.com/gpu.product=H100"
    echo "  kubectl label node $NODE nvidia.com/gpu.product=A100-80GB"
    echo "  kubectl label node $NODE nvidia.com/gpu.product=L40S"
    echo ""
done

# Show labeled nodes
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}Summary: GPU Nodes${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${CMD}$ kubectl get nodes -l gpu.node=true${NC}"
kubectl get nodes -l gpu.node=true
echo ""

# Show all GPU-related labels
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}All GPU Labels${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "GPU nodes and their labels:"
for NODE in $(kubectl get nodes -l gpu.node=true -o jsonpath='{.items[*].metadata.name}'); do
    echo ""
    echo -e "${CMD}$NODE:${NC}"
    kubectl get node "$NODE" -o jsonpath='{.metadata.labels}' | jq -r 'to_entries[] | "  \(.key): \(.value)"'
done
echo ""

# Show example scheduling
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}Example: Schedule to H100 Nodes${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
cat <<'EOF'
# After labeling, you can schedule to specific GPU types:

apiVersion: apps/v1
kind: Deployment
metadata:
  name: llama-model
spec:
  template:
    spec:
      nodeSelector:
        nvidia.com/gpu.product: H100
      containers:
      - name: vllm
        resources:
          limits:
            nvidia.com/gpu: "4"

# This will only schedule to H100 nodes!
EOF
echo ""

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  GPU Node Labeling Complete!                                   ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Labels created:"
echo "  ✓ gpu.node=true (for GPU nodes)"
echo "  ✓ gpu.node=false (for non-GPU nodes)"
echo ""
echo "Next steps:"
echo "  → Add GPU type labels: kubectl label node <name> nvidia.com/gpu.product=H100"
echo "  → See 03-gpu-node-selector.yaml for usage examples"
echo ""
