# Environment Setup Guide

This guide will help you set up a local Kubernetes development environment for running the examples in this repository.

## Table of Contents

- [macOS](#macos)
- [Linux](#linux)
- [Verification](#verification)
- [minikube Configuration](#minikube-configuration)
- [Troubleshooting](#troubleshooting)

---

## macOS

### Step 1: Install Docker Desktop

```bash
# Using Homebrew
brew install --cask docker

# Or download from: https://www.docker.com/products/docker-desktop/
```

Start Docker Desktop and ensure it's running:
```bash
docker --version
docker ps
```

### Step 2: Install kubectl

```bash
# Using Homebrew
brew install kubectl

# Verify installation
kubectl version --client
```

### Step 3: Install minikube

```bash
# Using Homebrew
brew install minikube

# Verify installation
minikube version
```

### Step 4: Optional - Install Useful Tools

```bash
# kubectx/kubens - for context/namespace switching
brew install kubectx

# stern - for multi-pod log tailing
brew install stern

# k9s - terminal UI for Kubernetes
brew install k9s
```

---

## Linux

### Step 1: Install Docker

```bash
# Ubuntu/Debian
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add your user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Verify
docker --version
```

### Step 2: Install kubectl

```bash
# Download latest version
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Make executable
chmod +x kubectl

# Move to path
sudo mv kubectl /usr/local/bin/

# Verify
kubectl version --client
```

### Step 3: Install minikube

```bash
# Download latest release
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Verify
minikube version
```

### Step 4: Optional - Install Useful Tools

```bash
# kubectx/kubens
git clone https://github.com/ahmetb/kubectx /opt/kubectx
sudo ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx
sudo ln -s /opt/kubectx/kubens /usr/local/bin/kubens

# stern
sudo wget -qO /usr/local/bin/stern https://github.com/stern/stern/releases/download/v0.26.0/stern_0.26.0_linux_amd64
sudo chmod +x /usr/local/bin/stern

# k9s
sudo wget -qO /usr/local/bin/k9s https://github.com/derailed/k9s/releases/download/v0.31.0/k9s_linux_amd64
sudo chmod +x /usr/local/bin/k9s
```

---

## Verification

Run the verification script to ensure everything is set up correctly:

```bash
cd nano-k8s-cluster
./scripts/verify-setup.sh
```

Or verify manually:

```bash
# Check Docker
docker run hello-world

# Check kubectl
kubectl version --client

# Check minikube
minikube version
```

---

## minikube Configuration

### Start Cluster

For LLM workloads, you'll want more resources:

```bash
# Start with sufficient resources for GPU simulation
minikube start --cpus=4 --memory=8192 --driver=docker

# Or for even more resources (if available)
minikube start --cpus=8 --memory=16384 --driver=docker
```

### Enable Addons

```bash
# Enable ingress for external access examples
minikube addons enable ingress

# Enable metrics-server for HPA examples
minikube addons enable metrics-server

# Verify addons
minikube addons list
```

### Verify Cluster

```bash
# Check node status
kubectl get nodes

# Check system pods
kubectl get pods -n kube-system

# Check cluster info
kubectl cluster-info
```

---

## Troubleshooting

### Docker Issues

**Problem:** Docker daemon not running
```bash
# macOS: Start Docker Desktop
open -a Docker

# Linux: Start Docker service
sudo systemctl start docker
sudo systemctl enable docker
```

**Problem:** Permission denied (Linux only)
```bash
# Add user to docker group and re-login
sudo usermod -aG docker $USER
```

### minikube Issues

**Problem:** minikube start fails
```bash
# Delete existing cluster and retry
minikube delete
minikube start --cpus=4 --memory=8192 --driver=docker
```

**Problem:** Insufficient resources
```bash
# Check available memory
free -h  # Linux
sysctl hw.memsize  # macOS

# Reduce minikube resources
minikube start --cpus=2 --memory=4096
```

**Problem:** minikube can't connect to Docker
```bash
# Reset Docker context
docker context use default

# Restart Docker Desktop (macOS)
# or restart docker service (Linux)
sudo systemctl restart docker
```

### kubectl Issues

**Problem:** kubectl can't connect to cluster
```bash
# Reconfigure kubectl for minikube
minikube update-context

# Verify connection
kubectl cluster-info
```

**Problem:** Permission errors
```bash
# Check current context
kubectl config current-context

# View all contexts
kubectl config get-contexts

# Use minikube context
kubectl config use-context minikube
```

### Resource Cleanup

If things get messy, clean up and start fresh:

```bash
# Delete all resources in namespace
kubectl delete all --all -n default

# Reset minikube completely
minikube delete
minikube start --cpus=4 --memory=8192 --driver=docker
```

---

## Next Steps

Once your environment is set up:

1. Try the [basic examples](../examples/01-basics/)
2. Read the [concept documentation](concepts/)
3. Explore [LLM-specific patterns](llm-patterns/)

---

## Quick Reference

| Task | Command |
|------|---------|
| Start minikube | `minikube start --cpus=4 --memory=8192` |
| Stop minikube | `minikube stop` |
| Delete minikube | `minikube delete` |
| View dashboard | `minikube dashboard` |
| Get pod logs | `kubectl logs <pod-name>` |
| Port forward | `kubectl port-forward <pod-name> 8080:80` |
| Delete all resources | `kubectl delete all --all` |
| View resources | `kubectl get all` |
| Enter pod shell | `kubectl exec -it <pod-name> -- sh` |
