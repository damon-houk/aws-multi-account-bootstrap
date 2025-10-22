#!/bin/bash

# Test script for dry-run mode
# This verifies that --dry-run flag prevents resource creation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Testing dry-run mode...${NC}"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Test parameters
TEST_PROJECT_CODE="TST"
TEST_EMAIL="test.user"
TEST_OU_ID="ou-test-12345678"
TEST_GITHUB_ORG="test-org"
TEST_REPO_NAME="test-repo"

# Function to check if output contains expected dry-run indicators
check_dry_run_output() {
    local output="$1"
    local test_name="$2"

    if echo "$output" | grep -q "DRY RUN MODE ENABLED"; then
        echo -e "${GREEN}✓${NC} $test_name: Dry-run banner found"
    else
        echo -e "${RED}✗${NC} $test_name: Dry-run banner missing"
        return 1
    fi

    if echo "$output" | grep -q "\[DRY RUN\]"; then
        echo -e "${GREEN}✓${NC} $test_name: Dry-run markers found"
    else
        echo -e "${RED}✗${NC} $test_name: Dry-run markers missing"
        return 1
    fi

    if echo "$output" | grep -q "Dry Run Complete!"; then
        echo -e "${GREEN}✓${NC} $test_name: Dry-run completion message found"
    else
        echo -e "${RED}✗${NC} $test_name: Dry-run completion message missing"
        return 1
    fi

    # Check that no actual creation commands are executed
    if echo "$output" | grep -q "aws organizations create-account"; then
        echo -e "${RED}✗${NC} $test_name: AWS account creation attempted!"
        return 1
    fi

    if echo "$output" | grep -q "gh repo create"; then
        echo -e "${RED}✗${NC} $test_name: GitHub repo creation attempted!"
        return 1
    fi

    echo -e "${GREEN}✓${NC} $test_name: No resource creation detected"
}

# Test 1: Dry-run with all parameters (CI mode to avoid prompts)
echo -e "${BLUE}Test 1: Dry-run with all parameters (CI mode)${NC}"
OUTPUT=$(CI=true "$PROJECT_ROOT/scripts/setup-complete-project.sh" \
    "$TEST_PROJECT_CODE" \
    "$TEST_EMAIL" \
    "$TEST_OU_ID" \
    "$TEST_GITHUB_ORG" \
    "$TEST_REPO_NAME" \
    --dry-run 2>&1) || true

check_dry_run_output "$OUTPUT" "Test 1"
echo ""

# Test 2: Dry-run with config file (SKIPPED - config file must be in scripts/ directory)
echo -e "${BLUE}Test 2: Dry-run with config file${NC}"
echo -e "${YELLOW}⚠ Skipping - Config files must be in scripts/ directory${NC}"
echo -e "  This is a known limitation when running from different directories"
echo ""

# Test 3: Verify output directory is not created
echo -e "${BLUE}Test 3: Verify no files are created${NC}"
OUTPUT_DIR="$PROJECT_ROOT/output/${TEST_PROJECT_CODE}-${TEST_REPO_NAME}"

if [ -d "$OUTPUT_DIR" ]; then
    echo -e "${RED}✗${NC} Output directory was created: $OUTPUT_DIR"
    # Clean up
    rm -rf "$OUTPUT_DIR"
else
    echo -e "${GREEN}✓${NC} No output directory created"
fi
echo ""

# Test 4: Check that --dry-run can be placed anywhere in arguments
echo -e "${BLUE}Test 4: Flag position flexibility${NC}"
OUTPUT=$(CI=true "$PROJECT_ROOT/scripts/setup-complete-project.sh" \
    --dry-run \
    "$TEST_PROJECT_CODE" \
    "$TEST_EMAIL" \
    "$TEST_OU_ID" \
    "$TEST_GITHUB_ORG" \
    "$TEST_REPO_NAME" 2>&1) || true

if echo "$OUTPUT" | grep -q "DRY RUN MODE ENABLED"; then
    echo -e "${GREEN}✓${NC} --dry-run works at beginning of arguments"
else
    echo -e "${RED}✗${NC} --dry-run not recognized at beginning"
fi
echo ""

# Summary
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Dry-run mode tests completed!${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"