#!/usr/bin/env bash

# ============================================================================
# GitHub Repository Adapter
# ============================================================================
#
# Implements vcs-provider-port.sh functions for GitHub repository operations.
# Handles repository creation, secrets, variables, and environments.
#
# Features:
#   - Repository creation and management
#   - Secrets and variables (repo and environment-level)
#   - Environment creation with reviewers
#   - Authentication and user info
#
# Requirements:
#   - GitHub CLI (gh) installed and configured
#   - Authentication with GitHub
#
# Usage:
#   source scripts/ports/vcs-provider-port.sh
#   source scripts/adapters/github/github-repo-adapter.sh
#   repo_url=$(vcs_provider_create_repo "myorg" "myrepo" "private" "My repository")
#
# ============================================================================

# Source the port to ensure we implement all required functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/ports/vcs-provider-port.sh
source "$SCRIPT_DIR/../../ports/vcs-provider-port.sh"

# ============================================================================
# Port Metadata
# ============================================================================

vcs_provider_name() {
    echo "GitHub"
    return 0
}

# ============================================================================
# Repository Management
# ============================================================================

vcs_provider_create_repo() {
    local org=$1
    local repo_name=$2
    local visibility=${3:-private}
    local description=${4:-}

    if [ -z "$org" ] || [ -z "$repo_name" ]; then
        echo "ERROR: Missing required parameters" >&2
        echo "Usage: vcs_provider_create_repo <org> <repo_name> [visibility] [description]" >&2
        return 1
    fi

    # Check if repository already exists
    if gh repo view "$org/$repo_name" &> /dev/null; then
        local existing_url
        existing_url=$(gh repo view "$org/$repo_name" --json url -q .url 2>/dev/null)
        echo "$existing_url"
        return 0
    fi

    # Build visibility flag
    local visibility_flag
    case "$visibility" in
        public)
            visibility_flag="--public"
            ;;
        private)
            visibility_flag="--private"
            ;;
        internal)
            visibility_flag="--internal"
            ;;
        *)
            visibility_flag="--private"
            ;;
    esac

    # Create repository
    local repo_url
    if ! repo_url=$(gh repo create "$org/$repo_name" \
        $visibility_flag \
        ${description:+--description "$description"} \
        --disable-wiki \
        2>&1); then
        echo "ERROR: Failed to create repository: $repo_url" >&2
        return 1
    fi

    # Get the actual URL
    repo_url=$(gh repo view "$org/$repo_name" --json url -q .url 2>/dev/null)
    echo "$repo_url"
    return 0
}

vcs_provider_repo_exists() {
    local org=$1
    local repo_name=$2

    if [ -z "$org" ] || [ -z "$repo_name" ]; then
        echo "ERROR: Missing required parameters" >&2
        return 1
    fi

    gh repo view "$org/$repo_name" &> /dev/null
    return $?
}

vcs_provider_delete_repo() {
    local org=$1
    local repo_name=$2

    if [ -z "$org" ] || [ -z "$repo_name" ]; then
        echo "ERROR: Missing required parameters" >&2
        echo "Usage: vcs_provider_delete_repo <org> <repo_name>" >&2
        return 1
    fi

    # Delete repository (requires confirmation)
    if ! gh repo delete "$org/$repo_name" --yes 2>&1; then
        echo "ERROR: Failed to delete repository" >&2
        return 1
    fi

    return 0
}

# ============================================================================
# Secrets & Configuration
# ============================================================================

vcs_provider_set_secret() {
    local org=$1
    local repo_name=$2
    local secret_name=$3
    local secret_value=$4

    if [ -z "$org" ] || [ -z "$repo_name" ] || [ -z "$secret_name" ] || [ -z "$secret_value" ]; then
        echo "ERROR: Missing required parameters" >&2
        echo "Usage: vcs_provider_set_secret <org> <repo_name> <secret_name> <secret_value>" >&2
        return 1
    fi

    # Set repository secret
    if ! echo "$secret_value" | gh secret set "$secret_name" \
        --repo "$org/$repo_name" \
        --body - 2>&1; then
        echo "ERROR: Failed to set secret" >&2
        return 1
    fi

    return 0
}

vcs_provider_set_variable() {
    local org=$1
    local repo_name=$2
    local variable_name=$3
    local variable_value=$4

    if [ -z "$org" ] || [ -z "$repo_name" ] || [ -z "$variable_name" ] || [ -z "$variable_value" ]; then
        echo "ERROR: Missing required parameters" >&2
        echo "Usage: vcs_provider_set_variable <org> <repo_name> <variable_name> <variable_value>" >&2
        return 1
    fi

    # Set repository variable
    if ! gh variable set "$variable_name" \
        --body "$variable_value" \
        --repo "$org/$repo_name" 2>&1; then
        echo "ERROR: Failed to set variable" >&2
        return 1
    fi

    return 0
}

# ============================================================================
# Environments
# ============================================================================

vcs_provider_create_environment() {
    local org=$1
    local repo_name=$2
    local environment=$3
    local require_reviewers=${4:-false}
    local reviewers=${5:-}

    if [ -z "$org" ] || [ -z "$repo_name" ] || [ -z "$environment" ]; then
        echo "ERROR: Missing required parameters" >&2
        echo "Usage: vcs_provider_create_environment <org> <repo_name> <environment> [require_reviewers] [reviewers]" >&2
        return 1
    fi

    # Create environment using GitHub API
    local api_result
    if ! api_result=$(gh api "repos/$org/$repo_name/environments/$environment" \
        --method PUT \
        --field wait_timer=0 \
        2>&1); then
        # Environment might already exist, which is OK
        if ! echo "$api_result" | grep -q "already exists"; then
            echo "ERROR: Failed to create environment: $api_result" >&2
            return 1
        fi
    fi

    # Add reviewers if required
    if [ "$require_reviewers" = "true" ] && [ -n "$reviewers" ]; then
        # Get user/team IDs and add as reviewers
        local current_user
        current_user=$(gh api user --jq .login 2>/dev/null)
        local user_id
        user_id=$(gh api "users/$current_user" --jq .id 2>/dev/null)

        gh api "repos/$org/$repo_name/environments/$environment" \
            --method PUT \
            --field reviewers[]='{"type":"User","id":'"$user_id"'}' \
            --field wait_timer=0 \
            2>/dev/null || echo "WARNING: Could not add reviewers (may require GitHub Pro)" >&2
    fi

    return 0
}

vcs_provider_set_environment_secret() {
    local org=$1
    local repo_name=$2
    local environment=$3
    local secret_name=$4
    local secret_value=$5

    if [ -z "$org" ] || [ -z "$repo_name" ] || [ -z "$environment" ] || [ -z "$secret_name" ] || [ -z "$secret_value" ]; then
        echo "ERROR: Missing required parameters" >&2
        echo "Usage: vcs_provider_set_environment_secret <org> <repo_name> <environment> <secret_name> <secret_value>" >&2
        return 1
    fi

    # Set environment secret
    if ! echo "$secret_value" | gh secret set "$secret_name" \
        --repo "$org/$repo_name" \
        --env "$environment" \
        --body - 2>&1; then
        echo "ERROR: Failed to set environment secret" >&2
        return 1
    fi

    return 0
}

# ============================================================================
# Utility Functions
# ============================================================================

vcs_provider_get_current_user() {
    local user
    if ! user=$(gh api user --jq .login 2>&1); then
        echo "ERROR: Failed to get current user: $user" >&2
        return 1
    fi

    echo "$user"
    return 0
}

vcs_provider_is_authenticated() {
    gh auth status &> /dev/null
    return $?
}

# ============================================================================
# Validation
# ============================================================================

# Validate that GitHub CLI is available
_validate_gh_cli() {
    if ! command -v gh &> /dev/null; then
        echo "ERROR: GitHub CLI (gh) is not installed" >&2
        echo "Install: https://cli.github.com/" >&2
        return 1
    fi

    # Check if authenticated
    if ! gh auth status &> /dev/null; then
        echo "ERROR: Not authenticated with GitHub" >&2
        echo "Please run: gh auth login" >&2
        return 1
    fi

    return 0
}

# Run validation on source
if ! _validate_gh_cli; then
    echo "WARNING: GitHub CLI validation failed - some functions may not work" >&2
fi

# ============================================================================
# Export Functions
# ============================================================================

export -f vcs_provider_name
export -f vcs_provider_create_repo
export -f vcs_provider_repo_exists
export -f vcs_provider_delete_repo
export -f vcs_provider_set_secret
export -f vcs_provider_set_variable
export -f vcs_provider_create_environment
export -f vcs_provider_set_environment_secret
export -f vcs_provider_get_current_user
export -f vcs_provider_is_authenticated
