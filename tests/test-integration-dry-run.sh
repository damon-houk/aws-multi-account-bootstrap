#!/usr/bin/env bash

# Integration test for setup-complete-project.sh in dry-run mode
# Tests the configuration flow WITHOUT creating AWS/GitHub resources
#
# Usage: ./tests/test-integration-dry-run.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Get script directory
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$TEST_DIR/.." && pwd)"
SCRIPT_DIR="$PROJECT_ROOT/scripts"

# Create temp directory for test files
TEST_TEMP_DIR="$(mktemp -d)"
trap "rm -rf $TEST_TEMP_DIR" EXIT

# ============================================================================
# Test Helper Functions
# ============================================================================

test_scenario() {
    local scenario_name="$1"
    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  Scenario: $scenario_name${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    ((TESTS_RUN++))
}

test_pass() {
    local message="$1"
    echo -e "  ${GREEN}✓${NC} $message"
    ((TESTS_PASSED++))
}

test_fail() {
    local message="$1"
    echo -e "  ${RED}✗${NC} $message"
    ((TESTS_FAILED++))
}

# Create a modified setup script that doesn't execute AWS/GitHub commands
create_dry_run_setup() {
    cat > "$TEST_TEMP_DIR/setup-dry-run.sh" <<'EOF'
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source real config manager
source "REAL_SCRIPT_DIR/lib/config-manager.sh"

# Mock the prerequisite checker to avoid real checks
check_all_prerequisites() {
    echo "✓ Prerequisites check (mocked)"
    return 0
}

# Parse CLI arguments
CLI_PROJECT_CODE=""
CLI_EMAIL_PREFIX=""
CLI_OU_ID=""
CLI_GITHUB_ORG=""
CLI_REPO_NAME=""

if [ "${#@}" -ge 1 ]; then CLI_PROJECT_CODE="$1"; fi
if [ "${#@}" -ge 2 ]; then CLI_EMAIL_PREFIX="$2"; fi
if [ "${#@}" -ge 3 ]; then CLI_OU_ID="$3"; fi
if [ "${#@}" -ge 4 ]; then CLI_GITHUB_ORG="$4"; fi
if [ "${#@}" -ge 5 ]; then CLI_REPO_NAME="$5"; fi

# Detect mode
MODE=$(detect_mode)
echo "MODE=$MODE"

# Show config file info if in interactive mode
if [ "$MODE" = "interactive" ]; then
    CONFIG_FILE=$(detect_config_file)
    if [ -n "$CONFIG_FILE" ]; then
        echo "CONFIG_FILE=$CONFIG_FILE"
    fi
fi

# Load configuration values
PROJECT_CODE=$(get_config "PROJECT_CODE" "$CLI_PROJECT_CODE")
EMAIL_PREFIX=$(get_config "EMAIL_PREFIX" "$CLI_EMAIL_PREFIX")
OU_ID=$(get_config "OU_ID" "$CLI_OU_ID")
GITHUB_ORG=$(get_config "GITHUB_ORG" "$CLI_GITHUB_ORG")
REPO_NAME=$(get_config "REPO_NAME" "$CLI_REPO_NAME")

# Handle missing values based on mode
if [ "$MODE" = "ci" ]; then
    MISSING=()
    [ -z "$PROJECT_CODE" ] && MISSING+=("PROJECT_CODE")
    [ -z "$EMAIL_PREFIX" ] && MISSING+=("EMAIL_PREFIX")
    [ -z "$OU_ID" ] && MISSING+=("OU_ID")
    [ -z "$GITHUB_ORG" ] && MISSING+=("GITHUB_ORG")
    [ -z "$REPO_NAME" ] && MISSING+=("REPO_NAME")

    if [ ${#MISSING[@]} -gt 0 ]; then
        echo "ERROR: Missing required configuration in CI mode"
        echo "Missing: ${MISSING[*]}"
        exit 1
    fi
fi

# Output the final configuration
echo "FINAL_CONFIG:"
echo "  PROJECT_CODE=$PROJECT_CODE"
echo "  EMAIL_PREFIX=$EMAIL_PREFIX"
echo "  OU_ID=$OU_ID"
echo "  GITHUB_ORG=$GITHUB_ORG"
echo "  REPO_NAME=$REPO_NAME"

# Validate inputs if we have them
if [ -n "$PROJECT_CODE" ]; then
    if validate_project_code "$PROJECT_CODE"; then
        echo "  PROJECT_CODE_VALID=true"
    else
        echo "  PROJECT_CODE_VALID=false"
        exit 1
    fi
fi

if [ -n "$EMAIL_PREFIX" ]; then
    if validate_email_prefix "$EMAIL_PREFIX"; then
        echo "  EMAIL_PREFIX_VALID=true"
    else
        echo "  EMAIL_PREFIX_VALID=false"
        exit 1
    fi
fi

if [ -n "$OU_ID" ]; then
    if validate_ou_id "$OU_ID"; then
        echo "  OU_ID_VALID=true"
    else
        echo "  OU_ID_VALID=false"
        exit 1
    fi
fi

echo "DRY_RUN_SUCCESS"
EOF

    # Replace the real script directory
    sed -i.bak "s|REAL_SCRIPT_DIR|$SCRIPT_DIR|g" "$TEST_TEMP_DIR/setup-dry-run.sh"
    chmod +x "$TEST_TEMP_DIR/setup-dry-run.sh"
}

# ============================================================================
# Test Scenarios
# ============================================================================

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Integration Tests: Configuration Flow (Dry Run)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Create the dry-run setup script
create_dry_run_setup

# Change to temp directory for tests
cd "$TEST_TEMP_DIR"

# ============================================================================
# Scenario 1: CLI Arguments Only (No Config File)
# ============================================================================

test_scenario "CLI Arguments Only (No Config File)"

output=$("$TEST_TEMP_DIR/setup-dry-run.sh" "TST" "test@example.com" "ou-test-12345678" "test-org" "test-repo" 2>&1)

if echo "$output" | grep -q "DRY_RUN_SUCCESS"; then
    test_pass "Setup completed with CLI arguments"
else
    test_fail "Setup failed with CLI arguments"
fi

if echo "$output" | grep -q "PROJECT_CODE=TST"; then
    test_pass "PROJECT_CODE correctly set from CLI"
else
    test_fail "PROJECT_CODE not set correctly"
fi

if echo "$output" | grep -q "EMAIL_PREFIX=test@example.com"; then
    test_pass "EMAIL_PREFIX correctly set from CLI"
else
    test_fail "EMAIL_PREFIX not set correctly"
fi

# ============================================================================
# Scenario 2: JSON Config File
# ============================================================================

test_scenario "JSON Config File"

# Create JSON config
cat > .aws-bootstrap.json <<EOF
{
  "PROJECT_CODE": "JSN",
  "EMAIL_PREFIX": "json@example.com",
  "OU_ID": "ou-json-12345678",
  "GITHUB_ORG": "json-org",
  "REPO_NAME": "json-repo"
}
EOF

output=$("$TEST_TEMP_DIR/setup-dry-run.sh" 2>&1)

if echo "$output" | grep -q "CONFIG_FILE=.aws-bootstrap.json"; then
    test_pass "JSON config file detected"
else
    test_fail "JSON config file not detected"
fi

if echo "$output" | grep -q "PROJECT_CODE=JSN"; then
    test_pass "PROJECT_CODE loaded from JSON"
else
    test_fail "PROJECT_CODE not loaded from JSON"
fi

rm .aws-bootstrap.json

# ============================================================================
# Scenario 3: YAML Config File (if yq available)
# ============================================================================

if command -v yq &> /dev/null; then
    test_scenario "YAML Config File"

    # Create YAML config
    cat > .aws-bootstrap.yml <<EOF
PROJECT_CODE: YML
EMAIL_PREFIX: yaml@example.com
OU_ID: ou-yaml-87654321
GITHUB_ORG: yaml-org
REPO_NAME: yaml-repo
EOF

    output=$("$TEST_TEMP_DIR/setup-dry-run.sh" 2>&1)

    if echo "$output" | grep -q "CONFIG_FILE=.aws-bootstrap.yml"; then
        test_pass "YAML config file detected"
    else
        test_fail "YAML config file not detected"
    fi

    if echo "$output" | grep -q "PROJECT_CODE=YML"; then
        test_pass "PROJECT_CODE loaded from YAML"
    else
        test_fail "PROJECT_CODE not loaded from YAML"
    fi

    rm .aws-bootstrap.yml
else
    echo -e "  ${YELLOW}⚠${NC} Skipping YAML test (yq not installed)"
fi

# ============================================================================
# Scenario 4: CI Mode with Environment Variables
# ============================================================================

test_scenario "CI Mode with Environment Variables"

export BOOTSTRAP_MODE="ci"
export BOOTSTRAP_PROJECT_CODE="ENV"
export BOOTSTRAP_EMAIL_PREFIX="env@example.com"
export BOOTSTRAP_OU_ID="ou-env-12345678"
export BOOTSTRAP_GITHUB_ORG="env-org"
export BOOTSTRAP_REPO_NAME="env-repo"

output=$("$TEST_TEMP_DIR/setup-dry-run.sh" 2>&1)

if echo "$output" | grep -q "MODE=ci"; then
    test_pass "CI mode detected"
else
    test_fail "CI mode not detected"
fi

if echo "$output" | grep -q "PROJECT_CODE=ENV"; then
    test_pass "PROJECT_CODE loaded from environment"
else
    test_fail "PROJECT_CODE not loaded from environment"
fi

if echo "$output" | grep -q "DRY_RUN_SUCCESS"; then
    test_pass "CI mode completed successfully"
else
    test_fail "CI mode failed"
fi

unset BOOTSTRAP_MODE BOOTSTRAP_PROJECT_CODE BOOTSTRAP_EMAIL_PREFIX BOOTSTRAP_OU_ID BOOTSTRAP_GITHUB_ORG BOOTSTRAP_REPO_NAME

# ============================================================================
# Scenario 5: CI Mode Missing Values (Should Fail)
# ============================================================================

test_scenario "CI Mode with Missing Values (Should Fail)"

export BOOTSTRAP_MODE="ci"
export BOOTSTRAP_PROJECT_CODE="CIM"
# Deliberately missing other values

output=$("$TEST_TEMP_DIR/setup-dry-run.sh" 2>&1 || true)

if echo "$output" | grep -q "ERROR: Missing required configuration in CI mode"; then
    test_pass "CI mode correctly fails with missing values"
else
    test_fail "CI mode should fail with missing values"
fi

if echo "$output" | grep -q "Missing:.*EMAIL_PREFIX"; then
    test_pass "Missing EMAIL_PREFIX detected"
else
    test_fail "Missing EMAIL_PREFIX not reported"
fi

unset BOOTSTRAP_MODE BOOTSTRAP_PROJECT_CODE

# ============================================================================
# Scenario 6: Precedence Test - CLI over Config File
# ============================================================================

test_scenario "Precedence: CLI Arguments Override Config File"

# Create config file
cat > .aws-bootstrap.json <<EOF
{
  "PROJECT_CODE": "CFG",
  "EMAIL_PREFIX": "config@example.com",
  "OU_ID": "ou-conf-12345678"
}
EOF

# Run with CLI argument that should override config
output=$("$TEST_TEMP_DIR/setup-dry-run.sh" "CLI" "" "" "cli-org" "" 2>&1)

if echo "$output" | grep -q "PROJECT_CODE=CLI"; then
    test_pass "CLI argument overrides config file"
else
    test_fail "CLI argument did not override config file"
fi

if echo "$output" | grep -q "EMAIL_PREFIX=config@example.com"; then
    test_pass "Config file used for non-CLI values"
else
    test_fail "Config file not used for non-CLI values"
fi

rm .aws-bootstrap.json

# ============================================================================
# Scenario 7: Validation Tests
# ============================================================================

test_scenario "Input Validation"

# Test invalid PROJECT_CODE
output=$("$TEST_TEMP_DIR/setup-dry-run.sh" "ab" "test@example.com" "ou-test-12345678" "test-org" "test-repo" 2>&1 || true)

if echo "$output" | grep -q "PROJECT_CODE_VALID=false"; then
    test_pass "Invalid PROJECT_CODE rejected (too short)"
else
    test_fail "Invalid PROJECT_CODE not rejected"
fi

# Test invalid email
output=$("$TEST_TEMP_DIR/setup-dry-run.sh" "ABC" "invalid-email" "ou-test-12345678" "test-org" "test-repo" 2>&1 || true)

if echo "$output" | grep -q "EMAIL_PREFIX_VALID=false"; then
    test_pass "Invalid EMAIL_PREFIX rejected"
else
    test_fail "Invalid EMAIL_PREFIX not rejected"
fi

# Test invalid OU_ID
output=$("$TEST_TEMP_DIR/setup-dry-run.sh" "ABC" "test@example.com" "invalid-ou" "test-org" "test-repo" 2>&1 || true)

if echo "$output" | grep -q "OU_ID_VALID=false"; then
    test_pass "Invalid OU_ID rejected"
else
    test_fail "Invalid OU_ID not rejected"
fi

# ============================================================================
# Scenario 8: Mixed Configuration Sources
# ============================================================================

test_scenario "Mixed Configuration Sources"

# Create partial config file
cat > .aws-bootstrap.json <<EOF
{
  "PROJECT_CODE": "MIX",
  "EMAIL_PREFIX": "config@example.com"
}
EOF

# Set some environment variables
export BOOTSTRAP_MODE="ci"
export BOOTSTRAP_OU_ID="ou-env-12345678"
export BOOTSTRAP_GITHUB_ORG="env-org"

# Run with some CLI arguments
output=$("$TEST_TEMP_DIR/setup-dry-run.sh" "" "" "" "" "cli-repo" 2>&1)

if echo "$output" | grep -q "PROJECT_CODE=MIX"; then
    test_pass "PROJECT_CODE from config file"
else
    test_fail "PROJECT_CODE not from config file"
fi

if echo "$output" | grep -q "OU_ID=ou-env-12345678"; then
    test_pass "OU_ID from environment variable"
else
    test_fail "OU_ID not from environment variable"
fi

if echo "$output" | grep -q "REPO_NAME=cli-repo"; then
    test_pass "REPO_NAME from CLI argument"
else
    test_fail "REPO_NAME not from CLI argument"
fi

rm .aws-bootstrap.json
unset BOOTSTRAP_MODE BOOTSTRAP_OU_ID BOOTSTRAP_GITHUB_ORG

# ============================================================================
# Test Summary
# ============================================================================

echo
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Integration Test Results${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo

echo -e "Scenarios Run: ${CYAN}$TESTS_RUN${NC}"
echo -e "Tests Passed:  ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed:  ${RED}$TESTS_FAILED${NC}"
echo

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  ✓ ALL INTEGRATION TESTS PASSED!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 0
else
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}  ✗ SOME INTEGRATION TESTS FAILED${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 1
fi