#!/usr/bin/env bash

# ============================================================================
# GitHub Workflows/OIDC Adapter
# ============================================================================
#
# Implements vcs-provider-port.sh functions for GitHub workflows and OIDC.
# Handles branch protection, workflows, releases, and git operations.
#
# Features:
#   - Branch protection configuration
#   - Workflow file creation
#   - OIDC setup for cloud providers
#   - Release and tag creation
#   - Git operations (init, push)
#
# Requirements:
#   - GitHub CLI (gh) installed and configured
#   - Git installed
#   - Authentication with GitHub
#
# Usage:
#   source scripts/ports/vcs-provider-port.sh
#   source scripts/adapters/github/github-workflows-adapter.sh
#   vcs_provider_setup_branch_protection "myorg" "myrepo" "main" 1 "true"
#
# ============================================================================

# Source the port to ensure we implement all required functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/ports/vcs-provider-port.sh
source "$SCRIPT_DIR/../../ports/vcs-provider-port.sh"

# ============================================================================
# Branch Management
# ============================================================================

vcs_provider_setup_branch_protection() {
    local org=$1
    local repo_name=$2
    local branch=$3
    local require_reviews=${4:-0}
    local require_checks=${5:-false}

    if [ -z "$org" ] || [ -z "$repo_name" ] || [ -z "$branch" ]; then
        echo "ERROR: Missing required parameters" >&2
        echo "Usage: vcs_provider_setup_branch_protection <org> <repo_name> <branch> [require_reviews] [require_checks]" >&2
        return 1
    fi

    # Build protection configuration
    local protection_config
    protection_config=$(cat <<EOF
{
  "required_status_checks": {
    "strict": $([ "$require_checks" = "true" ] && echo "true" || echo "false"),
    "contexts": $([ "$require_checks" = "true" ] && echo '["test"]' || echo '[]')
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "required_approving_review_count": ${require_reviews}
  },
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": true
}
EOF
)

    # Apply branch protection using GitHub API
    if ! gh api "repos/$org/$repo_name/branches/$branch/protection" \
        --method PUT \
        --input - <<< "$protection_config" 2>&1; then
        echo "WARNING: Some branch protection rules may require GitHub Pro" >&2
        # Don't fail - some protection features require paid plans
        return 0
    fi

    return 0
}

vcs_provider_get_default_branch() {
    local org=$1
    local repo_name=$2

    if [ -z "$org" ] || [ -z "$repo_name" ]; then
        echo "ERROR: Missing required parameters" >&2
        return 1
    fi

    local default_branch
    if ! default_branch=$(gh repo view "$org/$repo_name" --json defaultBranchRef -q .defaultBranchRef.name 2>&1); then
        echo "ERROR: Failed to get default branch: $default_branch" >&2
        return 1
    fi

    echo "$default_branch"
    return 0
}

# ============================================================================
# Workflows & CI/CD
# ============================================================================

vcs_provider_create_workflow() {
    local org=$1
    local repo_name=$2
    local workflow_name=$3
    local workflow_content=$4
    local commit_message=${5:-"Add workflow: $workflow_name"}

    if [ -z "$org" ] || [ -z "$repo_name" ] || [ -z "$workflow_name" ] || [ -z "$workflow_content" ]; then
        echo "ERROR: Missing required parameters" >&2
        echo "Usage: vcs_provider_create_workflow <org> <repo_name> <workflow_name> <workflow_content> [commit_message]" >&2
        return 1
    fi

    # Create workflow file locally
    local workflow_dir=".github/workflows"
    mkdir -p "$workflow_dir"

    local workflow_path="$workflow_dir/$workflow_name"
    echo "$workflow_content" > "$workflow_path"

    # Commit and push workflow
    git add "$workflow_path"
    git commit -m "$commit_message" || true
    git push || true

    return 0
}

vcs_provider_enable_workflow() {
    local org=$1
    local repo_name=$2
    local workflow_name=$3

    if [ -z "$org" ] || [ -z "$repo_name" ] || [ -z "$workflow_name" ]; then
        echo "ERROR: Missing required parameters" >&2
        echo "Usage: vcs_provider_enable_workflow <org> <repo_name> <workflow_name>" >&2
        return 1
    fi

    # Enable workflow using GitHub API
    if ! gh api "repos/$org/$repo_name/actions/workflows/$workflow_name/enable" \
        --method PUT 2>&1; then
        echo "WARNING: Failed to enable workflow (may already be enabled)" >&2
        return 0
    fi

    return 0
}

# ============================================================================
# OIDC Configuration
# ============================================================================

vcs_provider_setup_oidc() {
    local org=$1
    local repo_name=$2
    local cloud_provider=$3
    local role_arn=$4
    local environment=${5:-}

    if [ -z "$org" ] || [ -z "$repo_name" ] || [ -z "$cloud_provider" ] || [ -z "$role_arn" ]; then
        echo "ERROR: Missing required parameters" >&2
        echo "Usage: vcs_provider_setup_oidc <org> <repo_name> <cloud_provider> <role_arn> [environment]" >&2
        return 1
    fi

    # OIDC setup is primarily configuration of secrets/variables
    # The actual OIDC provider is created on the cloud provider side

    # Set the role ARN as a secret or variable
    case "$cloud_provider" in
        aws)
            local secret_name="AWS_ROLE_ARN"
            if [ -n "$environment" ]; then
                secret_name="${environment}_AWS_ROLE_ARN"
                vcs_provider_set_environment_secret "$org" "$repo_name" "$environment" "$secret_name" "$role_arn"
            else
                vcs_provider_set_secret "$org" "$repo_name" "$secret_name" "$role_arn"
            fi
            ;;
        azure)
            local secret_name="AZURE_CLIENT_ID"
            if [ -n "$environment" ]; then
                secret_name="${environment}_AZURE_CLIENT_ID"
                vcs_provider_set_environment_secret "$org" "$repo_name" "$environment" "$secret_name" "$role_arn"
            else
                vcs_provider_set_secret "$org" "$repo_name" "$secret_name" "$role_arn"
            fi
            ;;
        gcp)
            local secret_name="GCP_WORKLOAD_IDENTITY"
            if [ -n "$environment" ]; then
                secret_name="${environment}_GCP_WORKLOAD_IDENTITY"
                vcs_provider_set_environment_secret "$org" "$repo_name" "$environment" "$secret_name" "$role_arn"
            else
                vcs_provider_set_secret "$org" "$repo_name" "$secret_name" "$role_arn"
            fi
            ;;
        *)
            echo "ERROR: Unsupported cloud provider: $cloud_provider" >&2
            return 1
            ;;
    esac

    return 0
}

# ============================================================================
# Git Operations
# ============================================================================

vcs_provider_init_local_repo() {
    local repo_path=$1
    local remote_url=$2
    local default_branch=${3:-main}

    if [ -z "$repo_path" ] || [ -z "$remote_url" ]; then
        echo "ERROR: Missing required parameters" >&2
        echo "Usage: vcs_provider_init_local_repo <repo_path> <remote_url> [default_branch]" >&2
        return 1
    fi

    # Initialize git repository
    cd "$repo_path" || return 1

    if [ ! -d ".git" ]; then
        git init
    fi

    # Add remote if not exists
    if ! git remote get-url origin &> /dev/null; then
        git remote add origin "$remote_url"
    fi

    # Set default branch
    git branch -M "$default_branch"

    return 0
}

vcs_provider_push() {
    local repo_path=$1
    local branch=$2
    local force=${3:-false}

    if [ -z "$repo_path" ] || [ -z "$branch" ]; then
        echo "ERROR: Missing required parameters" >&2
        echo "Usage: vcs_provider_push <repo_path> <branch> [force]" >&2
        return 1
    fi

    cd "$repo_path" || return 1

    # Push to remote
    local push_args=()
    if [ "$force" = "true" ]; then
        push_args+=("--force")
    fi

    if ! git push -u origin "$branch" "${push_args[@]}" 2>&1; then
        echo "ERROR: Failed to push to remote" >&2
        return 1
    fi

    return 0
}

# ============================================================================
# Releases & Tags
# ============================================================================

vcs_provider_create_release() {
    local org=$1
    local repo_name=$2
    local tag_name=$3
    local release_name=$4
    local body=${5:-}
    local prerelease=${6:-false}

    if [ -z "$org" ] || [ -z "$repo_name" ] || [ -z "$tag_name" ] || [ -z "$release_name" ]; then
        echo "ERROR: Missing required parameters" >&2
        echo "Usage: vcs_provider_create_release <org> <repo_name> <tag_name> <release_name> [body] [prerelease]" >&2
        return 1
    fi

    # Build release command
    local release_args=(
        "$tag_name"
        --title "$release_name"
        --repo "$org/$repo_name"
    )

    if [ -n "$body" ]; then
        release_args+=(--notes "$body")
    fi

    if [ "$prerelease" = "true" ]; then
        release_args+=(--prerelease)
    fi

    # Create release
    local release_url
    if ! release_url=$(gh release create "${release_args[@]}" 2>&1); then
        # Release might already exist
        if echo "$release_url" | grep -q "already exists"; then
            release_url=$(gh release view "$tag_name" --repo "$org/$repo_name" --json url -q .url 2>/dev/null)
            echo "$release_url"
            return 0
        fi
        echo "ERROR: Failed to create release: $release_url" >&2
        return 1
    fi

    echo "$release_url"
    return 0
}

# ============================================================================
# Export Functions
# ============================================================================

export -f vcs_provider_setup_branch_protection
export -f vcs_provider_get_default_branch
export -f vcs_provider_create_workflow
export -f vcs_provider_enable_workflow
export -f vcs_provider_setup_oidc
export -f vcs_provider_init_local_repo
export -f vcs_provider_push
export -f vcs_provider_create_release
