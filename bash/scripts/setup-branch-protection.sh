#!/bin/bash

# Setup Branch Protection Rules for GitHub Repository
# This script configures branch protection for main and develop branches

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}Branch Protection Setup${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Check if gh is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}Error: GitHub CLI (gh) is not installed${NC}"
    echo "Please install it first:"
    echo "  - Windows: winget install --id GitHub.cli"
    echo "  - macOS: brew install gh"
    echo "  - Linux: See https://cli.github.com/manual/installation"
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    echo -e "${RED}Error: Not authenticated with GitHub${NC}"
    echo "Please run: gh auth login"
    exit 1
fi

# Get repository info
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
echo -e "${BLUE}Configuring branch protection for: ${GREEN}$REPO${NC}"
echo ""

# Function to setup branch protection
setup_branch_protection() {
    local BRANCH=$1
    local REQUIRE_REVIEWS=$2

    echo -e "${YELLOW}Setting up protection for branch: $BRANCH${NC}"

    # Base protection settings
    PROTECTION_ARGS=(
        --branch "$BRANCH"
        --required-status-checks "lint-scripts,lint-makefile,lint-docs,unit-tests,validate-structure"
        --require-conversation-resolution
        --block-force-push
    )

    # Add review requirements if specified
    if [ "$REQUIRE_REVIEWS" = "true" ]; then
        PROTECTION_ARGS+=(
            --required-review-count 1
            --dismiss-stale-reviews
        )
    fi

    # Apply branch protection
    if gh api \
        --method PUT \
        -H "Accept: application/vnd.github+json" \
        "/repos/$REPO/branches/$BRANCH/protection" \
        -f "required_status_checks[strict]=true" \
        -f "required_status_checks[contexts][]=lint-scripts" \
        -f "required_status_checks[contexts][]=lint-makefile" \
        -f "required_status_checks[contexts][]=lint-docs" \
        -f "required_status_checks[contexts][]=unit-tests" \
        -f "required_status_checks[contexts][]=validate-structure" \
        -f "enforce_admins=true" \
        -f "required_pull_request_reviews[dismiss_stale_reviews]=true" \
        -f "required_pull_request_reviews[require_code_owner_reviews]=false" \
        -f "required_pull_request_reviews[required_approving_review_count]=${REQUIRE_REVIEWS:+1}" \
        -f "required_conversation_resolution=true" \
        -f "restrictions=null" \
        -F "allow_force_pushes=false" \
        -F "allow_deletions=false"; then

        echo -e "${GREEN}✓ Branch protection configured for $BRANCH${NC}"
    else
        echo -e "${RED}✗ Failed to configure branch protection for $BRANCH${NC}"
        return 1
    fi

    echo ""
}

# Setup protection for main branch (with reviews required)
setup_branch_protection "main" "true"

# Setup protection for develop branch (optional reviews)
setup_branch_protection "develop" "false"

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Branch Protection Setup Complete!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo "Branch protection rules configured:"
echo "  - main: Requires 1 approval + status checks"
echo "  - develop: Requires status checks only"
echo ""
echo "View settings at:"
echo "  https://github.com/$REPO/settings/branches"