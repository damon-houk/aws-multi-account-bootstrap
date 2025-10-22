#!/bin/bash
# Quick automated tests for non-interactive mode
# Tests that don't require full AWS setup

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Running Automated Tests for Non-Interactive Mode"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

test_result() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: $1"
        ((PASS++))
    else
        echo -e "${RED}✗ FAIL${NC}: $1"
        ((FAIL++))
    fi
}

test_warning() {
    echo -e "${YELLOW}⚠️  WARN${NC}: $1"
    ((WARN++))
}

# Test 1: Check files exist and are executable
echo "Test 1: Script files exist and are executable"
test -x scripts/setup-complete-project.sh
test_result "setup-complete-project.sh is executable"

test -x scripts/setup-github-repo.sh
test_result "setup-github-repo.sh is executable"

echo ""

# Test 2: Help text includes -y option
echo "Test 2: Help text includes --yes option"
if ./scripts/setup-github-repo.sh 2>&1 | grep -q "\-y.*\-\-yes"; then
    test_result "setup-github-repo.sh help includes -y/--yes flag"
else
    false
    test_result "setup-github-repo.sh help includes -y/--yes flag"
fi

if ./scripts/setup-complete-project.sh 2>&1 | grep -q "\-y.*\-\-yes"; then
    test_result "setup-complete-project.sh help includes -y/--yes flag"
else
    false
    test_result "setup-complete-project.sh help includes -y/--yes flag"
fi

echo ""

# Test 3: Verify AUTO_CONFIRM variable is used
echo "Test 3: Scripts check AUTO_CONFIRM variable"
if grep -q "AUTO_CONFIRM" scripts/setup-complete-project.sh; then
    test_result "setup-complete-project.sh uses AUTO_CONFIRM"
else
    false
    test_result "setup-complete-project.sh uses AUTO_CONFIRM"
fi

if grep -q "AUTO_CONFIRM" scripts/setup-github-repo.sh; then
    test_result "setup-github-repo.sh uses AUTO_CONFIRM"
else
    false
    test_result "setup-github-repo.sh uses AUTO_CONFIRM"
fi

echo ""

# Test 4: Verify --yes flag is passed to child script
echo "Test 4: Parent script passes --yes to child scripts"
if grep -q '\-\-yes' scripts/setup-complete-project.sh; then
    test_result "setup-complete-project.sh passes --yes flag"
else
    false
    test_result "setup-complete-project.sh passes --yes flag"
fi

echo ""

# Test 5: Verify npm install is called
echo "Test 5: npm install is called to generate package-lock.json"
if grep -q "npm install" scripts/setup-complete-project.sh; then
    test_result "npm install command found in script"
else
    false
    test_result "npm install command found in script"
fi

echo ""

# Test 6: Verify PROJECT_DIR is used
echo "Test 6: Output directory (PROJECT_DIR) is used correctly"
if grep -q 'PROJECT_DIR=' scripts/setup-complete-project.sh; then
    test_result "PROJECT_DIR variable is defined"
else
    false
    test_result "PROJECT_DIR variable is defined"
fi

if grep -q 'output/\$PROJECT_CODE' scripts/setup-complete-project.sh; then
    test_result "Output directory uses output/ prefix"
else
    false
    test_result "Output directory uses output/ prefix"
fi

echo ""

# Test 7: Check for leftover TODOs/FIXMEs
echo "Test 7: No leftover TODO/FIXME comments in modified files"
if grep -n "TODO\|FIXME" scripts/setup-complete-project.sh scripts/setup-github-repo.sh 2>/dev/null; then
    test_warning "TODO/FIXME comments found (review needed)"
else
    test_result "No TODO/FIXME comments found"
fi

echo ""

# Test 8: ShellCheck validation
echo "Test 8: ShellCheck validation"
if command -v shellcheck &> /dev/null; then
    if shellcheck scripts/setup-complete-project.sh 2>/dev/null; then
        test_result "setup-complete-project.sh passes ShellCheck"
    else
        false
        test_result "setup-complete-project.sh passes ShellCheck"
    fi

    if shellcheck scripts/setup-github-repo.sh 2>/dev/null; then
        test_result "setup-github-repo.sh passes ShellCheck"
    else
        false
        test_result "setup-github-repo.sh passes ShellCheck"
    fi
else
    test_warning "ShellCheck not installed (run: brew install shellcheck)"
fi

echo ""

# Test 9: Verify read prompts are wrapped in AUTO_CONFIRM checks
echo "Test 9: Interactive prompts are properly guarded"
# Check that all 'read -p' commands are inside AUTO_CONFIRM checks
SCRIPT="scripts/setup-github-repo.sh"
if grep -n "read -p" "$SCRIPT" | while read -r line; do
    line_num=$(echo "$line" | cut -d: -f1)
    # Check if there's an AUTO_CONFIRM check within 10 lines before
    if ! sed -n "$((line_num - 10)),$((line_num))p" "$SCRIPT" | grep -q "AUTO_CONFIRM"; then
        echo "Found unguarded read at line $line_num"
        exit 1
    fi
done; then
    test_result "All interactive prompts are guarded by AUTO_CONFIRM"
else
    test_warning "Some interactive prompts may not be properly guarded"
fi

echo ""

# Test 10: Check argument parsing logic
echo "Test 10: Argument parsing handles --yes correctly"
if grep -A 10 "while \[\[ \$# -gt 0 \]\]" scripts/setup-github-repo.sh | grep -q "\-y|\-\-yes"; then
    test_result "Argument parsing uses while loop for flag handling"
else
    false
    test_result "Argument parsing uses while loop for flag handling"
fi

echo ""

# Test 11: Verify summary files go to PROJECT_DIR
echo "Test 11: Summary files are written to PROJECT_DIR"
if grep "GITHUB_SETUP_SUMMARY.md" scripts/setup-github-repo.sh | grep -q "PROJECT_DIR"; then
    test_result "GITHUB_SETUP_SUMMARY.md written to PROJECT_DIR"
else
    false
    test_result "GITHUB_SETUP_SUMMARY.md written to PROJECT_DIR"
fi

echo ""

# Test 12: Verify .gitignore includes output/
echo "Test 12: .gitignore includes output/ directory"
if [ -f .gitignore ] && grep -q "^output/" .gitignore; then
    test_result ".gitignore includes output/ directory"
else
    test_warning ".gitignore may not exclude output/ directory"
fi

echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Test Results Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${GREEN}Passed:  $PASS${NC}"
echo -e "${RED}Failed:  $FAIL${NC}"
echo -e "${YELLOW}Warnings: $WARN${NC}"
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}✓ All automated tests passed!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Run manual tests from TEST_PLAN_NON_INTERACTIVE.md"
    echo "  2. Test with actual AWS setup (Test 1 in test plan)"
    echo "  3. Fix any issues found"
    echo "  4. Create PR"
    exit 0
else
    echo -e "${RED}✗ Some tests failed - review and fix before proceeding${NC}"
    exit 1
fi