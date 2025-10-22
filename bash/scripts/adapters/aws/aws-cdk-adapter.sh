#!/usr/bin/env bash

# ============================================================================
# AWS CDK Bootstrap Adapter
# ============================================================================
#
# Implements cloud-provider-port.sh functions for AWS CDK operations.
# Handles CDK bootstrapping with cross-account trust configuration.
#
# Features:
#   - CDK bootstrap with trust policies
#   - Cross-account deployment support
#   - CloudFormation execution policy configuration
#
# Requirements:
#   - AWS CDK CLI installed (npm install -g aws-cdk)
#   - AWS CLI installed and configured
#   - Permissions to bootstrap CDK in target accounts
#
# Usage:
#   source scripts/ports/cloud-provider-port.sh
#   source scripts/adapters/aws/aws-cdk-adapter.sh
#   cloud_provider_bootstrap_cdk "$account_id" "us-east-1" "OrganizationAccountAccessRole"
#
# ============================================================================

# Source the port to ensure we implement all required functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/ports/cloud-provider-port.sh
source "$SCRIPT_DIR/../../ports/cloud-provider-port.sh"

# ============================================================================
# Infrastructure Bootstrapping
# ============================================================================

cloud_provider_bootstrap_cdk() {
    local account_id=$1
    local region=${2:-us-east-1}
    local role_name=${3:-OrganizationAccountAccessRole}
    local trust_account_id=${4:-}

    if [ -z "$account_id" ]; then
        echo "ERROR: Missing account_id parameter" >&2
        echo "Usage: cloud_provider_bootstrap_cdk <account_id> [region] [role_name] [trust_account_id]" >&2
        return 1
    fi

    # Validate CDK CLI is installed
    if ! command -v cdk &> /dev/null; then
        echo "ERROR: AWS CDK CLI is not installed" >&2
        echo "Install: npm install -g aws-cdk" >&2
        return 1
    fi

    # If no trust account provided, use current account
    if [ -z "$trust_account_id" ]; then
        local caller_identity
        if ! caller_identity=$(aws sts get-caller-identity --output json 2>&1); then
            echo "ERROR: Failed to get caller identity: $caller_identity" >&2
            return 1
        fi
        trust_account_id=$(echo "$caller_identity" | jq -r '.Account')
    fi

    # Assume role into target account if not already in it
    local current_account
    current_account=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)

    if [ "$current_account" != "$account_id" ]; then
        echo "Assuming role in account $account_id..." >&2

        # Source AWS Organizations adapter for assume_role function
        if [ -f "$SCRIPT_DIR/aws-organizations-adapter.sh" ]; then
            # shellcheck source=scripts/adapters/aws/aws-organizations-adapter.sh
            source "$SCRIPT_DIR/aws-organizations-adapter.sh"
        fi

        if ! cloud_provider_assume_role "$account_id" "$role_name" "cdk-bootstrap" "$region" >/dev/null; then
            echo "ERROR: Failed to assume role in account $account_id" >&2
            return 1
        fi
    fi

    # Bootstrap CDK with trust to management/deployment account
    echo "Bootstrapping CDK in account $account_id, region $region..." >&2

    local bootstrap_output
    if bootstrap_output=$(cdk bootstrap "aws://${account_id}/${region}" \
        --cloudformation-execution-policies "arn:aws:iam::aws:policy/AdministratorAccess" \
        --trust "$trust_account_id" \
        --trust-for-lookup "$trust_account_id" \
        2>&1); then
        echo "CDK bootstrap successful" >&2
        return 0
    else
        # Check if it's already bootstrapped
        if echo "$bootstrap_output" | grep -q "already exists"; then
            echo "CDK already bootstrapped" >&2
            return 0
        fi

        echo "ERROR: CDK bootstrap failed: $bootstrap_output" >&2
        return 1
    fi
}

# ============================================================================
# Export Functions
# ============================================================================

export -f cloud_provider_bootstrap_cdk
