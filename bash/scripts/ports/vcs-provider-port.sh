#!/usr/bin/env bash

# ============================================================================
# VCS Provider Port (Interface)
# ============================================================================
#
# Defines the contract for version control system operations.
# Implementations: GitHub, GitLab (future), Bitbucket (future), Mock (testing)
#
# This is an interface - implementations must provide these functions.
# No implementation code should exist in this file.
#
# Usage:
#   source scripts/ports/vcs-provider-port.sh
#   # Then source an adapter that implements these functions
#   source scripts/adapters/github/github-repo-adapter.sh
#
# ============================================================================

# ============================================================================
# Repository Management
# ============================================================================

# Create a new repository
#
# Args:
#   $1 - org: Organization or username
#   $2 - repo_name: Name for the repository
#   $3 - visibility: "private" or "public" (default: "private")
#   $4 - description: (Optional) Repository description
#
# Returns:
#   Repository URL (stdout): HTTPS clone URL
#   Exit code: 0 on success, non-zero on failure
#
# Example:
#   repo_url=$(vcs_provider_create_repo "myorg" "myrepo" "private" "My awesome project")
#
vcs_provider_create_repo() {
    echo "ERROR: vcs_provider_create_repo() not implemented by adapter" >&2
    echo "Please source a VCS provider adapter (e.g., adapters/github/github-repo-adapter.sh)" >&2
    return 1
}

# Check if repository exists
#
# Args:
#   $1 - org: Organization or username
#   $2 - repo_name: Name of the repository
#
# Returns:
#   Exit code: 0 if exists, 1 if not found
#
# Example:
#   if vcs_provider_repo_exists "myorg" "myrepo"; then
#       echo "Repository exists"
#   fi
#
vcs_provider_repo_exists() {
    echo "ERROR: vcs_provider_repo_exists() not implemented by adapter" >&2
    return 1
}

# Delete a repository (use with caution!)
#
# Args:
#   $1 - org: Organization or username
#   $2 - repo_name: Name of the repository to delete
#
# Returns:
#   Exit code: 0 on success, non-zero on failure
#
# Example:
#   vcs_provider_delete_repo "myorg" "old-repo"
#
vcs_provider_delete_repo() {
    echo "ERROR: vcs_provider_delete_repo() not implemented by adapter" >&2
    return 1
}

# ============================================================================
# Branch Management
# ============================================================================

# Create branch protection rules
#
# Args:
#   $1 - org: Organization or username
#   $2 - repo_name: Name of the repository
#   $3 - branch: Branch name to protect (e.g., "main")
#   $4 - require_reviews: Number of required reviews (0 to disable)
#   $5 - require_checks: "true" or "false" - require status checks to pass
#
# Returns:
#   Exit code: 0 on success, non-zero on failure
#
# Example:
#   vcs_provider_setup_branch_protection "myorg" "myrepo" "main" 1 "true"
#
vcs_provider_setup_branch_protection() {
    echo "ERROR: vcs_provider_setup_branch_protection() not implemented by adapter" >&2
    return 1
}

# Get default branch name
#
# Args:
#   $1 - org: Organization or username
#   $2 - repo_name: Name of the repository
#
# Returns:
#   Branch name (stdout): e.g., "main" or "master"
#   Exit code: 0 on success, non-zero on failure
#
# Example:
#   default_branch=$(vcs_provider_get_default_branch "myorg" "myrepo")
#
vcs_provider_get_default_branch() {
    echo "ERROR: vcs_provider_get_default_branch() not implemented by adapter" >&2
    return 1
}

# ============================================================================
# Secrets & Configuration
# ============================================================================

# Set repository secret
#
# Args:
#   $1 - org: Organization or username
#   $2 - repo_name: Name of the repository
#   $3 - secret_name: Name of the secret (e.g., "AWS_ACCOUNT_ID_DEV")
#   $4 - secret_value: Value of the secret
#
# Returns:
#   Exit code: 0 on success, non-zero on failure
#
# Example:
#   vcs_provider_set_secret "myorg" "myrepo" "AWS_ACCOUNT_ID_DEV" "123456789012"
#
vcs_provider_set_secret() {
    echo "ERROR: vcs_provider_set_secret() not implemented by adapter" >&2
    return 1
}

# Set repository variable (non-secret configuration)
#
# Args:
#   $1 - org: Organization or username
#   $2 - repo_name: Name of the repository
#   $3 - variable_name: Name of the variable
#   $4 - variable_value: Value of the variable
#
# Returns:
#   Exit code: 0 on success, non-zero on failure
#
# Example:
#   vcs_provider_set_variable "myorg" "myrepo" "AWS_REGION" "us-east-1"
#
vcs_provider_set_variable() {
    echo "ERROR: vcs_provider_set_variable() not implemented by adapter" >&2
    return 1
}

# ============================================================================
# Environments
# ============================================================================

# Create deployment environment
#
# Args:
#   $1 - org: Organization or username
#   $2 - repo_name: Name of the repository
#   $3 - environment: Environment name (e.g., "production")
#   $4 - require_reviewers: "true" or "false" - require manual approval
#   $5 - reviewers: (Optional) Comma-separated list of reviewer usernames
#
# Returns:
#   Exit code: 0 on success, non-zero on failure
#
# Example:
#   vcs_provider_create_environment "myorg" "myrepo" "production" "true" "admin1,admin2"
#
vcs_provider_create_environment() {
    echo "ERROR: vcs_provider_create_environment() not implemented by adapter" >&2
    return 1
}

# Set environment secret
#
# Args:
#   $1 - org: Organization or username
#   $2 - repo_name: Name of the repository
#   $3 - environment: Environment name
#   $4 - secret_name: Name of the secret
#   $5 - secret_value: Value of the secret
#
# Returns:
#   Exit code: 0 on success, non-zero on failure
#
# Example:
#   vcs_provider_set_environment_secret "myorg" "myrepo" "production" "API_KEY" "secret123"
#
vcs_provider_set_environment_secret() {
    echo "ERROR: vcs_provider_set_environment_secret() not implemented by adapter" >&2
    return 1
}

# ============================================================================
# Workflows & CI/CD
# ============================================================================

# Create workflow file in repository
#
# Args:
#   $1 - org: Organization or username
#   $2 - repo_name: Name of the repository
#   $3 - workflow_name: Name of the workflow file (e.g., "deploy.yml")
#   $4 - workflow_content: Content of the workflow file
#   $5 - commit_message: (Optional) Commit message
#
# Returns:
#   Exit code: 0 on success, non-zero on failure
#
# Example:
#   vcs_provider_create_workflow "myorg" "myrepo" "deploy.yml" "$workflow_content" "Add deploy workflow"
#
vcs_provider_create_workflow() {
    echo "ERROR: vcs_provider_create_workflow() not implemented by adapter" >&2
    return 1
}

# Enable workflow file
#
# Args:
#   $1 - org: Organization or username
#   $2 - repo_name: Name of the repository
#   $3 - workflow_name: Name of the workflow file
#
# Returns:
#   Exit code: 0 on success, non-zero on failure
#
# Example:
#   vcs_provider_enable_workflow "myorg" "myrepo" "deploy.yml"
#
vcs_provider_enable_workflow() {
    echo "ERROR: vcs_provider_enable_workflow() not implemented by adapter" >&2
    return 1
}

# ============================================================================
# OIDC Configuration (for cloud authentication)
# ============================================================================

# Setup OIDC trust relationship for cloud provider
#
# Args:
#   $1 - org: Organization or username
#   $2 - repo_name: Name of the repository
#   $3 - cloud_provider: Cloud provider name (e.g., "aws", "azure", "gcp")
#   $4 - role_arn: ARN or identifier of the cloud role to assume
#   $5 - environment: (Optional) Limit to specific environment
#
# Returns:
#   Exit code: 0 on success, non-zero on failure
#
# Note: This may involve creating workflow files or configuring provider-specific settings
#
# Example:
#   vcs_provider_setup_oidc "myorg" "myrepo" "aws" "arn:aws:iam::123456789012:role/GitHubActions" "production"
#
vcs_provider_setup_oidc() {
    echo "ERROR: vcs_provider_setup_oidc() not implemented by adapter" >&2
    return 1
}

# ============================================================================
# Git Operations
# ============================================================================

# Initialize local git repository and configure remote
#
# Args:
#   $1 - repo_path: Local path to repository
#   $2 - remote_url: Remote repository URL
#   $3 - default_branch: (Optional) Default branch name (default: "main")
#
# Returns:
#   Exit code: 0 on success, non-zero on failure
#
# Example:
#   vcs_provider_init_local_repo "/path/to/repo" "https://github.com/org/repo.git" "main"
#
vcs_provider_init_local_repo() {
    echo "ERROR: vcs_provider_init_local_repo() not implemented by adapter" >&2
    return 1
}

# Push local repository to remote
#
# Args:
#   $1 - repo_path: Local path to repository
#   $2 - branch: Branch to push (e.g., "main")
#   $3 - force: (Optional) "true" to force push (default: "false")
#
# Returns:
#   Exit code: 0 on success, non-zero on failure
#
# Example:
#   vcs_provider_push "path/to/repo" "main" "false"
#
vcs_provider_push() {
    echo "ERROR: vcs_provider_push() not implemented by adapter" >&2
    return 1
}

# ============================================================================
# Releases & Tags
# ============================================================================

# Create a release/tag
#
# Args:
#   $1 - org: Organization or username
#   $2 - repo_name: Name of the repository
#   $3 - tag_name: Tag name (e.g., "v1.0.0")
#   $4 - release_name: Human-readable release name
#   $5 - body: (Optional) Release notes
#   $6 - prerelease: (Optional) "true" or "false" (default: "false")
#
# Returns:
#   Exit code: 0 on success, non-zero on failure
#
# Example:
#   vcs_provider_create_release "myorg" "myrepo" "v1.0.0" "Initial Release" "First stable release" "false"
#
vcs_provider_create_release() {
    echo "ERROR: vcs_provider_create_release() not implemented by adapter" >&2
    return 1
}

# ============================================================================
# Utility Functions
# ============================================================================

# Get current authenticated user
#
# Returns:
#   Username (stdout): e.g., "johndoe"
#   Exit code: 0 on success, non-zero on failure
#
# Example:
#   username=$(vcs_provider_get_current_user)
#
vcs_provider_get_current_user() {
    echo "ERROR: vcs_provider_get_current_user() not implemented by adapter" >&2
    return 1
}

# Check if user is authenticated
#
# Returns:
#   Exit code: 0 if authenticated, 1 if not
#
# Example:
#   if vcs_provider_is_authenticated; then
#       echo "Authenticated"
#   fi
#
vcs_provider_is_authenticated() {
    echo "ERROR: vcs_provider_is_authenticated() not implemented by adapter" >&2
    return 1
}

# ============================================================================
# Port Metadata
# ============================================================================

# Return the name of the VCS provider implementation
#
# Returns:
#   Provider name (stdout): e.g., "GitHub", "GitLab", "Bitbucket", "Mock"
#   Exit code: 0 on success
#
# Example:
#   provider=$(vcs_provider_name)
#   echo "Using VCS provider: $provider"
#
vcs_provider_name() {
    echo "UNIMPLEMENTED"
    return 0
}

# Validate that all required port functions are implemented
#
# Returns:
#   Exit code: 0 if all functions implemented, 1 if any missing
#
# Example:
#   if vcs_provider_validate_port; then
#       echo "All port functions implemented"
#   fi
#
vcs_provider_validate_port() {
    local missing=0
    local functions=(
        "vcs_provider_create_repo"
        "vcs_provider_repo_exists"
        "vcs_provider_delete_repo"
        "vcs_provider_setup_branch_protection"
        "vcs_provider_get_default_branch"
        "vcs_provider_set_secret"
        "vcs_provider_set_variable"
        "vcs_provider_create_environment"
        "vcs_provider_set_environment_secret"
        "vcs_provider_create_workflow"
        "vcs_provider_enable_workflow"
        "vcs_provider_setup_oidc"
        "vcs_provider_init_local_repo"
        "vcs_provider_push"
        "vcs_provider_create_release"
        "vcs_provider_get_current_user"
        "vcs_provider_is_authenticated"
        "vcs_provider_name"
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
export -f vcs_provider_create_repo
export -f vcs_provider_repo_exists
export -f vcs_provider_delete_repo
export -f vcs_provider_setup_branch_protection
export -f vcs_provider_get_default_branch
export -f vcs_provider_set_secret
export -f vcs_provider_set_variable
export -f vcs_provider_create_environment
export -f vcs_provider_set_environment_secret
export -f vcs_provider_create_workflow
export -f vcs_provider_enable_workflow
export -f vcs_provider_setup_oidc
export -f vcs_provider_init_local_repo
export -f vcs_provider_push
export -f vcs_provider_create_release
export -f vcs_provider_get_current_user
export -f vcs_provider_is_authenticated
export -f vcs_provider_name
export -f vcs_provider_validate_port