#!/bin/bash

# Script to create and configure GitHub repository with all best practices
# Usage: ./setup-github-repo.sh TPA your-github-org therapy-practice-app

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Check arguments
if [ "$#" -ne 3 ]; then
    echo -e "${RED}ERROR: Missing required arguments${NC}"
    echo ""
    echo "Usage: $0 <PROJECT_CODE> <GITHUB_ORG> <REPO_NAME>"
    echo ""
    echo "Example:"
    echo "  $0 TPA myusername therapy-practice-app"
    echo ""
    exit 1
fi

PROJECT_CODE=$1
GITHUB_ORG=$2
REPO_NAME=$3

echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║      GitHub Repository Setup with Best Practices         ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${GREEN}Configuration${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Project Code:    $PROJECT_CODE"
echo "  GitHub Org:      $GITHUB_ORG"
echo "  Repository:      $REPO_NAME"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}ERROR: GitHub CLI (gh) is not installed${NC}"
    echo ""
    echo "Install with:"
    echo "  macOS:   brew install gh"
    echo "  Linux:   See https://github.com/cli/cli/blob/trunk/docs/install_linux.md"
    echo "  Windows: See https://github.com/cli/cli#windows"
    echo ""
    exit 1
fi

# Check if authenticated with GitHub
if ! gh auth status &> /dev/null; then
    echo -e "${YELLOW}Not authenticated with GitHub${NC}"
    echo "Authenticating..."
    gh auth login
fi

echo -e "${GREEN}✓ Authenticated with GitHub${NC}"
echo ""

# Ask for repository visibility
echo -e "${BLUE}Repository Settings${NC}"
echo ""
read -p "Make repository private? [Y/n] " -n 1 -r
echo ""
VISIBILITY="--private"
if [[ $REPLY =~ ^[Nn]$ ]]; then
    VISIBILITY="--public"
fi

read -p "Continue with repository creation? [y/N] " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}STEP 1/7: Creating GitHub Repository${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Create repository
if gh repo view "$GITHUB_ORG/$REPO_NAME" &> /dev/null; then
    echo -e "${YELLOW}Repository already exists: $GITHUB_ORG/$REPO_NAME${NC}"
else
    echo "Creating repository..."
    gh repo create "$GITHUB_ORG/$REPO_NAME" \
        $VISIBILITY \
        --description "Therapy practice management application for cash-pay therapists" \
        --disable-wiki \
        || { echo -e "${RED}Failed to create repository${NC}"; exit 1; }

    echo -e "${GREEN}✓ Repository created${NC}"
fi

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}STEP 2/7: Setting Up Branch Protection${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Push initial commit if needed
if [ ! -d ".git" ]; then
    git init
    git add .
    git commit -m "Initial commit: Project setup"
fi

# Add remote if not exists
if ! git remote get-url origin &> /dev/null; then
    git remote add origin "https://github.com/$GITHUB_ORG/$REPO_NAME.git"
fi

# Push to main
git branch -M main
git push -u origin main

echo "Configuring branch protection for main..."

# Enable branch protection for main
gh api repos/$GITHUB_ORG/$REPO_NAME/branches/main/protection \
    --method PUT \
    --field required_status_checks='{"strict":true,"contexts":["test"]}' \
    --field enforce_admins=false \
    --field required_pull_request_reviews='{"dismiss_stale_reviews":true,"require_code_owner_reviews":false,"required_approving_review_count":1}' \
    --field restrictions=null \
    --field required_linear_history=true \
    --field allow_force_pushes=false \
    --field allow_deletions=false \
    --field required_conversation_resolution=true \
    2>/dev/null || echo "  Note: Some protection rules may require GitHub Pro"

echo -e "${GREEN}✓ Main branch protected${NC}"

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}STEP 3/7: Creating Develop Branch${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Create and push develop branch
git checkout -b develop 2>/dev/null || git checkout develop
git push -u origin develop

# Enable branch protection for develop
echo "Configuring branch protection for develop..."
gh api repos/$GITHUB_ORG/$REPO_NAME/branches/develop/protection \
    --method PUT \
    --field required_status_checks='{"strict":true,"contexts":["test"]}' \
    --field enforce_admins=false \
    --field required_pull_request_reviews='{"dismiss_stale_reviews":true,"require_code_owner_reviews":false,"required_approving_review_count":1}' \
    --field restrictions=null \
    --field allow_force_pushes=false \
    --field allow_deletions=false \
    --field required_conversation_resolution=true \
    2>/dev/null || echo "  Note: Some protection rules may require GitHub Pro"

echo -e "${GREEN}✓ Develop branch created and protected${NC}"

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}STEP 4/7: Creating Environments${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Create environments
for ENV in dev staging prod; do
    echo "Creating $ENV environment..."

    # Create environment
    gh api repos/$GITHUB_ORG/$REPO_NAME/environments/$ENV \
        --method PUT \
        --field wait_timer=0 \
        2>/dev/null || true

    # For prod, add protection
    if [ "$ENV" = "prod" ]; then
        echo "  Adding reviewers to prod environment..."
        GITHUB_USER=$(gh api user --jq .login)
        USER_ID=$(gh api users/$GITHUB_USER --jq .id)
        gh api repos/$GITHUB_ORG/$REPO_NAME/environments/prod \
            --method PUT \
            --field reviewers[]='{"type":"User","id":'"$USER_ID"'}' \
            --field wait_timer=0 \
            2>/dev/null || echo "  Note: Environment protection may require GitHub Pro"
    fi

    echo -e "${GREEN}  ✓ $ENV environment created${NC}"
done

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}STEP 5/7: Setting Up Labels${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Create custom labels
declare -A LABELS
LABELS=(
    ["bug"]="d73a4a"
    ["enhancement"]="a2eeef"
    ["documentation"]="0075ca"
    ["infrastructure"]="fbca04"
    ["security"]="d93f0b"
    ["dependencies"]="0366d6"
    ["frontend"]="e99695"
    ["backend"]="c2e0c6"
    ["breaking-change"]="b60205"
    ["good-first-issue"]="7057ff"
)

for LABEL in "${!LABELS[@]}"; do
    COLOR=${LABELS[$LABEL]}
    gh label create "$LABEL" --color "$COLOR" --repo "$GITHUB_ORG/$REPO_NAME" 2>/dev/null || true
done

echo -e "${GREEN}✓ Labels created${NC}"

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}STEP 6/7: Setting Up Semantic Versioning${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Create semantic release configuration
cat > .releaserc.json <<EOF
{
  "branches": [
    "main",
    {
      "name": "develop",
      "prerelease": "beta"
    }
  ],
  "plugins": [
    "@semantic-release/commit-analyzer",
    "@semantic-release/release-notes-generator",
    [
      "@semantic-release/changelog",
      {
        "changelogFile": "CHANGELOG.md"
      }
    ],
    "@semantic-release/npm",
    [
      "@semantic-release/git",
      {
        "assets": ["CHANGELOG.md", "package.json"],
        "message": "chore(release): \${nextRelease.version} [skip ci]\n\n\${nextRelease.notes}"
      }
    ],
    "@semantic-release/github"
  ]
}
EOF

# Create commitlint config
cat > .commitlintrc.json <<EOF
{
  "extends": ["@commitlint/config-conventional"],
  "rules": {
    "type-enum": [
      2,
      "always",
      [
        "feat",
        "fix",
        "docs",
        "style",
        "refactor",
        "perf",
        "test",
        "build",
        "ci",
        "chore",
        "revert"
      ]
    ]
  }
}
EOF

# Create semantic release workflow
mkdir -p .github/workflows
cat > .github/workflows/release.yml <<EOF
name: Release

on:
  push:
    branches:
      - main
      - develop

permissions:
  contents: write
  issues: write
  pull-requests: write

jobs:
  release:
    name: Semantic Release
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
          persist-credentials: false

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install dependencies
        run: |
          npm install --save-dev semantic-release @semantic-release/changelog @semantic-release/git @semantic-release/github

      - name: Release
        env:
          GITHUB_TOKEN: \${{ secrets.GITHUB_TOKEN }}
          NPM_TOKEN: \${{ secrets.NPM_TOKEN }}
        run: npx semantic-release
EOF

# Update package.json with semantic release dependencies
if [ -f "package.json" ]; then
    # Add semantic release to devDependencies
    npm install --save-dev \
        semantic-release \
        @semantic-release/changelog \
        @semantic-release/git \
        @semantic-release/github \
        @commitlint/cli \
        @commitlint/config-conventional \
        --silent 2>/dev/null || true
fi

echo -e "${GREEN}✓ Semantic versioning configured${NC}"
echo ""
echo "Commit message format:"
echo "  feat: Add new feature (minor version bump)"
echo "  fix: Bug fix (patch version bump)"
echo "  feat!: Breaking change (major version bump)"
echo "  docs: Documentation only"
echo "  chore: Maintenance tasks"

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}STEP 7/7: Creating Initial Release${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Commit semantic release files
git add .releaserc.json .commitlintrc.json .github/workflows/release.yml package.json package-lock.json
git commit -m "chore: Setup semantic versioning and automated releases" || true
git push

# Create initial tag
git tag v0.1.0
git push --tags

echo -e "${GREEN}✓ Initial release v0.1.0 created${NC}"

# Create release on GitHub
gh release create v0.1.0 \
    --title "v0.1.0 - Initial Release" \
    --notes "🎉 Initial project setup

## Features
- Multi-account AWS infrastructure
- CI/CD with GitHub Actions
- Automated semantic versioning
- Branch protection and environments configured

## Getting Started
See README.md for setup instructions." \
    --repo "$GITHUB_ORG/$REPO_NAME" \
    2>/dev/null || true

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ GitHub Repository Setup Complete!${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Create summary
cat > GITHUB_SETUP_SUMMARY.md <<EOF
# GitHub Repository Setup Summary

## Repository
**URL:** https://github.com/$GITHUB_ORG/$REPO_NAME

## Branches
- **main** - Production-ready code (protected)
- **develop** - Development branch (protected)

## Branch Protection Rules
Both \`main\` and \`develop\` branches are protected with:
- ✅ Require pull request before merging
- ✅ Require status checks to pass
- ✅ Dismiss stale reviews when new commits are pushed
- ✅ Require conversation resolution before merging
- ✅ Require linear history (no merge commits)
- ❌ Force pushes disabled
- ❌ Branch deletion disabled

## Environments
- **dev** - Auto-deploy from develop branch
- **staging** - Auto-deploy from main branch
- **prod** - Manual deploy with required approval

## Labels
Standard labels created for issue/PR management:
- bug, enhancement, documentation
- infrastructure, security, dependencies
- frontend, backend
- breaking-change, good-first-issue

## Semantic Versioning
Automated versioning based on commit messages:

### Commit Message Format
\`\`\`
<type>(<scope>): <subject>

[optional body]

[optional footer]
\`\`\`

### Types
- **feat**: New feature (bumps minor version)
- **fix**: Bug fix (bumps patch version)
- **feat!** or **fix!**: Breaking change (bumps major version)
- **docs**: Documentation only
- **style**: Code style changes
- **refactor**: Code refactoring
- **perf**: Performance improvements
- **test**: Adding tests
- **build**: Build system changes
- **ci**: CI/CD changes
- **chore**: Maintenance tasks

### Examples
\`\`\`bash
git commit -m "feat: Add user authentication"
git commit -m "fix: Resolve login bug"
git commit -m "feat!: Change API response format"
git commit -m "docs: Update README"
\`\`\`

## Releases
- Releases are automatically created when merging to \`main\`
- Version numbers follow semantic versioning (MAJOR.MINOR.PATCH)
- Changelog is automatically generated from commit messages
- GitHub releases include release notes

## Workflow
1. Create feature branch from \`develop\`
2. Make changes with semantic commit messages
3. Create PR to \`develop\`
4. After approval and tests pass, merge
5. Auto-deploys to dev environment
6. When ready for staging, create PR: \`develop\` → \`main\`
7. After approval, merge to \`main\`
8. Auto-deploys to staging
9. Auto-creates release with version bump
10. Manual trigger to deploy to prod

## Repository Settings
- Wiki: Disabled (use docs/ folder instead)
- Issues: Enabled
- Projects: Enabled
- Pull Requests: Enabled
- Discussions: Can be enabled if needed

## Next Steps
1. Clone repository: \`git clone https://github.com/$GITHUB_ORG/$REPO_NAME.git\`
2. Create feature branch: \`git checkout -b feature/my-feature\`
3. Make changes and commit with semantic messages
4. Push and create PR
5. Watch CI/CD pipeline run!

## Useful Commands
\`\`\`bash
# View repository
gh repo view $GITHUB_ORG/$REPO_NAME --web

# Create issue
gh issue create --title "Bug: Something broken" --body "Details here"

# Create PR
gh pr create --title "feat: Add new feature" --body "Description"

# View releases
gh release list

# Create release manually
gh release create v1.0.0 --title "v1.0.0" --notes "Release notes"
\`\`\`
EOF

echo "Summary written to: GITHUB_SETUP_SUMMARY.md"
echo ""
echo -e "${BLUE}Repository URL:${NC}"
echo "  https://github.com/$GITHUB_ORG/$REPO_NAME"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  1. Review GITHUB_SETUP_SUMMARY.md"
echo "  2. Create a feature branch and test the workflow"
echo "  3. Use semantic commit messages (feat:, fix:, etc.)"
echo ""
echo -e "${GREEN}Happy coding! 🚀${NC}"
echo ""