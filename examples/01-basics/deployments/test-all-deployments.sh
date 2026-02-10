#!/bin/bash
# Master test script for all deployment examples
#
# Runs all deployment tests sequentially with cleanup between each.

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
echo -e "${SUCCESS}Running All Deployment Examples${NC}"
echo -e "${SUCCESS}========================================${NC}"
echo ""

# Array of test scripts
TESTS=(
    "01-test-basic-deployment.sh"
    "02-test-scaling.sh"
    "03-test-rolling-update.sh"
    "04-test-update-strategies.sh"
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
    YAML_FILE=$(echo "$TEST" | sed 's/01-test-/01-/; s/02-test-/02-/; s/03-test-/03-/; s/04-test-/04-/').yaml'
    echo -e "${CMD}$ kubectl delete -f $YAML_FILE --ignore-not-found=true${NC}"
    kubectl delete -f $YAML_FILE --ignore-not-found=true > /dev/null

    # Wait for resources to be deleted
    sleep 2
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
echo "  - Move on to Services examples"
echo ""
