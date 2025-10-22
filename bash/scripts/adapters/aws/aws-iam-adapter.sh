#!/usr/bin/env bash

# ============================================================================
# AWS IAM/OIDC Adapter
# ============================================================================
#
# Implements cloud-provider-port.sh functions for AWS IAM and OIDC operations.
# Handles OIDC provider creation and GitHub Actions role setup.
#
# Features:
#   - OIDC provider creation for GitHub Actions
#   - IAM role creation with OIDC trust policies
#   - Role assumption for cross-account access
#
# Requirements:
#   - AWS CLI installed and configured
#   - Permissions to manage IAM resources
#   - jq for JSON parsing
#
# Usage:
#   source scripts/ports/cloud-provider-port.sh
#   source scripts/adapters/aws/aws-iam-adapter.sh
#   provider_arn=$(cloud_provider_create_oidc_provider "$account_id" "https://token.actions.githubusercontent.com" "sts.amazonaws.com")
#
# ============================================================================

# Source the port to ensure we implement all required functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/ports/cloud-provider-port.sh
source "$SCRIPT_DIR/../../ports/cloud-provider-port.sh"

# ============================================================================
# IAM & Authentication
# ============================================================================

cloud_provider_create_oidc_provider() {
    local account_id=$1
    local url=$2
    local client_id=$3
    local thumbprint=${4:-6938fd4d98bab03faadb97b34396831e3780aea1}

    if [ -z "$account_id" ] || [ -z "$url" ] || [ -z "$client_id" ]; then
        echo "ERROR: Missing required parameters" >&2
        echo "Usage: cloud_provider_create_oidc_provider <account_id> <url> <client_id> [thumbprint]" >&2
        return 1
    fi

    # Extract the URL path for ARN construction
    local url_path="${url#https://}"

    # Try to create the OIDC provider
    local provider_arn
    if provider_arn=$(aws iam create-open-id-connect-provider \
        --url "$url" \
        --client-id-list "$client_id" \
        --thumbprint-list "$thumbprint" \
        --output text \
        --query 'OpenIDConnectProviderArn' 2>&1); then
        echo "$provider_arn"
        return 0
    fi

    # If creation failed, it might already exist - try to get it
    if echo "$provider_arn" | grep -q "EntityAlreadyExists"; then
        provider_arn="arn:aws:iam::${account_id}:oidc-provider/${url_path}"

        # Verify it exists
        if aws iam get-open-id-connect-provider \
            --open-id-connect-provider-arn "$provider_arn" &>/dev/null; then
            echo "$provider_arn"
            return 0
        fi
    fi

    echo "ERROR: Failed to create or find OIDC provider: $provider_arn" >&2
    return 1
}

cloud_provider_create_oidc_role() {
    local account_id=$1
    local role_name=$2
    local oidc_provider_arn=$3
    local repository=$4
    local branch_filter=${5:-*}

    if [ -z "$account_id" ] || [ -z "$role_name" ] || [ -z "$oidc_provider_arn" ] || [ -z "$repository" ]; then
        echo "ERROR: Missing required parameters" >&2
        echo "Usage: cloud_provider_create_oidc_role <account_id> <role_name> <oidc_provider_arn> <repository> [branch_filter]" >&2
        return 1
    fi

    # Extract provider URL from ARN (e.g., arn:aws:iam::123:oidc-provider/token.actions.githubusercontent.com)
    local provider_url="${oidc_provider_arn##*/}"

    # Create trust policy document
    local trust_policy
    trust_policy=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${oidc_provider_arn}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${provider_url}:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "${provider_url}:sub": "repo:${repository}:${branch_filter}"
        }
      }
    }
  ]
}
EOF
)

    # Try to create the role
    local role_arn
    if role_arn=$(aws iam create-role \
        --role-name "$role_name" \
        --assume-role-policy-document "$trust_policy" \
        --description "Role for GitHub Actions OIDC authentication" \
        --output text \
        --query 'Role.Arn' 2>&1); then

        # Attach administrator access policy (can be customized later)
        aws iam attach-role-policy \
            --role-name "$role_name" \
            --policy-arn "arn:aws:iam::aws:policy/AdministratorAccess" 2>/dev/null || true

        echo "$role_arn"
        return 0
    fi

    # If creation failed, role might already exist
    if echo "$role_arn" | grep -q "EntityAlreadyExists"; then
        role_arn="arn:aws:iam::${account_id}:role/${role_name}"

        # Update trust policy for existing role
        aws iam update-assume-role-policy \
            --role-name "$role_name" \
            --policy-document "$trust_policy" 2>/dev/null || true

        echo "$role_arn"
        return 0
    fi

    echo "ERROR: Failed to create or update role: $role_arn" >&2
    return 1
}

# ============================================================================
# Export Functions
# ============================================================================

export -f cloud_provider_create_oidc_provider
export -f cloud_provider_create_oidc_role
