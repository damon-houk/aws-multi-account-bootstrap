#!/usr/bin/env bash

# ============================================================================
# Cloud Provider Port (Interface)
# ============================================================================
#
# Defines the contract for cloud provider operations.
# Implementations: AWS, Azure (future), GCP (future), Mock (testing)
#
# This is an interface - implementations must provide these functions.
# No implementation code should exist in this file.
#
# Usage:
#   source scripts/ports/cloud-provider-port.sh
#   # Then source an adapter that implements these functions
#   source scripts/adapters/aws/aws-organizations-adapter.sh
#
# ============================================================================

# ============================================================================
# Account Management
# ============================================================================

# Create a cloud account within an organization
#
# Args:
#   $1 - account_name: Name for the account (e.g., "TPA-dev")
#   $2 - email: Email address for the account (e.g., "user+tpa-dev@gmail.com")
#   $3 - org_unit_id: Organization unit ID (e.g., "ou-813y-xxxxxxxx")
#
# Returns:
#   Account ID (stdout): The unique identifier for the created account
#   Exit code: 0 on success, non-zero on failure
#
# Example:
#   account_id=$(cloud_provider_create_account "TPA-dev" "user+dev@gmail.com" "ou-813y-12345678")
#   echo "Created account: $account_id"
#
cloud_provider_create_account() {
    echo "ERROR: cloud_provider_create_account() not implemented by adapter" >&2
    echo "Please source a cloud provider adapter (e.g., adapters/aws/aws-organizations-adapter.sh)" >&2
    return 1
}

# Wait for an account to be fully created and ready
#
# Args:
#   $1 - request_id: The account creation request ID
#
# Returns:
#   Account ID (stdout): The unique identifier for the created account
#   Exit code: 0 on success, non-zero on failure/timeout
#
# Example:
#   account_id=$(cloud_provider_wait_for_account "$request_id")
#
cloud_provider_wait_for_account() {
    echo "ERROR: cloud_provider_wait_for_account() not implemented by adapter" >&2
    return 1
}

# Get account ID by account name
#
# Args:
#   $1 - account_name: Name of the account to find
#
# Returns:
#   Account ID (stdout): The unique identifier, or empty if not found
#   Exit code: 0 if found, 1 if not found
#
# Example:
#   account_id=$(cloud_provider_get_account_id "TPA-dev")
#
cloud_provider_get_account_id() {
    echo "ERROR: cloud_provider_get_account_id() not implemented by adapter" >&2
    return 1
}

# ============================================================================
# IAM & Authentication
# ============================================================================

# Create OIDC identity provider for external authentication (e.g., GitHub Actions)
#
# Args:
#   $1 - account_id: Account where OIDC provider should be created
#   $2 - oidc_url: OIDC provider URL (e.g., "https://token.actions.githubusercontent.com")
#   $3 - audience: Audience/client ID for the OIDC provider (e.g., "sts.amazonaws.com")
#
# Returns:
#   Exit code: 0 on success, non-zero on failure
#
# Example:
#   cloud_provider_create_oidc_provider "$account_id" \
#       "https://token.actions.githubusercontent.com" \
#       "sts.amazonaws.com"
#
cloud_provider_create_oidc_provider() {
    echo "ERROR: cloud_provider_create_oidc_provider() not implemented by adapter" >&2
    return 1
}

# Create IAM role with OIDC trust relationship
#
# Args:
#   $1 - account_id: Account where role should be created
#   $2 - role_name: Name for the IAM role (e.g., "GitHubActionsRole")
#   $3 - oidc_provider_arn: ARN of the OIDC provider
#   $4 - repository: Repository that can assume this role (e.g., "org/repo")
#   $5 - policy_arns: Space-separated list of policy ARNs to attach
#
# Returns:
#   Role ARN (stdout): The ARN of the created role
#   Exit code: 0 on success, non-zero on failure
#
# Example:
#   role_arn=$(cloud_provider_create_oidc_role "$account_id" \
#       "GitHubActionsRole" \
#       "$oidc_provider_arn" \
#       "myorg/myrepo" \
#       "arn:aws:iam::aws:policy/AdministratorAccess")
#
cloud_provider_create_oidc_role() {
    echo "ERROR: cloud_provider_create_oidc_role() not implemented by adapter" >&2
    return 1
}

# ============================================================================
# Infrastructure Bootstrapping
# ============================================================================

# Bootstrap CDK in an account (or equivalent infrastructure-as-code tooling)
#
# Args:
#   $1 - account_id: Account to bootstrap
#   $2 - region: Region to bootstrap (e.g., "us-east-1")
#   $3 - role_name: (Optional) Role to use for bootstrapping
#
# Returns:
#   Exit code: 0 on success, non-zero on failure
#
# Example:
#   cloud_provider_bootstrap_cdk "$account_id" "us-east-1" "OrganizationAccountAccessRole"
#
cloud_provider_bootstrap_cdk() {
    echo "ERROR: cloud_provider_bootstrap_cdk() not implemented by adapter" >&2
    return 1
}

# ============================================================================
# Cost Management
# ============================================================================

# Create a budget with alerts
#
# Args:
#   $1 - account_id: Account where budget should be created
#   $2 - budget_name: Name for the budget (e.g., "MonthlyBudget")
#   $3 - amount: Budget amount in USD (e.g., "25")
#   $4 - email: Email address for budget notifications
#
# Returns:
#   Exit code: 0 on success, non-zero on failure
#
# Example:
#   cloud_provider_create_budget "$account_id" "MonthlyBudget" "25" "alerts@example.com"
#
cloud_provider_create_budget() {
    echo "ERROR: cloud_provider_create_budget() not implemented by adapter" >&2
    return 1
}

# Create a CloudWatch alarm for billing (or equivalent)
#
# Args:
#   $1 - account_id: Account where alarm should be created
#   $2 - alarm_name: Name for the alarm
#   $3 - threshold: Dollar amount threshold (e.g., "15")
#   $4 - sns_topic_arn: SNS topic ARN for notifications
#
# Returns:
#   Exit code: 0 on success, non-zero on failure
#
# Example:
#   cloud_provider_create_billing_alarm "$account_id" "BillingWarning" "15" "$sns_topic_arn"
#
cloud_provider_create_billing_alarm() {
    echo "ERROR: cloud_provider_create_billing_alarm() not implemented by adapter" >&2
    return 1
}

# ============================================================================
# Notification Services
# ============================================================================

# Create SNS topic (or equivalent notification service)
#
# Args:
#   $1 - account_id: Account where topic should be created
#   $2 - topic_name: Name for the topic
#
# Returns:
#   Topic ARN (stdout): The ARN of the created topic
#   Exit code: 0 on success, non-zero on failure
#
# Example:
#   topic_arn=$(cloud_provider_create_sns_topic "$account_id" "BillingAlerts")
#
cloud_provider_create_sns_topic() {
    echo "ERROR: cloud_provider_create_sns_topic() not implemented by adapter" >&2
    return 1
}

# Subscribe email to SNS topic (or equivalent)
#
# Args:
#   $1 - account_id: Account where subscription should be created
#   $2 - topic_arn: ARN of the SNS topic
#   $3 - email: Email address to subscribe
#
# Returns:
#   Exit code: 0 on success, non-zero on failure
#
# Note: Email subscriptions typically require confirmation from the recipient
#
# Example:
#   cloud_provider_subscribe_email_to_topic "$account_id" "$topic_arn" "alerts@example.com"
#
cloud_provider_subscribe_email_to_topic() {
    echo "ERROR: cloud_provider_subscribe_email_to_topic() not implemented by adapter" >&2
    return 1
}

# ============================================================================
# Utility Functions
# ============================================================================

# Assume a role in another account and execute a command
#
# Args:
#   $1 - account_id: Account to assume role in
#   $2 - role_name: Role to assume
#   $3...$N - command: Command and arguments to execute with assumed role
#
# Returns:
#   Exit code: Exit code of the command
#
# Example:
#   cloud_provider_assume_role "$account_id" "OrganizationAccountAccessRole" \
#       aws s3 ls
#
cloud_provider_assume_role() {
    echo "ERROR: cloud_provider_assume_role() not implemented by adapter" >&2
    return 1
}

# Get current caller identity
#
# Returns:
#   JSON object with caller identity information
#   Exit code: 0 on success, non-zero on failure
#
# Example:
#   identity=$(cloud_provider_get_caller_identity)
#   account_id=$(echo "$identity" | jq -r '.Account')
#
cloud_provider_get_caller_identity() {
    echo "ERROR: cloud_provider_get_caller_identity() not implemented by adapter" >&2
    return 1
}

# ============================================================================
# Port Metadata
# ============================================================================

# Return the name of the cloud provider implementation
#
# Returns:
#   Provider name (stdout): e.g., "AWS", "Azure", "GCP", "Mock"
#   Exit code: 0 on success
#
# Example:
#   provider=$(cloud_provider_name)
#   echo "Using cloud provider: $provider"
#
cloud_provider_name() {
    echo "UNIMPLEMENTED"
    return 0
}

# Validate that all required port functions are implemented
#
# Returns:
#   Exit code: 0 if all functions implemented, 1 if any missing
#
# Example:
#   if cloud_provider_validate_port; then
#       echo "All port functions implemented"
#   fi
#
cloud_provider_validate_port() {
    local missing=0
    local functions=(
        "cloud_provider_create_account"
        "cloud_provider_wait_for_account"
        "cloud_provider_get_account_id"
        "cloud_provider_create_oidc_provider"
        "cloud_provider_create_oidc_role"
        "cloud_provider_bootstrap_cdk"
        "cloud_provider_create_budget"
        "cloud_provider_create_billing_alarm"
        "cloud_provider_create_sns_topic"
        "cloud_provider_subscribe_email_to_topic"
        "cloud_provider_assume_role"
        "cloud_provider_get_caller_identity"
        "cloud_provider_name"
    )

    for func in "${functions[@]}"; do
        if ! declare -f "$func" > /dev/null; then
            echo "ERROR: Required function not implemented: $func" >&2
            missing=1
        fi
    done

    return "$missing"
}

# Export port functions for subshells
export -f cloud_provider_create_account
export -f cloud_provider_wait_for_account
export -f cloud_provider_get_account_id
export -f cloud_provider_create_oidc_provider
export -f cloud_provider_create_oidc_role
export -f cloud_provider_bootstrap_cdk
export -f cloud_provider_create_budget
export -f cloud_provider_create_billing_alarm
export -f cloud_provider_create_sns_topic
export -f cloud_provider_subscribe_email_to_topic
export -f cloud_provider_assume_role
export -f cloud_provider_get_caller_identity
export -f cloud_provider_name
export -f cloud_provider_validate_port