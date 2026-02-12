#!/bin/bash
# Test script for Custom Scheduler Binary
#
# This script tests the custom scheduler implementation.

set -e

# Color codes
CMD='\033[0;36m'
SUCCESS='\033[0;32m'
ERROR='\033[0;31m'
INFO='\033[0;33m'
WARN='\033[0;35m'
NC='\033[0m'

echo -e "${INFO}===========================================${NC}"
echo -e "${INFO}Custom Scheduler Binary Test${NC}"
echo -e "${INFO}===========================================${NC}"
echo ""
echo "This test demonstrates custom scheduler binaries:"
echo "  ✓ Write your own scheduling logic"
echo "  ✓ Real-time GPU metrics integration"
echo "  ✓ Compare with default scheduler"
echo ""

# Check prerequisites
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}Prerequisites${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo "Checking for Go..."
if command -v go &> /dev/null; then
    echo -e "${SUCCESS}✓ Go installed${NC}"
    go version
else
    echo -e "${WARN}⚠ Go not found${NC}"
    echo "Install Go: https://golang.org/dl/"
fi
echo ""

echo "Checking for Python..."
if command -v python3 &> /dev/null; then
    echo -e "${SUCCESS}✓ Python installed${NC}"
    python3 --version
else
    echo -e "${WARN}⚠ Python not found${NC}"
fi
echo ""

echo "Checking for kubectl..."
if command -v kubectl &> /dev/null; then
    echo -e "${SUCCESS}✓ kubectl installed${NC}"
    kubectl version --client 2>/dev/null | head -1
else
    echo -e "${ERROR}✗ kubectl not found${NC}"
    exit 1
fi
echo ""

# Ask what to test
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${INFO}Select Test Option${NC}"
echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "1. Run Go scheduler locally (development mode)"
echo "2. Deploy scheduler to Kubernetes"
echo "3. Compare schedulers"
echo "4. Show code examples only"
echo ""
read -p "Select option (1-4): " choice
echo ""

case $choice in
    1)
        echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${INFO}Option 1: Run Go Scheduler Locally${NC}"
        echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""

        echo "Checking if Go is installed..."
        if ! command -v go &> /dev/null; then
            echo -e "${ERROR}✗ Go not found. Please install Go first.${NC}"
            exit 1
        fi

        echo "Downloading dependencies..."
        cd /Volumes/CaseSensitive/nano-k8s-cluster/examples/08-custom-scheduler-binary

        echo "Initializing Go module..."
        go mod init custom-scheduler 2>/dev/null || true

        echo "Getting Kubernetes client library..."
        go get k8s.io/client-go@latest
        go mod tidy

        echo ""
        echo "Starting scheduler (will use your kubeconfig)..."
        echo "Press Ctrl+C to stop"
        echo ""

        go run 01-simple-custom-scheduler.go
        ;;

    2)
        echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${INFO}Option 2: Deploy to Kubernetes${NC}"
        echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""

        echo "Creating Dockerfiles..."
        cat > Dockerfile.go <<'EOF'
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY 01-simple-custom-scheduler.go .
RUN go mod init scheduler && \
    go get k8s.io/client-go@latest && \
    go build -o simple-custom-scheduler 01-simple-custom-scheduler.go

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /
COPY --from=builder /app/simple-custom-scheduler .
EXPOSE 10251
ENTRYPOINT ["/simple-custom-scheduler"]
EOF

        cat > Dockerfile.python <<'EOF'
FROM python:3.11-slim
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY 02-gpu-aware-scheduler.py .
RUN pip install kubernetes --no-cache-dir
ENV PYTHONUNBUFFERED=1
ENTRYPOINT ["python3", "-u", "02-gpu-aware-scheduler.py"]
EOF

        echo -e "${SUCCESS}✓ Dockerfiles created${NC}"
        echo ""

        echo "Next steps:"
        echo "1. Build images:"
        echo -e "${CMD}docker build -f Dockerfile.go -t custom-scheduler-go .${NC}"
        echo -e "${CMD}docker build -f Dockerfile.python -t gpu-aware-scheduler .${NC}"
        echo ""
        echo "2. Push to your registry:"
        echo -e "${CMD}docker tag custom-scheduler-go <your-registry>/custom-scheduler-go:latest${NC}"
        echo -e "${CMD}docker push <your-registry>/custom-scheduler-go:latest${NC}"
        echo ""
        echo "3. Update image references in 03-deploy-custom-scheduler.yaml"
        echo ""
        echo "4. Deploy:"
        echo -e "${CMD}kubectl apply -f 03-deploy-custom-scheduler.yaml${NC}"
        ;;

    3)
        echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${INFO}Option 3: Compare Schedulers${NC}"
        echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""

        echo "Deploying comparison pods..."
        kubectl apply -f 04-compare-schedulers.yaml
        echo ""

        echo "Waiting for pods to schedule..."
        sleep 10
        echo ""

        echo "Pod scheduling results:"
        kubectl get pods -l app=compare -o custom-columns=NAME:.metadata.name,SCHEDULER:.spec.schedulerName,NODE:.spec.nodeName,PHASE:.status.phase
        echo ""

        echo "Differences:"
        echo "  - default-scheduler: Uses built-in K8s scheduling"
        echo "  - simple-custom-scheduler: Uses your Go code"
        echo "  - gpu-aware-scheduler: Uses Python with DCGM metrics"
        echo ""

        echo "To clean up:"
        echo -e "${CMD}kubectl delete -f 04-compare-schedulers.yaml${NC}"
        ;;

    4)
        echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${INFO}Option 4: Code Examples${NC}"
        echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""

        echo "Go Scheduler (01-simple-custom-scheduler.go):"
        echo "  - ~500 lines of Go code"
        echo "  - Implements full scheduler loop"
        echo "  - Filters, scores, and binds pods"
        echo ""

        echo "Python GPU Scheduler (02-gpu-aware-scheduler.py):"
        echo "  - ~400 lines of Python code"
        echo "  - Queries DCGM for GPU metrics"
        echo "  - NVLink topology aware"
        echo ""

        echo "View the code:"
        echo -e "${CMD}cat 01-simple-custom-scheduler.go | less${NC}"
        echo -e "${CMD}cat 02-gpu-aware-scheduler.py | less${NC}"
        ;;

    *)
        echo -e "${ERROR}Invalid option${NC}"
        exit 1
        ;;
esac

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Test Complete!                                              ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Learn more:"
echo "  → README.md - Full documentation"
echo "  → 01-simple-custom-scheduler.go - Go implementation"
echo "  → 02-gpu-aware-scheduler.py - Python with GPU metrics"
echo "  → 03-deploy-custom-scheduler.yaml - Deployment manifest"
echo "  → 04-compare-schedulers.yaml - Side-by-side comparison"
echo ""
