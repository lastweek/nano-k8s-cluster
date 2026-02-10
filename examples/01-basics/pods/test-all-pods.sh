#!/bin/bash
# Master test script for all pod examples
#
# Runs all pod tests sequentially with cleanup between each.

# Color codes
CMD='\033[0;36m'      # Cyan for commands
OUT='\033[0;37m'      # White for output
SUCCESS='\033[0;32m'   # Green for success
ERROR='\033[0;31m'     # Red for errors
INFO='\033[0;33m'      # Yellow for info
NC='\033[0m'           # No Color

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo -e "${SUCCESS}========================================${NC}"
echo -e "${SUCCESS}Running All Pod Examples${NC}"
echo -e "${SUCCESS}========================================${NC}"
echo ""

# Array of test scripts
TESTS=(
    "01-test-simple-pod.sh"
    "02-test-multi-container-pod.sh"
    "03-test-pod-with-resources.sh"
    "04-test-pod-with-probes.sh"
    "05-test-pod-with-env.sh"
    "06-test-pod-with-init-container.sh"
)

# Run each test
for i in "${!TESTS[@]}"; do
    TEST="${TESTS[$i]}"
    TEST_NUM=$((i + 1))
    TOTAL=${#TESTS[@]}

    echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${INFO}Test $TEST_NUM/$TOTAL: $TEST${NC}"
    echo -e "${INFO}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Run the test
    bash "$TEST"

    # Cleanup before next test
    echo ""
    echo -e "${INFO}Cleaning up before next test...${NC}"
    YAML_FILE=$(echo "$TEST" | sed 's/test-/0-/').yaml
    echo -e "${CMD}$ kubectl delete -f $YAML_FILE --ignore-not-found=true${NC}"
    kubectl delete -f $YAML_FILE --ignore-not-found=true

    # Wait for pod to be fully deleted
    POD_NAME=$(echo "$YAML_FILE" | sed 's/\.yaml//')
    while kubectl get pod $POD_NAME --ignore-not-found=true &>/dev/null; do
        sleep 1
    done

    echo -e "${SUCCESS}   ✓ Cleanup complete${NC}"
    echo ""

    # Small pause between tests
    sleep 2
done

echo -e "${SUCCESS}========================================${NC}"
echo -e "${SUCCESS}All Tests Complete!${NC}"
echo -e "${SUCCESS}========================================${NC}"
echo ""
echo "Summary:"
echo "  Ran $TOTAL tests successfully"
echo "  All resources cleaned up"
echo ""
echo "Next steps:"
echo "  - Review the test scripts to understand each concept"
echo "  - Modify the YAML files and re-run tests"
echo "  - Move on to Deployment examples"
echo ""
