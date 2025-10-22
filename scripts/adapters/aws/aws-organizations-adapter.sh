#!/usr/bin/env bash

# ============================================================================
# AWS Organizations Adapter
# ============================================================================
#
# Implements cloud-provider-port.sh functions for AWS Organizations.
# Handles account creation, retrieval, and management operations.
#
# Features:
#   - Account creation with email and organizational unit
#   - Account status polling (wait for creation)
#   - Account lookup by name
#   - Role assumption for cross-account access
#   - Caller identity retrieval
#
# Requirements:
#   - AWS CLI installed and configured
#   - Permissions to create/manage organization accounts
#   - jq for JSON parsing
#
# Usage:
#   source scripts/ports/cloud-provider-port.sh
#   source scripts/adapters/aws/aws-organizations-adapter.sh
#   account_id=$(cloud_provider_create_account "MyAccount" "user@example.com" "ou-xxx")
#
# ============================================================================

# Source the port to ensure we implement all required functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/ports/cloud-provider-port.sh
source "$SCRIPT_DIR/../../ports/cloud-provider-port.sh"

# ============================================================================
# Port Metadata
# ============================================================================

cloud_provider_name() {
    echo "AWS"
    return 0
}

# ============================================================================
# Account Management
# ============================================================================

cloud_provider_create_account() {
    local account_name=$1
    local email=$2
    local org_unit_id=$3
    local role_name=${4:-OrganizationAccountAccessRole}

    # Validate inputs
    if [ -z "$account_name" ] || [ -z "$email" ] || [ -z "$org_unit_id" ]; then
        echo "ERROR: Missing required parameters" >&2
        echo "Usage: cloud_provider_create_account <account_name> <email> <org_unit_id> [role_name]" >&2
        return 1
    fi

    # Validate OU ID format
    if [[ ! $org_unit_id =~ ^ou- ]]; then
        echo "ERROR: OU_ID must start with 'ou-'" >&2
        return 1
    fi

    # Check if account already exists
    local existing_account
    existing_account=$(aws organizations list-accounts \
        --query "Accounts[?Name=='${account_name}'].Id" \
        --output text 2>/dev/null || echo "")

    if [ -n "$existing_account" ]; then
        echo "$existing_account"
        return 0
    fi

    # Create the account
    local create_output
    if ! create_output=$(aws organizations create-account \
        --email "${email}" \
        --account-name "${account_name}" \
        --role-name "${role_name}" \
        --output json 2>&1); then
        echo "ERROR: Failed to create account: $create_output" >&2
        return 1
    fi

    # Extract request ID
    local request_id
    request_id=$(echo "$create_output" | jq -r '.CreateAccountStatus.Id')

    if [ -z "$request_id" ] || [ "$request_id" = "null" ]; then
        echo "ERROR: Failed to get create account request ID" >&2
        return 1
    fi

    # Wait for account creation to complete
    local account_id
    if ! account_id=$(cloud_provider_wait_for_account "$request_id"); then
        echo "ERROR: Account creation failed or timed out" >&2
        return 1
    fi

    # Move account to target OU
    local current_parent
    current_parent=$(aws organizations list-parents \
        --child-id "${account_id}" \
        --query 'Parents[0].Id' \
        --output text 2>/dev/null)

    if [ -n "$current_parent" ] && [ "$current_parent" != "$org_unit_id" ]; then
        if ! aws organizations move-account \
            --account-id "${account_id}" \
            --source-parent-id "${current_parent}" \
            --destination-parent-id "${org_unit_id}" 2>/dev/null; then
            echo "WARNING: Failed to move account to target OU (account may already be there)" >&2
        fi
    fi

    echo "$account_id"
    return 0
}

cloud_provider_wait_for_account() {
    local request_id=$1
    local max_attempts=${2:-60}  # 60 attempts = ~10 minutes (10s interval)
    local attempt=0

    if [ -z "$request_id" ]; then
        echo "ERROR: Missing request_id parameter" >&2
        return 1
    fi

    while [ $attempt -lt $max_attempts ]; do
        local status_output
        if ! status_output=$(aws organizations describe-create-account-status \
            --create-account-request-id "${request_id}" \
            --output json 2>&1); then
            echo "ERROR: Failed to check account status: $status_output" >&2
            return 1
        fi

        local state
        state=$(echo "$status_output" | jq -r '.CreateAccountStatus.State')

        case "$state" in
            SUCCEEDED)
                local account_id
                account_id=$(echo "$status_output" | jq -r '.CreateAccountStatus.AccountId')
                echo "$account_id"
                return 0
                ;;
            FAILED)
                local failure_reason
                failure_reason=$(echo "$status_output" | jq -r '.CreateAccountStatus.FailureReason')
                echo "ERROR: Account creation failed: $failure_reason" >&2
                return 1
                ;;
            IN_PROGRESS)
                # Still creating, wait and retry
                sleep 10
                attempt=$((attempt + 1))
                ;;
            *)
                echo "ERROR: Unknown account creation state: $state" >&2
                return 1
                ;;
        esac
    done

    echo "ERROR: Account creation timed out after $max_attempts attempts" >&2
    return 1
}

cloud_provider_get_account_id() {
    local account_name=$1

    if [ -z "$account_name" ]; then
        echo "ERROR: Missing account_name parameter" >&2
        return 1
    fi

    local account_id
    account_id=$(aws organizations list-accounts \
        --query "Accounts[?Name=='${account_name}'].Id" \
        --output text 2>/dev/null || echo "")

    if [ -z "$account_id" ]; then
        echo "ERROR: Account '$account_name' not found" >&2
        return 1
    fi

    echo "$account_id"
    return 0
}

# ============================================================================
# IAM & Authentication
# ============================================================================

cloud_provider_assume_role() {
    local account_id=$1
    local role_name=$2
    local session_name=${3:-hexagonal-architecture-session}
    local region=${4:-us-east-1}

    if [ -z "$account_id" ] || [ -z "$role_name" ]; then
        echo "ERROR: Missing required parameters" >&2
        echo "Usage: cloud_provider_assume_role <account_id> <role_name> [session_name] [region]" >&2
        return 1
    fi

    local role_arn="arn:aws:iam::${account_id}:role/${role_name}"

    # Assume the role
    local credentials
    if ! credentials=$(aws sts assume-role \
        --role-arn "${role_arn}" \
        --role-session-name "${session_name}" \
        --region "${region}" \
        --output json 2>&1); then
        echo "ERROR: Failed to assume role: $credentials" >&2
        return 1
    fi

    # Extract and export credentials
    local access_key_id secret_access_key session_token
    access_key_id=$(echo "$credentials" | jq -r '.Credentials.AccessKeyId')
    secret_access_key=$(echo "$credentials" | jq -r '.Credentials.SecretAccessKey')
    session_token=$(echo "$credentials" | jq -r '.Credentials.SessionToken')

    if [ -z "$access_key_id" ] || [ "$access_key_id" = "null" ]; then
        echo "ERROR: Failed to extract credentials from assume-role response" >&2
        return 1
    fi

    # Export credentials for use in current shell
    export AWS_ACCESS_KEY_ID="$access_key_id"
    export AWS_SECRET_ACCESS_KEY="$secret_access_key"
    export AWS_SESSION_TOKEN="$session_token"

    # Also output as JSON for programmatic use
    echo "$credentials"
    return 0
}

# ============================================================================
# Utility Functions
# ============================================================================

cloud_provider_get_caller_identity() {
    local identity
    if ! identity=$(aws sts get-caller-identity --output json 2>&1); then
        echo "ERROR: Failed to get caller identity: $identity" >&2
        return 1
    fi

    echo "$identity"
    return 0
}

# ============================================================================
# Validation
# ============================================================================

# Validate that AWS CLI is available
_validate_aws_cli() {
    if ! command -v aws &> /dev/null; then
        echo "ERROR: AWS CLI is not installed" >&2
        echo "Install: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html" >&2
        return 1
    fi

    # Check if authenticated
    if ! aws sts get-caller-identity &> /dev/null; then
        echo "ERROR: Not authenticated with AWS" >&2
        echo "Please run: aws sso login" >&2
        return 1
    fi

    return 0
}

# Validate that jq is available
_validate_jq() {
    if ! command -v jq &> /dev/null; then
        echo "ERROR: jq is not installed" >&2
        echo "Install: brew install jq (macOS) or apt-get install jq (Linux)" >&2
        return 1
    fi
    return 0
}

# Run validation on source
if ! _validate_aws_cli; then
    echo "WARNING: AWS CLI validation failed - some functions may not work" >&2
fi

if ! _validate_jq; then
    echo "WARNING: jq validation failed - some functions may not work" >&2
fi

# ============================================================================
# Export Functions
# ============================================================================

export -f cloud_provider_name
export -f cloud_provider_create_account
export -f cloud_provider_wait_for_account
export -f cloud_provider_get_account_id
export -f cloud_provider_assume_role
export -f cloud_provider_get_caller_identity
