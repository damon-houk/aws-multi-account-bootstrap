#!/usr/bin/env bash

# ============================================================================
# Mock Cloud Provider Adapter
# ============================================================================
#
# Implements the cloud-provider-port.sh interface for testing.
# No real cloud resources are created - all operations are simulated.
#
# Features:
#   - Generates fake account IDs, ARNs, etc.
#   - Logs all operations to a temp file for test verification
#   - Simulates delays and success/failure scenarios
#   - Thread-safe operation logging
#
# Usage:
#   source scripts/ports/cloud-provider-port.sh
#   source scripts/adapters/mock/mock-cloud-adapter.sh
#   account_id=$(cloud_provider_create_account "Test" "test@example.com" "ou-test")
#
# ============================================================================

# Source the port to ensure we implement all required functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/ports/cloud-provider-port.sh
source "$SCRIPT_DIR/../../ports/cloud-provider-port.sh"

# ============================================================================
# Mock State Management
# ============================================================================

# Initialize mock state directory
MOCK_STATE_DIR="${MOCK_STATE_DIR:-$(mktemp -d -t aws-bootstrap-mock-XXXXXX)}"
MOCK_LOG_FILE="$MOCK_STATE_DIR/operations.log"
MOCK_ACCOUNTS_FILE="$MOCK_STATE_DIR/accounts.txt"
MOCK_TOPICS_FILE="$MOCK_STATE_DIR/topics.txt"

# Create state files
touch "$MOCK_LOG_FILE"
touch "$MOCK_ACCOUNTS_FILE"
touch "$MOCK_TOPICS_FILE"

# Export state directory for tests to access
export MOCK_STATE_DIR

# Log an operation
_mock_log() {
    local operation=$1
    shift
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $operation: $*" >> "$MOCK_LOG_FILE"
}

# Generate a fake AWS account ID
_mock_generate_account_id() {
    printf "MOCK%09d" $((RANDOM * RANDOM % 1000000000))
}

# Generate a fake request ID
_mock_generate_request_id() {
    printf "req-mock-%s" "$(date +%s)-$RANDOM"
}

# Generate a fake ARN
_mock_generate_arn() {
    local service=$1
    local resource=$2
    echo "arn:aws:${service}::MOCK000000000:${resource}"
}

# ============================================================================
# Account Management
# ============================================================================

cloud_provider_create_account() {
    local account_name=$1
    local email=$2
    local org_unit_id=$3

    _mock_log "create_account" "name=$account_name email=$email ou=$org_unit_id"

    # Validate inputs
    if [ -z "$account_name" ] || [ -z "$email" ] || [ -z "$org_unit_id" ]; then
        echo "ERROR: Missing required parameters" >&2
        return 1
    fi

    # Check if account already exists
    if grep -q "^$account_name|" "$MOCK_ACCOUNTS_FILE" 2>/dev/null; then
        # Return existing account ID
        local existing_id
        existing_id=$(grep "^$account_name|" "$MOCK_ACCOUNTS_FILE" | cut -d'|' -f2)
        _mock_log "create_account" "account already exists: $existing_id"
        echo "$existing_id"
        return 0
    fi

    # Generate fake account ID
    local account_id
    account_id=$(_mock_generate_account_id)

    # Store account info
    echo "${account_name}|${account_id}|${email}|${org_unit_id}|ACTIVE" >> "$MOCK_ACCOUNTS_FILE"

    # Simulate creation delay (very short for tests)
    sleep 0.1

    _mock_log "create_account" "created account_id=$account_id"
    echo "$account_id"
    return 0
}

cloud_provider_wait_for_account() {
    local request_id=$1

    _mock_log "wait_for_account" "request_id=$request_id"

    # Validate input
    if [ -z "$request_id" ]; then
        echo "ERROR: Missing request_id" >&2
        return 1
    fi

    # Simulate wait
    sleep 0.1

    # Generate account ID from request ID
    local account_id
    account_id=$(_mock_generate_account_id)

    _mock_log "wait_for_account" "completed account_id=$account_id"
    echo "$account_id"
    return 0
}

cloud_provider_get_account_id() {
    local account_name=$1

    _mock_log "get_account_id" "name=$account_name"

    # Validate input
    if [ -z "$account_name" ]; then
        echo "ERROR: Missing account_name" >&2
        return 1
    fi

    # Look up account
    if grep -q "^$account_name|" "$MOCK_ACCOUNTS_FILE" 2>/dev/null; then
        local account_id
        account_id=$(grep "^$account_name|" "$MOCK_ACCOUNTS_FILE" | cut -d'|' -f2)
        echo "$account_id"
        return 0
    fi

    # Account not found
    return 1
}

# ============================================================================
# IAM & Authentication
# ============================================================================

cloud_provider_create_oidc_provider() {
    local account_id=$1
    local oidc_url=$2
    local audience=$3

    _mock_log "create_oidc_provider" "account=$account_id url=$oidc_url audience=$audience"

    # Validate inputs
    if [ -z "$account_id" ] || [ -z "$oidc_url" ] || [ -z "$audience" ]; then
        echo "ERROR: Missing required parameters" >&2
        return 1
    fi

    # Simulate creation
    sleep 0.05

    local provider_arn
    provider_arn=$(_mock_generate_arn "iam" "oidc-provider/${oidc_url#https://}")

    _mock_log "create_oidc_provider" "created arn=$provider_arn"
    echo "$provider_arn"
    return 0
}

cloud_provider_create_oidc_role() {
    local account_id=$1
    local role_name=$2
    local oidc_provider_arn=$3
    local repository=$4
    local policy_arns=$5

    _mock_log "create_oidc_role" "account=$account_id role=$role_name repo=$repository"

    # Validate inputs
    if [ -z "$account_id" ] || [ -z "$role_name" ]; then
        echo "ERROR: Missing required parameters" >&2
        return 1
    fi

    # Simulate creation
    sleep 0.05

    local role_arn
    role_arn=$(_mock_generate_arn "iam" "role/$role_name")

    _mock_log "create_oidc_role" "created arn=$role_arn"
    echo "$role_arn"
    return 0
}

# ============================================================================
# Infrastructure Bootstrapping
# ============================================================================

cloud_provider_bootstrap_cdk() {
    local account_id=$1
    local region=$2
    local role_name=$3

    _mock_log "bootstrap_cdk" "account=$account_id region=$region role=$role_name"

    # Validate inputs
    if [ -z "$account_id" ] || [ -z "$region" ]; then
        echo "ERROR: Missing required parameters" >&2
        return 1
    fi

    # Simulate bootstrap (longer delay to mimic real CDK)
    sleep 0.2

    _mock_log "bootstrap_cdk" "completed successfully"
    return 0
}

# ============================================================================
# Cost Management
# ============================================================================

cloud_provider_create_budget() {
    local account_id=$1
    local budget_name=$2
    local amount=$3
    local email=$4

    _mock_log "create_budget" "account=$account_id name=$budget_name amount=\$$amount email=$email"

    # Validate inputs
    if [ -z "$account_id" ] || [ -z "$budget_name" ] || [ -z "$amount" ]; then
        echo "ERROR: Missing required parameters" >&2
        return 1
    fi

    # Simulate creation
    sleep 0.05

    _mock_log "create_budget" "created successfully"
    return 0
}

cloud_provider_create_billing_alarm() {
    local account_id=$1
    local alarm_name=$2
    local threshold=$3
    local sns_topic_arn=$4

    _mock_log "create_billing_alarm" "account=$account_id name=$alarm_name threshold=\$$threshold topic=$sns_topic_arn"

    # Validate inputs
    if [ -z "$account_id" ] || [ -z "$alarm_name" ] || [ -z "$threshold" ]; then
        echo "ERROR: Missing required parameters" >&2
        return 1
    fi

    # Simulate creation
    sleep 0.05

    local alarm_arn
    alarm_arn=$(_mock_generate_arn "cloudwatch" "alarm:$alarm_name")

    _mock_log "create_billing_alarm" "created arn=$alarm_arn"
    echo "$alarm_arn"
    return 0
}

# ============================================================================
# Notification Services
# ============================================================================

cloud_provider_create_sns_topic() {
    local account_id=$1
    local topic_name=$2

    _mock_log "create_sns_topic" "account=$account_id name=$topic_name"

    # Validate inputs
    if [ -z "$account_id" ] || [ -z "$topic_name" ]; then
        echo "ERROR: Missing required parameters" >&2
        return 1
    fi

    # Simulate creation
    sleep 0.05

    local topic_arn
    topic_arn=$(_mock_generate_arn "sns" "$topic_name")

    # Store topic
    echo "${account_id}|${topic_name}|${topic_arn}" >> "$MOCK_TOPICS_FILE"

    _mock_log "create_sns_topic" "created arn=$topic_arn"
    echo "$topic_arn"
    return 0
}

cloud_provider_subscribe_email_to_topic() {
    local account_id=$1
    local topic_arn=$2
    local email=$3

    _mock_log "subscribe_email" "account=$account_id topic=$topic_arn email=$email"

    # Validate inputs
    if [ -z "$account_id" ] || [ -z "$topic_arn" ] || [ -z "$email" ]; then
        echo "ERROR: Missing required parameters" >&2
        return 1
    fi

    # Simulate subscription
    sleep 0.05

    local subscription_arn
    subscription_arn="${topic_arn}:$(uuidgen | tr '[:upper:]' '[:lower:]')"

    _mock_log "subscribe_email" "created subscription_arn=$subscription_arn (pending confirmation)"
    return 0
}

# ============================================================================
# Utility Functions
# ============================================================================

cloud_provider_assume_role() {
    local account_id=$1
    local role_name=$2
    shift 2
    local command=("$@")

    _mock_log "assume_role" "account=$account_id role=$role_name command=${command[*]}"

    # Validate inputs
    if [ -z "$account_id" ] || [ -z "$role_name" ] || [ ${#command[@]} -eq 0 ]; then
        echo "ERROR: Missing required parameters" >&2
        return 1
    fi

    # Execute command (in mock mode, just run it directly without assuming role)
    _mock_log "assume_role" "executing: ${command[*]}"
    "${command[@]}"
    local exit_code=$?

    _mock_log "assume_role" "command exited with code $exit_code"
    return $exit_code
}

cloud_provider_get_caller_identity() {
    _mock_log "get_caller_identity" "requesting identity"

    # Return fake identity JSON
    cat <<EOF
{
  "UserId": "MOCKUSERID123456",
  "Account": "MOCK000000000",
  "Arn": "arn:aws:iam::MOCK000000000:user/mock-user"
}
EOF
    return 0
}

# ============================================================================
# Port Metadata
# ============================================================================

cloud_provider_name() {
    echo "Mock"
    return 0
}

# ============================================================================
# Mock-Specific Helper Functions
# ============================================================================

# Get the mock operation log for test verification
mock_get_log() {
    if [ -f "$MOCK_LOG_FILE" ]; then
        cat "$MOCK_LOG_FILE"
    fi
}

# Clear the mock operation log
mock_clear_log() {
    : > "$MOCK_LOG_FILE"
}

# Get all mock accounts created
mock_get_accounts() {
    if [ -f "$MOCK_ACCOUNTS_FILE" ]; then
        cat "$MOCK_ACCOUNTS_FILE"
    fi
}

# Count mock operations of a specific type
mock_count_operations() {
    local operation=$1
    if [ -f "$MOCK_LOG_FILE" ]; then
        grep -c "] $operation:" "$MOCK_LOG_FILE" || echo "0"
    else
        echo "0"
    fi
}

# Verify an operation was logged
mock_verify_operation() {
    local operation=$1
    local pattern=$2

    if [ ! -f "$MOCK_LOG_FILE" ]; then
        return 1
    fi

    grep "] $operation:" "$MOCK_LOG_FILE" | grep -q "$pattern"
}

# Reset all mock state
mock_reset() {
    : > "$MOCK_LOG_FILE"
    : > "$MOCK_ACCOUNTS_FILE"
    : > "$MOCK_TOPICS_FILE"
}

# Export mock helper functions
export -f mock_get_log
export -f mock_clear_log
export -f mock_get_accounts
export -f mock_count_operations
export -f mock_verify_operation
export -f mock_reset

# Log adapter loaded
_mock_log "adapter" "Mock cloud provider adapter loaded (state_dir=$MOCK_STATE_DIR)"