#!/bin/bash
# Master test script for all CRD and Operator examples
#
# Runs all tests sequentially with cleanup between each.

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
echo -e "${SUCCESS}Running All CRD and Operator Examples${NC}"
echo -e "${SUCCESS}========================================${NC}"
echo ""

# Array of test scripts
TESTS=(
    "01-test-crd.sh"
    "02-test-operator.sh"
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

    # Small pause between tests
    sleep 2
done

echo -e "${SUCCESS}========================================${NC}"
echo -e "${SUCCESS}All Tests Complete!${NC}"
echo -e "${SUCCESS}========================================${NC}"
echo ""
echo "Summary:"
echo "  Ran $TOTAL tests successfully"
echo ""
echo "Next steps:"
echo "  - Review the test scripts to understand each concept"
echo "  - Modify the YAML files and re-run tests"
echo "  - Try building your own operator with Kubebuilder"
echo "  - Study NVIDIA Dynamo's operator implementation"
echo ""
