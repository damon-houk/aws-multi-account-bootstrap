#!/usr/bin/env bash

# ============================================================================
# Mock VCS Provider Adapter
# ============================================================================
#
# Implements the vcs-provider-port.sh interface for testing.
# No real VCS operations are performed - all operations are simulated.
#
# Features:
#   - Simulates repository creation, secrets, workflows, etc.
#   - Logs all operations for test verification
#   - Generates fake URLs and identifiers
#   - Thread-safe operation logging
#
# Usage:
#   source scripts/ports/vcs-provider-port.sh
#   source scripts/adapters/mock/mock-vcs-adapter.sh
#   repo_url=$(vcs_provider_create_repo "myorg" "myrepo")
#
# ============================================================================

# Source the port to ensure we implement all required functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/ports/vcs-provider-port.sh
source "$SCRIPT_DIR/../../ports/vcs-provider-port.sh"

# ============================================================================
# Mock State Management
# ============================================================================

# Initialize mock state directory (shared with cloud adapter)
MOCK_STATE_DIR="${MOCK_STATE_DIR:-$(mktemp -d -t aws-bootstrap-mock-XXXXXX)}"
MOCK_VCS_LOG_FILE="$MOCK_STATE_DIR/vcs-operations.log"
MOCK_REPOS_FILE="$MOCK_STATE_DIR/repositories.txt"
MOCK_SECRETS_FILE="$MOCK_STATE_DIR/secrets.txt"
MOCK_WORKFLOWS_FILE="$MOCK_STATE_DIR/workflows.txt"

# Create state files
touch "$MOCK_VCS_LOG_FILE"
touch "$MOCK_REPOS_FILE"
touch "$MOCK_SECRETS_FILE"
touch "$MOCK_WORKFLOWS_FILE"

# Export state directory
export MOCK_STATE_DIR

# Log an operation
_mock_vcs_log() {
    local operation=$1
    shift
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $operation: $*" >> "$MOCK_VCS_LOG_FILE"
}

# ============================================================================
# Repository Management
# ============================================================================

vcs_provider_create_repo() {
    local org=$1
    local repo_name=$2
    local visibility=${3:-private}
    local description=${4:-}

    _mock_vcs_log "create_repo" "org=$org name=$repo_name visibility=$visibility"

    # Validate inputs
    if [ -z "$org" ] || [ -z "$repo_name" ]; then
        echo "ERROR: Missing required parameters" >&2
        return 1
    fi

    # Check if repo already exists
    if grep -q "^${org}/${repo_name}|" "$MOCK_REPOS_FILE" 2>/dev/null; then
        _mock_vcs_log "create_repo" "repository already exists"
        local existing_url
        existing_url=$(grep "^${org}/${repo_name}|" "$MOCK_REPOS_FILE" | cut -d'|' -f2)
        echo "$existing_url"
        return 0
    fi

    # Generate fake repo URL
    local repo_url="https://mock-vcs.example.com/${org}/${repo_name}.git"

    # Store repo info
    echo "${org}/${repo_name}|${repo_url}|${visibility}|${description}" >> "$MOCK_REPOS_FILE"

    # Simulate creation delay
    sleep 0.05

    _mock_vcs_log "create_repo" "created url=$repo_url"
    echo "$repo_url"
    return 0
}

vcs_provider_repo_exists() {
    local org=$1
    local repo_name=$2

    _mock_vcs_log "repo_exists" "org=$org name=$repo_name"

    if grep -q "^${org}/${repo_name}|" "$MOCK_REPOS_FILE" 2>/dev/null; then
        _mock_vcs_log "repo_exists" "found"
        return 0
    else
        _mock_vcs_log "repo_exists" "not found"
        return 1
    fi
}

vcs_provider_delete_repo() {
    local org=$1
    local repo_name=$2

    _mock_vcs_log "delete_repo" "org=$org name=$repo_name"

    # Validate inputs
    if [ -z "$org" ] || [ -z "$repo_name" ]; then
        echo "ERROR: Missing required parameters" >&2
        return 1
    fi

    # Remove from state file
    if [ -f "$MOCK_REPOS_FILE" ]; then
        grep -v "^${org}/${repo_name}|" "$MOCK_REPOS_FILE" > "${MOCK_REPOS_FILE}.tmp" || true
        mv "${MOCK_REPOS_FILE}.tmp" "$MOCK_REPOS_FILE"
    fi

    _mock_vcs_log "delete_repo" "deleted"
    return 0
}

# ============================================================================
# Branch Management
# ============================================================================

vcs_provider_setup_branch_protection() {
    local org=$1
    local repo_name=$2
    local branch=$3
    local require_reviews=${4:-0}
    local require_checks=${5:-false}

    _mock_vcs_log "setup_branch_protection" "org=$org repo=$repo_name branch=$branch reviews=$require_reviews checks=$require_checks"

    # Validate inputs
    if [ -z "$org" ] || [ -z "$repo_name" ] || [ -z "$branch" ]; then
        echo "ERROR: Missing required parameters" >&2
        return 1
    fi

    # Simulate setup
    sleep 0.05

    _mock_vcs_log "setup_branch_protection" "configured successfully"
    return 0
}

vcs_provider_get_default_branch() {
    local org=$1
    local repo_name=$2

    _mock_vcs_log "get_default_branch" "org=$org repo=$repo_name"

    # Always return "main" for mock
    echo "main"
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

    _mock_vcs_log "set_secret" "org=$org repo=$repo_name name=$secret_name value=***REDACTED***"

    # Validate inputs
    if [ -z "$org" ] || [ -z "$repo_name" ] || [ -z "$secret_name" ] || [ -z "$secret_value" ]; then
        echo "ERROR: Missing required parameters" >&2
        return 1
    fi

    # Store secret (with redacted value for security)
    echo "${org}/${repo_name}|repo|${secret_name}|***REDACTED***" >> "$MOCK_SECRETS_FILE"

    _mock_vcs_log "set_secret" "stored successfully"
    return 0
}

vcs_provider_set_variable() {
    local org=$1
    local repo_name=$2
    local variable_name=$3
    local variable_value=$4

    _mock_vcs_log "set_variable" "org=$org repo=$repo_name name=$variable_name value=$variable_value"

    # Validate inputs
    if [ -z "$org" ] || [ -z "$repo_name" ] || [ -z "$variable_name" ] || [ -z "$variable_value" ]; then
        echo "ERROR: Missing required parameters" >&2
        return 1
    fi

    _mock_vcs_log "set_variable" "stored successfully"
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

    _mock_vcs_log "create_environment" "org=$org repo=$repo_name env=$environment reviewers=$require_reviewers"

    # Validate inputs
    if [ -z "$org" ] || [ -z "$repo_name" ] || [ -z "$environment" ]; then
        echo "ERROR: Missing required parameters" >&2
        return 1
    fi

    # Simulate creation
    sleep 0.05

    _mock_vcs_log "create_environment" "created successfully"
    return 0
}

vcs_provider_set_environment_secret() {
    local org=$1
    local repo_name=$2
    local environment=$3
    local secret_name=$4
    local secret_value=$5

    _mock_vcs_log "set_environment_secret" "org=$org repo=$repo_name env=$environment name=$secret_name"

    # Validate inputs
    if [ -z "$org" ] || [ -z "$repo_name" ] || [ -z "$environment" ] || [ -z "$secret_name" ] || [ -z "$secret_value" ]; then
        echo "ERROR: Missing required parameters" >&2
        return 1
    fi

    # Store environment secret
    echo "${org}/${repo_name}|env:${environment}|${secret_name}|***REDACTED***" >> "$MOCK_SECRETS_FILE"

    _mock_vcs_log "set_environment_secret" "stored successfully"
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

    _mock_vcs_log "create_workflow" "org=$org repo=$repo_name name=$workflow_name"

    # Validate inputs
    if [ -z "$org" ] || [ -z "$repo_name" ] || [ -z "$workflow_name" ] || [ -z "$workflow_content" ]; then
        echo "ERROR: Missing required parameters" >&2
        return 1
    fi

    # Store workflow
    echo "${org}/${repo_name}|${workflow_name}|$(echo "$workflow_content" | wc -l) lines" >> "$MOCK_WORKFLOWS_FILE"

    _mock_vcs_log "create_workflow" "created successfully"
    return 0
}

vcs_provider_enable_workflow() {
    local org=$1
    local repo_name=$2
    local workflow_name=$3

    _mock_vcs_log "enable_workflow" "org=$org repo=$repo_name name=$workflow_name"

    # Validate inputs
    if [ -z "$org" ] || [ -z "$repo_name" ] || [ -z "$workflow_name" ]; then
        echo "ERROR: Missing required parameters" >&2
        return 1
    fi

    _mock_vcs_log "enable_workflow" "enabled successfully"
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

    _mock_vcs_log "setup_oidc" "org=$org repo=$repo_name provider=$cloud_provider role=$role_arn env=$environment"

    # Validate inputs
    if [ -z "$org" ] || [ -z "$repo_name" ] || [ -z "$cloud_provider" ] || [ -z "$role_arn" ]; then
        echo "ERROR: Missing required parameters" >&2
        return 1
    fi

    # Simulate OIDC setup
    sleep 0.1

    _mock_vcs_log "setup_oidc" "configured successfully"
    return 0
}

# ============================================================================
# Git Operations
# ============================================================================

vcs_provider_init_local_repo() {
    local repo_path=$1
    local remote_url=$2
    local default_branch=${3:-main}

    _mock_vcs_log "init_local_repo" "path=$repo_path url=$remote_url branch=$default_branch"

    # Validate inputs
    if [ -z "$repo_path" ] || [ -z "$remote_url" ]; then
        echo "ERROR: Missing required parameters" >&2
        return 1
    fi

    # In mock mode, just log - don't actually init git
    _mock_vcs_log "init_local_repo" "initialized (mock - no actual git operation)"
    return 0
}

vcs_provider_push() {
    local repo_path=$1
    local branch=$2
    local force=${3:-false}

    _mock_vcs_log "push" "path=$repo_path branch=$branch force=$force"

    # Validate inputs
    if [ -z "$repo_path" ] || [ -z "$branch" ]; then
        echo "ERROR: Missing required parameters" >&2
        return 1
    fi

    # Simulate push delay
    sleep 0.1

    _mock_vcs_log "push" "pushed successfully (mock)"
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

    _mock_vcs_log "create_release" "org=$org repo=$repo_name tag=$tag_name name=$release_name prerelease=$prerelease"

    # Validate inputs
    if [ -z "$org" ] || [ -z "$repo_name" ] || [ -z "$tag_name" ] || [ -z "$release_name" ]; then
        echo "ERROR: Missing required parameters" >&2
        return 1
    fi

    # Simulate release creation
    sleep 0.05

    local release_url="https://mock-vcs.example.com/${org}/${repo_name}/releases/${tag_name}"
    _mock_vcs_log "create_release" "created url=$release_url"
    echo "$release_url"
    return 0
}

# ============================================================================
# Utility Functions
# ============================================================================

vcs_provider_get_current_user() {
    _mock_vcs_log "get_current_user" "requesting user"

    echo "mock-user"
    return 0
}

vcs_provider_is_authenticated() {
    _mock_vcs_log "is_authenticated" "checking authentication"

    # Always authenticated in mock mode
    return 0
}

# ============================================================================
# Port Metadata
# ============================================================================

vcs_provider_name() {
    echo "Mock"
    return 0
}

# ============================================================================
# Mock-Specific Helper Functions
# ============================================================================

# Get the mock VCS operation log for test verification
mock_vcs_get_log() {
    if [ -f "$MOCK_VCS_LOG_FILE" ]; then
        cat "$MOCK_VCS_LOG_FILE"
    fi
}

# Clear the mock VCS operation log
mock_vcs_clear_log() {
    : > "$MOCK_VCS_LOG_FILE"
}

# Get all mock repositories created
mock_vcs_get_repos() {
    if [ -f "$MOCK_REPOS_FILE" ]; then
        cat "$MOCK_REPOS_FILE"
    fi
}

# Count mock VCS operations of a specific type
mock_vcs_count_operations() {
    local operation=$1
    if [ -f "$MOCK_VCS_LOG_FILE" ]; then
        grep -c "] $operation:" "$MOCK_VCS_LOG_FILE" || echo "0"
    else
        echo "0"
    fi
}

# Verify a VCS operation was logged
mock_vcs_verify_operation() {
    local operation=$1
    local pattern=$2

    if [ ! -f "$MOCK_VCS_LOG_FILE" ]; then
        return 1
    fi

    grep "] $operation:" "$MOCK_VCS_LOG_FILE" | grep -q "$pattern"
}

# Reset all mock VCS state
mock_vcs_reset() {
    : > "$MOCK_VCS_LOG_FILE"
    : > "$MOCK_REPOS_FILE"
    : > "$MOCK_SECRETS_FILE"
    : > "$MOCK_WORKFLOWS_FILE"
}

# Export mock helper functions
export -f mock_vcs_get_log
export -f mock_vcs_clear_log
export -f mock_vcs_get_repos
export -f mock_vcs_count_operations
export -f mock_vcs_verify_operation
export -f mock_vcs_reset

# Log adapter loaded
_mock_vcs_log "adapter" "Mock VCS provider adapter loaded (state_dir=$MOCK_STATE_DIR)"