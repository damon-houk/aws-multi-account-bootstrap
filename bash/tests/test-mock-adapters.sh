#!/usr/bin/env bash

# ============================================================================
# Mock Adapters Test Suite
# ============================================================================
#
# Tests that mock adapters correctly implement the port interfaces.
# These tests run WITHOUT any AWS or GitHub credentials.
#
# Usage: ./tests/test-mock-adapters.sh
#
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Get directories
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$TEST_DIR/.." && pwd)"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test helper functions
test_start() {
    echo -n "  Testing: $1 ... "
    TESTS_RUN=$((TESTS_RUN + 1))
}

test_pass() {
    echo -e "${GREEN}✓${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

test_fail() {
    echo -e "${RED}✗${NC}"
    echo -e "${RED}    Error: $1${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

assert_equals() {
    local expected=$1
    local actual=$2
    local message=${3:-}

    if [ "$expected" = "$actual" ]; then
        test_pass
    else
        test_fail "Expected '$expected', got '$actual'. $message"
    fi
}

assert_contains() {
    local haystack=$1
    local needle=$2

    if echo "$haystack" | grep -q "$needle"; then
        test_pass
    else
        test_fail "Expected output to contain '$needle'"
    fi
}

assert_success() {
    local exit_code=$1
    if [ "$exit_code" -eq 0 ]; then
        test_pass
    else
        test_fail "Expected exit code 0, got $exit_code"
    fi
}

echo "========================================="
echo "  Mock Adapters Test Suite"
echo "========================================="
echo ""

# ============================================================================
# Cloud Provider Mock Adapter Tests
# ============================================================================

echo "Cloud Provider Mock Adapter Tests"
echo "-----------------------------------"

# Source the mock adapter
# shellcheck source=scripts/ports/cloud-provider-port.sh
source "$PROJECT_ROOT/scripts/ports/cloud-provider-port.sh"
# shellcheck source=scripts/adapters/mock/mock-cloud-adapter.sh
source "$PROJECT_ROOT/scripts/adapters/mock/mock-cloud-adapter.sh"

# Test: Adapter name
test_start "cloud_provider_name returns 'Mock'"
result=$(cloud_provider_name)
assert_equals "Mock" "$result"

# Test: Create account
test_start "cloud_provider_create_account creates account"
account_id=$(cloud_provider_create_account "TestAccount" "test@example.com" "ou-test-12345678")
if [[ $account_id =~ ^MOCK[0-9]{9}$ ]]; then
    test_pass
else
    test_fail "Expected account ID matching MOCK[0-9]{9}, got '$account_id'"
fi

# Test: Get account ID
test_start "cloud_provider_get_account_id retrieves account"
retrieved_id=$(cloud_provider_get_account_id "TestAccount")
assert_equals "$account_id" "$retrieved_id"

# Test: Duplicate account creation returns same ID
test_start "cloud_provider_create_account returns existing account ID for duplicate"
duplicate_id=$(cloud_provider_create_account "TestAccount" "test@example.com" "ou-test-12345678")
assert_equals "$account_id" "$duplicate_id"

# Test: OIDC provider creation
test_start "cloud_provider_create_oidc_provider returns ARN"
provider_arn=$(cloud_provider_create_oidc_provider "$account_id" "https://token.actions.githubusercontent.com" "sts.amazonaws.com")
if [[ $provider_arn =~ ^arn:aws:iam ]]; then
    test_pass
else
    test_fail "Expected ARN starting with 'arn:aws:iam', got '$provider_arn'"
fi

# Test: OIDC role creation
test_start "cloud_provider_create_oidc_role returns role ARN"
role_arn=$(cloud_provider_create_oidc_role "$account_id" "GitHubActionsRole" "$provider_arn" "myorg/myrepo" "")
if [[ $role_arn =~ ^arn:aws:iam.*role/GitHubActionsRole ]]; then
    test_pass
else
    test_fail "Expected role ARN, got '$role_arn'"
fi

# Test: CDK bootstrap
test_start "cloud_provider_bootstrap_cdk succeeds"
cloud_provider_bootstrap_cdk "$account_id" "us-east-1" "OrganizationAccountAccessRole"
assert_success $?

# Test: Create budget
test_start "cloud_provider_create_budget succeeds"
cloud_provider_create_budget "$account_id" "MonthlyBudget" "25" "alerts@example.com"
assert_success $?

# Test: Create SNS topic
test_start "cloud_provider_create_sns_topic returns topic ARN"
topic_arn=$(cloud_provider_create_sns_topic "$account_id" "BillingAlerts")
if [[ $topic_arn =~ ^arn:aws:sns ]]; then
    test_pass
else
    test_fail "Expected SNS topic ARN, got '$topic_arn'"
fi

# Test: Subscribe email to topic
test_start "cloud_provider_subscribe_email_to_topic succeeds"
cloud_provider_subscribe_email_to_topic "$account_id" "$topic_arn" "alerts@example.com"
assert_success $?

# Test: Get caller identity
test_start "cloud_provider_get_caller_identity returns JSON"
identity=$(cloud_provider_get_caller_identity)
if echo "$identity" | grep -q "Account"; then
    test_pass
else
    test_fail "Expected JSON with 'Account' field"
fi

# Test: Operation logging
test_start "mock_count_operations counts create_account operations"
count=$(mock_count_operations "create_account")
if [ "$count" -ge 2 ]; then
    test_pass
else
    test_fail "Expected at least 2 create_account operations, got $count"
fi

# Test: Verify specific operation
test_start "mock_verify_operation finds specific account creation"
if mock_verify_operation "create_account" "name=TestAccount"; then
    test_pass
else
    test_fail "Could not verify TestAccount creation in log"
fi

echo ""

# ============================================================================
# VCS Provider Mock Adapter Tests
# ============================================================================

echo "VCS Provider Mock Adapter Tests"
echo "--------------------------------"

# Source the mock VCS adapter
# shellcheck source=scripts/ports/vcs-provider-port.sh
source "$PROJECT_ROOT/scripts/ports/vcs-provider-port.sh"
# shellcheck source=scripts/adapters/mock/mock-vcs-adapter.sh
source "$PROJECT_ROOT/scripts/adapters/mock/mock-vcs-adapter.sh"

# Test: Adapter name
test_start "vcs_provider_name returns 'Mock'"
result=$(vcs_provider_name)
assert_equals "Mock" "$result"

# Test: Create repository
test_start "vcs_provider_create_repo creates repository"
repo_url=$(vcs_provider_create_repo "testorg" "testrepo" "private" "Test repository")
if [[ $repo_url =~ ^https://mock-vcs.example.com ]]; then
    test_pass
else
    test_fail "Expected mock VCS URL, got '$repo_url'"
fi

# Test: Repository exists
test_start "vcs_provider_repo_exists returns true for created repo"
if vcs_provider_repo_exists "testorg" "testrepo"; then
    test_pass
else
    test_fail "Repository should exist"
fi

# Test: Repository doesn't exist
test_start "vcs_provider_repo_exists returns false for non-existent repo"
if ! vcs_provider_repo_exists "testorg" "nonexistent"; then
    test_pass
else
    test_fail "Repository should not exist"
fi

# Test: Set secret
test_start "vcs_provider_set_secret succeeds"
vcs_provider_set_secret "testorg" "testrepo" "MY_SECRET" "secret_value"
assert_success $?

# Test: Set variable
test_start "vcs_provider_set_variable succeeds"
vcs_provider_set_variable "testorg" "testrepo" "AWS_REGION" "us-east-1"
assert_success $?

# Test: Create environment
test_start "vcs_provider_create_environment succeeds"
vcs_provider_create_environment "testorg" "testrepo" "production" "true" "admin"
assert_success $?

# Test: Set environment secret
test_start "vcs_provider_set_environment_secret succeeds"
vcs_provider_set_environment_secret "testorg" "testrepo" "production" "PROD_KEY" "prod_value"
assert_success $?

# Test: Setup branch protection
test_start "vcs_provider_setup_branch_protection succeeds"
vcs_provider_setup_branch_protection "testorg" "testrepo" "main" 1 "true"
assert_success $?

# Test: Get default branch
test_start "vcs_provider_get_default_branch returns 'main'"
branch=$(vcs_provider_get_default_branch "testorg" "testrepo")
assert_equals "main" "$branch"

# Test: Create workflow
test_start "vcs_provider_create_workflow succeeds"
workflow_content="name: Test\non: push"
vcs_provider_create_workflow "testorg" "testrepo" "test.yml" "$workflow_content" "Add test workflow"
assert_success $?

# Test: Setup OIDC
test_start "vcs_provider_setup_oidc succeeds"
vcs_provider_setup_oidc "testorg" "testrepo" "aws" "arn:aws:iam::123456789012:role/GitHubActions"
assert_success $?

# Test: Create release
test_start "vcs_provider_create_release creates release"
release_url=$(vcs_provider_create_release "testorg" "testrepo" "v1.0.0" "Initial Release" "First release" "false")
if [[ $release_url =~ v1.0.0 ]]; then
    test_pass
else
    test_fail "Expected release URL with version, got '$release_url'"
fi

# Test: Get current user
test_start "vcs_provider_get_current_user returns mock user"
user=$(vcs_provider_get_current_user)
assert_equals "mock-user" "$user"

# Test: Is authenticated
test_start "vcs_provider_is_authenticated returns true"
if vcs_provider_is_authenticated; then
    test_pass
else
    test_fail "Should be authenticated in mock mode"
fi

# Test: VCS operation logging
test_start "mock_vcs_count_operations counts create_repo operations"
count=$(mock_vcs_count_operations "create_repo")
if [ "$count" -ge 1 ]; then
    test_pass
else
    test_fail "Expected at least 1 create_repo operation, got $count"
fi

# Test: Verify specific VCS operation
test_start "mock_vcs_verify_operation finds specific repo creation"
if mock_vcs_verify_operation "create_repo" "name=testrepo"; then
    test_pass
else
    test_fail "Could not verify testrepo creation in log"
fi

echo ""

# ============================================================================
# Summary
# ============================================================================

echo "========================================="
echo "  Test Summary"
echo "========================================="
echo ""
echo "  Tests run:    $TESTS_RUN"
echo -e "  Tests passed: ${GREEN}$TESTS_PASSED${NC}"

if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "  Tests failed: ${RED}$TESTS_FAILED${NC}"
    echo ""
    exit 1
else
    echo -e "  Tests failed: ${GREEN}0${NC}"
    echo ""
    echo -e "${GREEN}All tests passed! ✓${NC}"
    echo ""
    exit 0
fi