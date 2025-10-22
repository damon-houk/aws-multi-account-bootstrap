#!/usr/bin/env bash

# Test suite for config-manager.sh
# Tests all configuration functionality WITHOUT creating AWS/GitHub resources
#
# Usage: ./tests/test-config-system.sh

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

# Change to temp directory for tests
cd "$TEST_TEMP_DIR"

# Mock the UI functions that config-manager needs
success() { echo "[SUCCESS] $*"; }
info() { echo "[INFO] $*"; }
warning() { echo "[WARNING] $*"; }
error() { echo "[ERROR] $*"; }

# Source the config manager
source "$SCRIPT_DIR/lib/config-manager.sh"

# ============================================================================
# Test Helper Functions
# ============================================================================

test_start() {
    local test_name="$1"
    echo -e "${CYAN}Testing: $test_name${NC}"
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

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Values should be equal}"

    if [ "$expected" = "$actual" ]; then
        test_pass "$message (got: '$actual')"
        return 0
    else
        test_fail "$message (expected: '$expected', got: '$actual')"
        return 1
    fi
}

assert_empty() {
    local value="$1"
    local message="${2:-Value should be empty}"

    if [ -z "$value" ]; then
        test_pass "$message"
        return 0
    else
        test_fail "$message (got: '$value')"
        return 1
    fi
}

assert_not_empty() {
    local value="$1"
    local message="${2:-Value should not be empty}"

    if [ -n "$value" ]; then
        test_pass "$message (got: '$value')"
        return 0
    else
        test_fail "$message (was empty)"
        return 1
    fi
}

assert_return_code() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Return code check}"

    if [ "$expected" -eq "$actual" ]; then
        test_pass "$message (code: $actual)"
        return 0
    else
        test_fail "$message (expected: $expected, got: $actual)"
        return 1
    fi
}

# ============================================================================
# Unit Tests: Validation Functions
# ============================================================================

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Unit Tests: Validation Functions${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo

test_start "validate_project_code()"

validate_project_code "ABC"; assert_return_code 0 $? "Valid 3-letter code ABC"
validate_project_code "A12"; assert_return_code 0 $? "Valid alphanumeric code A12"
validate_project_code "999"; assert_return_code 0 $? "Valid numeric code 999"

validate_project_code "ab"; assert_return_code 1 $? "Reject 2-letter code"
validate_project_code "abcd"; assert_return_code 1 $? "Reject 4-letter code"
validate_project_code "abc"; assert_return_code 1 $? "Reject lowercase code"
validate_project_code "A-B"; assert_return_code 1 $? "Reject special characters"
validate_project_code ""; assert_return_code 1 $? "Reject empty string"

echo

test_start "validate_email_prefix()"

validate_email_prefix "user@example.com"; assert_return_code 0 $? "Valid email"
validate_email_prefix "user.name@example.com"; assert_return_code 0 $? "Email with dot"
validate_email_prefix "user+tag@example.com"; assert_return_code 0 $? "Email with plus"
validate_email_prefix "user123@example.co.uk"; assert_return_code 0 $? "Email with subdomain"

validate_email_prefix "invalid"; assert_return_code 1 $? "Reject no @"
validate_email_prefix "@example.com"; assert_return_code 1 $? "Reject no user part"
validate_email_prefix "user@"; assert_return_code 1 $? "Reject no domain"
validate_email_prefix ""; assert_return_code 1 $? "Reject empty email"

echo

test_start "validate_ou_id()"

validate_ou_id "ou-abcd-12345678"; assert_return_code 0 $? "Valid OU ID"
validate_ou_id "ou-root-abcdefgh"; assert_return_code 0 $? "Valid root OU"
validate_ou_id "ou-1234-abcdefgh"; assert_return_code 0 $? "Valid with numbers"

validate_ou_id "ou-ab-123"; assert_return_code 1 $? "Reject short second part"
validate_ou_id "ou-abcd"; assert_return_code 1 $? "Reject missing third part"
validate_ou_id "r-abcd-12345678"; assert_return_code 1 $? "Reject wrong prefix"
validate_ou_id "ou-ABCD-12345678"; assert_return_code 1 $? "Reject uppercase"
validate_ou_id ""; assert_return_code 1 $? "Reject empty OU"

echo

# ============================================================================
# Unit Tests: Config File Detection
# ============================================================================

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Unit Tests: Config File Detection${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo

test_start "detect_config_file()"

# Test with no config files
result=$(detect_config_file)
assert_empty "$result" "No config file when none exists"

# Test YAML priority
echo "PROJECT_CODE: YML" > .aws-bootstrap.yml
result=$(detect_config_file)
assert_equals ".aws-bootstrap.yml" "$result" "Detects .yml file"
rm .aws-bootstrap.yml

echo "PROJECT_CODE: YAML" > .aws-bootstrap.yaml
result=$(detect_config_file)
assert_equals ".aws-bootstrap.yaml" "$result" "Detects .yaml file"

# Test YAML over JSON priority
echo '{"PROJECT_CODE": "JSON"}' > .aws-bootstrap.json
result=$(detect_config_file)
assert_equals ".aws-bootstrap.yaml" "$result" "YAML takes priority over JSON"
rm .aws-bootstrap.yaml

result=$(detect_config_file)
assert_equals ".aws-bootstrap.json" "$result" "Detects JSON when no YAML"
rm .aws-bootstrap.json

echo

test_start "get_config_file_type()"

result=$(get_config_file_type ".aws-bootstrap.yml")
assert_equals "yaml" "$result" "Recognizes .yml as YAML"

result=$(get_config_file_type ".aws-bootstrap.yaml")
assert_equals "yaml" "$result" "Recognizes .yaml as YAML"

result=$(get_config_file_type ".aws-bootstrap.json")
assert_equals "json" "$result" "Recognizes .json as JSON"

result=$(get_config_file_type "unknown.txt")
assert_equals "unknown" "$result" "Returns unknown for other extensions"

echo

# ============================================================================
# Unit Tests: Config Parsing
# ============================================================================

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Unit Tests: Config Parsing${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo

test_start "parse_config_value() - JSON"

# Create test JSON config
cat > test-config.json <<EOF
{
  "PROJECT_CODE": "TST",
  "EMAIL_PREFIX": "test@example.com",
  "OU_ID": "ou-test-12345678",
  "GITHUB_ORG": "test-org",
  "REPO_NAME": "test-repo"
}
EOF

if command -v jq &> /dev/null; then
    result=$(parse_config_value "PROJECT_CODE" "test-config.json")
    assert_equals "TST" "$result" "Parse PROJECT_CODE from JSON"

    result=$(parse_config_value "EMAIL_PREFIX" "test-config.json")
    assert_equals "test@example.com" "$result" "Parse EMAIL_PREFIX from JSON"

    result=$(parse_config_value "NONEXISTENT" "test-config.json")
    assert_empty "$result" "Returns empty for missing JSON key"
else
    test_fail "jq not installed - skipping JSON tests"
fi

rm test-config.json
echo

test_start "parse_config_value() - YAML"

# Create test YAML config
cat > test-config.yml <<EOF
PROJECT_CODE: YML
EMAIL_PREFIX: yaml@example.com
OU_ID: ou-yaml-87654321
GITHUB_ORG: yaml-org
REPO_NAME: yaml-repo
EOF

if command -v yq &> /dev/null; then
    result=$(parse_config_value "PROJECT_CODE" "test-config.yml")
    assert_equals "YML" "$result" "Parse PROJECT_CODE from YAML"

    result=$(parse_config_value "EMAIL_PREFIX" "test-config.yml")
    assert_equals "yaml@example.com" "$result" "Parse EMAIL_PREFIX from YAML"

    result=$(parse_config_value "NONEXISTENT" "test-config.yml")
    assert_empty "$result" "Returns empty for missing YAML key"
else
    echo -e "  ${YELLOW}⚠${NC} yq not installed - skipping YAML tests (this is OK, YAML is optional)"
fi

rm test-config.yml
echo

# ============================================================================
# Unit Tests: Mode Detection
# ============================================================================

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Unit Tests: Mode Detection${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo

test_start "detect_mode()"

# Test default mode
unset BOOTSTRAP_MODE CI GITHUB_ACTIONS GITLAB_CI
result=$(detect_mode)
assert_equals "interactive" "$result" "Default mode is interactive"

# Test explicit mode
export BOOTSTRAP_MODE="ci"
result=$(detect_mode)
assert_equals "ci" "$result" "Explicit BOOTSTRAP_MODE=ci"

export BOOTSTRAP_MODE="interactive"
result=$(detect_mode)
assert_equals "interactive" "$result" "Explicit BOOTSTRAP_MODE=interactive"
unset BOOTSTRAP_MODE

# Test CI environment detection
export CI="true"
result=$(detect_mode)
assert_equals "ci" "$result" "Auto-detect CI environment"
unset CI

export GITHUB_ACTIONS="true"
result=$(detect_mode)
assert_equals "ci" "$result" "Auto-detect GitHub Actions"
unset GITHUB_ACTIONS

export GITLAB_CI="true"
result=$(detect_mode)
assert_equals "ci" "$result" "Auto-detect GitLab CI"
unset GITLAB_CI

echo

# ============================================================================
# Integration Tests: Configuration Precedence
# ============================================================================

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Integration Tests: Configuration Precedence${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo

test_start "get_config() - Interactive Mode Precedence"

# Setup: Create config file
cat > .aws-bootstrap.json <<EOF
{
  "PROJECT_CODE": "CFG",
  "EMAIL_PREFIX": "config@example.com"
}
EOF

# Test 1: CLI argument takes precedence over config file
unset BOOTSTRAP_MODE BOOTSTRAP_PROJECT_CODE
export BOOTSTRAP_MODE="interactive"
result=$(get_config "PROJECT_CODE" "CLI")
assert_equals "CLI" "$result" "CLI args override config file in interactive mode"

# Test 2: Config file used when no CLI arg
result=$(get_config "EMAIL_PREFIX" "")
assert_equals "config@example.com" "$result" "Config file used when no CLI arg"

# Test 3: Environment variables ignored in interactive mode
export BOOTSTRAP_EMAIL_PREFIX="env@example.com"
result=$(get_config "EMAIL_PREFIX" "")
assert_equals "config@example.com" "$result" "Env vars ignored in interactive mode"
unset BOOTSTRAP_EMAIL_PREFIX

rm .aws-bootstrap.json
unset BOOTSTRAP_MODE
echo

test_start "get_config() - CI Mode Precedence"

# Setup: Create config file
cat > .aws-bootstrap.json <<EOF
{
  "PROJECT_CODE": "CFG",
  "EMAIL_PREFIX": "config@example.com",
  "OU_ID": "ou-conf-12345678"
}
EOF

export BOOTSTRAP_MODE="ci"

# Test 1: CLI argument highest priority
result=$(get_config "PROJECT_CODE" "CLI")
assert_equals "CLI" "$result" "CLI args override everything in CI mode"

# Test 2: Environment variables override config file
export BOOTSTRAP_PROJECT_CODE="ENV"
result=$(get_config "PROJECT_CODE" "")
assert_equals "ENV" "$result" "Env vars override config file in CI mode"
unset BOOTSTRAP_PROJECT_CODE

# Test 3: Config file used as fallback
result=$(get_config "OU_ID" "")
assert_equals "ou-conf-12345678" "$result" "Config file used as fallback in CI mode"

# Test 4: Empty when nothing provides value
result=$(get_config "GITHUB_ORG" "")
assert_empty "$result" "Returns empty when no source provides value"

rm .aws-bootstrap.json
unset BOOTSTRAP_MODE
echo

# ============================================================================
# Integration Tests: Mixed Sources
# ============================================================================

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Integration Tests: Mixed Configuration Sources${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo

test_start "Multiple config sources with validation"

# Create both YAML and JSON configs (YAML should take priority)
if command -v yq &> /dev/null; then
    cat > .aws-bootstrap.yml <<EOF
PROJECT_CODE: YML
EMAIL_PREFIX: yaml@example.com
EOF
fi

cat > .aws-bootstrap.json <<EOF
{
  "PROJECT_CODE": "JSN",
  "EMAIL_PREFIX": "json@example.com",
  "OU_ID": "ou-json-12345678"
}
EOF

# Set some environment variables
export BOOTSTRAP_MODE="ci"
export BOOTSTRAP_GITHUB_ORG="env-org"
export BOOTSTRAP_REPO_NAME="env-repo"

# Test complete configuration gathering
result=$(get_config "PROJECT_CODE" "")
if command -v yq &> /dev/null; then
    assert_equals "YML" "$result" "YAML config takes priority over JSON"
else
    assert_equals "JSN" "$result" "JSON config used when yq not available"
fi

result=$(get_config "GITHUB_ORG" "")
assert_equals "env-org" "$result" "Environment variable provides value"

result=$(get_config "OU_ID" "")
assert_equals "ou-json-12345678" "$result" "JSON provides value not in YAML"

# Cleanup
rm -f .aws-bootstrap.yml .aws-bootstrap.json
unset BOOTSTRAP_MODE BOOTSTRAP_GITHUB_ORG BOOTSTRAP_REPO_NAME

echo

# ============================================================================
# Test Summary
# ============================================================================

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Test Results Summary${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo

echo -e "Tests Run:    ${CYAN}$TESTS_RUN${NC}"
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  ✓ ALL TESTS PASSED!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 0
else
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}  ✗ SOME TESTS FAILED${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 1
fi