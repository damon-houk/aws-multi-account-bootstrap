---
description: Set up GitHub repository and CI/CD integration for AWS multi-account project
---

# GitHub Integration Setup


Help me set up GitHub integration for this AWS multi-account bootstrap project.

## What I need:

1. **Check current state:**
   - Verify if GitHub repository exists
   - Check if GitHub CLI (`gh`) is authenticated
   - Review existing GitHub configuration1

2. **Gather required information:**
   - PROJECT_CODE (3-letter identifier)
   - GITHUB_ORG (GitHub username or organization)
   - REPO_NAME (desired repository name)
   - AWS account information (if already created)

3. **Guide me through setup:**
   - Authenticate GitHub CLI if needed
   - Run appropriate make commands for GitHub setup
   - Verify repository creation and configuration
   - Check GitHub Actions workflows
   - Confirm OIDC provider setup
   - Verify branch protection rules

4. **Troubleshooting:**
   - Help diagnose any issues that arise
   - Provide next steps based on current state

## Context:

This project uses:
- GitHub Actions with OIDC authentication (no long-lived credentials)
- Automated semantic versioning
- Branch protection for main/develop branches
- Environments: dev, staging, prod (prod requires approval)

## Available Commands:

- `make setup-github PROJECT_CODE=XYZ GITHUB_ORG=org REPO_NAME=repo` - Create and configure repository
- `make setup-cicd PROJECT_CODE=XYZ GITHUB_ORG=org REPO_NAME=repo` - Set up GitHub Actions with OIDC
- `make show-github-summary` - Show GitHub configuration summary

Please walk me through the process step-by-step.
