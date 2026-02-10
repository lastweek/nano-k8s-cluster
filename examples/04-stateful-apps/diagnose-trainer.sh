#!/bin/bash
# Diagnostic script for trainer pods

# Color codes
CMD='\033[0;36m'
INFO='\033[0;33m'
ERROR='\033[0;31m'
SUCCESS='\033[0;32m'
NC='\033[0m'

echo -e "${INFO}========================================${NC}"
echo -e "${INFO}Diagnosing Trainer Pods${NC}"
echo -e "${INFO}========================================${NC}"
echo ""

echo -e "${INFO}1. Checking pod status...${NC}"
kubectl get pods -l app=distributed-training
echo ""

echo -e "${INFO}2. Checking StatefulSet status...${NC}"
kubectl get statefulset trainer
echo ""

echo -e "${INFO}3. Checking PVC status...${NC}"
kubectl get pvc -l app=distributed-training
echo ""

echo -e "${INFO}4. Checking trainer-0 details...${NC}"
kubectl describe pod trainer-0 | tail -30
echo ""

echo -e "${INFO}5. Checking trainer-0 logs...${NC}"
echo -e "${CMD}$ kubectl logs trainer-0${NC}"
kubectl logs trainer-0 --tail=50
echo ""

echo -e "${INFO}6. Checking recent events...${NC}"
kubectl get events --sort-by='.lastTimestamp' | grep trainer | tail -20
echo ""

echo -e "${INFO}7. Checking node resources...${NC}"
kubectl top nodes
echo ""

echo -e "${INFO}8. Checking if pods are scheduled...${NC}"
kubectl get pods -l app=distributed-training -o wide
echo ""
