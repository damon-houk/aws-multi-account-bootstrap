# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commit Message Convention

When creating git commits in this repository, ALWAYS append the following tag at the end of commit messages:

```
AI: Claude Code
```

This tag helps track AI-assisted contributions for review and quality assurance purposes.

## Project Overview

This is an AWS multi-account infrastructure bootstrap tool that automates the setup of a complete production-ready environment with GitHub CI/CD. It creates 3 AWS accounts (dev, staging, prod) in an AWS Organization, bootstraps AWS CDK, configures GitHub Actions with OIDC authentication, sets up semantic versioning, and implements billing alerts.

**Key Technology Stack:**
- AWS CDK (infrastructure as code)
- AWS Organizations (multi-account management)
- GitHub Actions with OIDC (CI/CD)
- Bash scripts (orchestration)
- Makefile (command interface)
- Semantic Release (automated versioning)

## Core Architecture

### Multi-Account Setup Flow

The bootstrap process follows this sequence (orchestrated by `scripts/setup-complete-project.sh`):

1. **Account Creation** (`create-project-accounts.sh`): Uses AWS Organizations API to create 3 member accounts with standardized naming (`{PROJECT_CODE}_DEV`, `{PROJECT_CODE}_STAGING`, `{PROJECT_CODE}_PROD`) using Gmail alias pattern (`email+project-env@gmail.com`)

2. **CDK Bootstrap** (`bootstrap-cdk.sh`): Assumes `OrganizationAccountAccessRole` in each member account to bootstrap CDK (creates S3 buckets, ECR repos, IAM roles for cross-account deployments)

3. **GitHub Actions OIDC Setup** (`setup-github-cicd.sh`): Creates OIDC identity providers in each AWS account, configures IAM roles with trust policies for GitHub Actions, stores account IDs as GitHub secrets

4. **GitHub Repository Configuration** (`setup-github-repo.sh`): Creates repository, sets branch protection (main/develop), configures environments (dev/staging/prod with prod requiring approval), creates initial release (v0.1.0)

5. **Billing Alerts** (`setup-billing-alerts.sh`): Configures CloudWatch billing alarms ($15 threshold) and AWS Budgets ($25 monthly limit) with SNS email notifications per account

### Project Code Pattern

All scripts and resources use a **3-letter PROJECT_CODE** as the primary identifier. This code:
- Must be exactly 3 characters
- Used for account names, stack names, resource tagging
- Appears in generated documentation and configuration files
- Enables multiple projects in same AWS Organization

### Generated Project Structure

When setup completes, the tool generates a TypeScript CDK project structure:
```
infrastructure/
  bin/app.ts           # CDK app entry point (reads ENV variable)
  lib/                 # User's CDK stacks go here
src/
  frontend/            # Application frontend
  backend/             # Lambda functions
  shared/              # Shared utilities
.github/workflows/     # CI/CD pipelines (generated)
```

### Environment-Based Deployment

The CDK app uses `process.env.ENV` to determine target environment (dev/staging/prod). The Makefile and GitHub Actions workflows set this variable before CDK operations.

## Build & Development Commands

### Prerequisites Check
```bash
make check-prerequisites    # Verify AWS CLI, CDK, jq, Node.js, git installed
```

### Complete Setup (One Command)
```bash
make setup-all PROJECT_CODE=MYP EMAIL_PREFIX=your.email OU_ID=ou-xxxx-xxxxxxxx GITHUB_ORG=username REPO_NAME=project
```

### Individual Setup Steps
```bash
make create-accounts PROJECT_CODE=MYP EMAIL_PREFIX=your.email OU_ID=ou-xxxx-xxxxxxxx
make bootstrap PROJECT_CODE=MYP
make setup-github PROJECT_CODE=MYP GITHUB_ORG=username REPO_NAME=project
make setup-cicd PROJECT_CODE=MYP GITHUB_ORG=username REPO_NAME=project
make setup-billing PROJECT_CODE=MYP EMAIL=your.email@gmail.com
```

### Development Commands
```bash
make install               # npm install
make build                 # Compile TypeScript
make test                  # Run Jest tests
make lint                  # Run ESLint
make watch                 # Watch mode for TypeScript
```

### CDK Operations
```bash
make synth                 # Synthesize CloudFormation templates
make diff                  # Show differences from deployed state
make deploy-dev            # Deploy to dev account (ENV=dev)
make deploy-staging        # Deploy to staging account (ENV=staging)
make deploy-prod           # Deploy to prod account (ENV=prod)
make destroy-dev           # Destroy dev stacks
```

### Information & Troubleshooting
```bash
make list-accounts                      # List all AWS Organization accounts
make account-info PROJECT_CODE=MYP      # Show account IDs and details
make show-summary                       # Display CICD_SETUP_SUMMARY.md
make show-github-summary                # Display GITHUB_SETUP_SUMMARY.md
make show-billing-summary               # Display BILLING_ALERTS_SUMMARY.md
```

## CI/CD Workflow

### Branching Strategy
- `main`: Production-ready code, protected branch
- `develop`: Integration branch, protected branch
- `feature/*`: Feature branches (PR required to merge)

### Deployment Triggers
- Push to `develop` → Auto-deploy to dev account
- Push to `main` → Auto-deploy to staging account + create semantic release
- Manual workflow dispatch → Deploy to prod account (requires approval)

### Semantic Versioning
Commit messages drive automated versioning:
- `feat:` → Minor version bump (0.1.0 → 0.2.0)
- `fix:` → Patch version bump (0.1.0 → 0.1.1)
- `feat!:` or `BREAKING CHANGE:` → Major version bump (0.1.0 → 1.0.0)
- `docs:`, `chore:`, `style:`, `refactor:`, `perf:`, `test:` → No version bump

Example commits:
```bash
git commit -m "feat: Add user authentication"
git commit -m "fix: Correct timezone handling in appointments"
git commit -m "feat!: Redesign API structure

BREAKING CHANGE: All endpoints now require authentication"
```

## Key Implementation Details

### Account Access Pattern
Scripts use `aws sts assume-role` to access member accounts via `OrganizationAccountAccessRole` (automatically created by AWS Organizations). The management account credentials must be configured via `aws sso login`.

### OIDC Authentication
GitHub Actions authenticate to AWS using OpenID Connect (no long-lived credentials). Each AWS account has:
- OIDC identity provider (thumbprint for `token.actions.githubusercontent.com`)
- IAM role `GitHubActionsDeployRole` with trust policy for specific GitHub repo
- Trust policy validates: repository name, branch/tag conditions

### Generated Documentation Files
After setup, these files are created in the project root:
- `CICD_SETUP_SUMMARY.md`: AWS account IDs, regions, IAM role ARNs
- `GITHUB_SETUP_SUMMARY.md`: Repository URL, branch protection rules, environments
- `BILLING_ALERTS_SUMMARY.md`: Billing thresholds, SNS topics, budget limits
- `BILLING_MANAGEMENT.md`: Complete cost management guide

### Billing Alert Configuration
Per-account defaults:
- CloudWatch alarm: $15 monthly threshold
- AWS Budget: $25 monthly limit with alerts at 60%, 90%, 100%
- Forecast alert: Predicted to exceed budget
- All alerts sent to SNS topic (requires email confirmation)

## Common Patterns & Best Practices

### Adding New CDK Stacks
1. Create stack file in `infrastructure/lib/my-stack.ts`
2. Import and instantiate in `infrastructure/bin/app.ts`
3. Use environment variable: `const env = process.env.ENV || 'dev'`
4. Tag all resources with `Project` and `Environment` tags
5. Test locally: `make synth && make deploy-dev`

### Cross-Account Deployments
CDK bootstrap creates trust relationships. To deploy from dev account to staging:
```typescript
new MyStack(app, `${projectCode}-${env}-Stack`, {
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT,  // Target account
    region: process.env.CDK_DEFAULT_REGION,
  },
});
```

### Script Modification Guidelines
- All scripts use `set -e` (fail on error)
- Color codes: GREEN (success), YELLOW (warning), RED (error), BLUE (info), CYAN (headers)
- Always validate inputs before AWS API calls
- Use `jq` for JSON parsing (required dependency)
- Scripts expect to run from `scripts/` directory

### Makefile Variable Handling
Required variables checked by targets:
- `check-vars`: PROJECT_CODE, EMAIL_PREFIX
- `check-all-vars`: Also requires OU_ID, GITHUB_ORG, REPO_NAME
- Pass variables: `make target VAR=value`

## Testing

This repository is primarily infrastructure automation. Tests should focus on:
- Script validation (parameter checking, error handling)
- CDK construct testing (Jest with `@aws-cdk/assert`)
- Integration testing (create test accounts, verify resources)

Run tests: `make test` (runs Jest if configured in generated project)

## Troubleshooting Common Issues

### "Not authenticated with AWS"
```bash
aws sso login
aws sts get-caller-identity  # Verify authentication
```

### "Account already exists"
Scripts should handle existing accounts gracefully. Check AWS Console → Organizations to verify account state.

### "CDK bootstrap fails"
Ensure you're authenticated to management account and have Organizations permissions:
```bash
aws organizations describe-organization  # Verify access
```

### "GitHub CLI not authenticated"
```bash
gh auth login  # Authenticate GitHub CLI
gh auth status # Verify authentication
```

### "Cannot assume OrganizationAccountAccessRole"
Wait 30 seconds after account creation (AWS propagation delay). The role may not be immediately available.

## Security Considerations

- Never commit AWS credentials or GitHub tokens
- OIDC eliminates need for long-lived credentials in GitHub
- Use least-privilege IAM policies (default uses AdministratorAccess for bootstrap)
- All scripts validate input format before execution
- Branch protection prevents direct commits to main/develop
- Prod environment requires manual approval for deployments

## Windows Considerations

This codebase runs on Windows (indicated by the `win32` platform). Key considerations:
- Scripts use bash (requires Git Bash, WSL, or similar)
- File paths use forward slashes in scripts but Windows paths externally
- Line endings: Scripts should use LF (not CRLF) for bash compatibility
- The Makefile uses Unix commands (requires make for Windows or WSL)

## Design Philosophy & Decisions

### Why 3 Accounts Instead of 5+?
AWS recommends 5-7 accounts (security, logging, network, shared services, workloads),
but we chose 3 for v1.0 because:
- **Simplicity**: Most startups/small teams don't need the complexity initially
- **Lower costs**: Fewer accounts = lower baseline costs
- **Faster adoption**: Less overwhelming for new users
- **Scalable**: Can add more accounts later (planned for v1.1 with templates)

### Why GitHub-First vs AWS CodePipeline?
- Most developers prefer GitHub over CodeCommit
- OIDC authentication (no long-lived credentials)
- Better integration with modern workflows
- Semantic versioning ecosystem (semantic-release)
- Note: AWS-native CI/CD option planned for v2.0

### Why CDK Instead of Terraform?
- TypeScript provides better IDE support
- More developer-friendly than HCL
- Easier for developers already using Node.js
- Note: We compared with oliverschenk/aws-multi-account-multi-region-bootstrapping-terraform
  and grendel-consulting/terraform-aws-cdk_bootstrap - ours fills different niche

### Why Apache 2.0 License?
- Patent protection (important for infrastructure tools)
- Business-friendly (maximizes adoption)
- Standard in AWS/cloud ecosystem
- Allows commercial use without forcing open-source derivatives

### One-Command Philosophy
Everything should work with a single command:
```bash
make setup-all PROJECT_CODE=XYZ ...
```
This is the core differentiator from complex alternatives that require multiple manual steps.

## Project Evolution Context

### Original Use Case
Built to support a therapy practice management SaaS (TPA = Therapy Practice App).
Requirements drove decisions:
- HIPAA compliance considerations (encryption, audit logging, billing alerts)
- Need for dev/staging/prod separation
- Cost consciousness (billing alerts @ $15, budget @ $25 per account)
- Small team (solo developer initially)

### Comparison to Alternatives
We analyzed two existing projects:
1. **oliverschenk/aws-multi-account-multi-region-bootstrapping-terraform**
    - More comprehensive (5 accounts, multi-region, Terragrunt)
    - Last updated 2 years ago
    - Complex setup with many manual steps
    - Our niche: Simpler, modern, GitHub-first

2. **grendel-consulting/terraform-aws-cdk_bootstrap**
    - Just CDK bootstrap in Terraform (for Control Tower users)
    - Very specific niche
    - Not a competitor - solves different problem

### Key Architectural Choices

**Email Address Strategy:**
Uses Gmail + addressing for multiple accounts:
- `user+project-dev@gmail.com`
- `user+project-staging@gmail.com`
- `user+project-prod@gmail.com`
  All go to same inbox but AWS sees as different emails.

**PROJECT_CODE Pattern:**
3-letter identifier used consistently:
- Account names: `TPA_DEV`, `TPA_STAGING`, `TPA_PROD`
- Resources: `tpa-dev-client-documents`
- Tags: `Project: TPA`
- Stack names: `TPA-dev-Infrastructure`

**Billing Alert Structure:**
Default per-account thresholds chosen based on typical small app costs:
- Alert: $15 (catches runaway costs early)
- Budget: $25 (reasonable monthly limit for dev/staging)
- Total: ~$75/month for all 3 environments
- Production gets higher limits in practice

**Generated Documentation:**
Three auto-generated files provide ongoing reference:
- `CICD_SETUP_SUMMARY.md` - Account IDs, role ARNs
- `GITHUB_SETUP_SUMMARY.md` - Repository configuration
- `BILLING_ALERTS_SUMMARY.md` - Cost alert details

## Semantic Versioning Strategy

Automated releases use conventional commits:
- `feat:` → minor version (0.1.0 → 0.2.0)
- `fix:` → patch version (0.1.0 → 0.1.1)
- `feat!:` or `BREAKING CHANGE:` → major version (0.1.0 → 1.0.0)
- `docs:`, `chore:`, etc. → no release

This is enforced via `.releaserc.json` and GitHub Actions.

## Roadmap Priorities

### v1.0 (Current) ✅
Focus: Ship minimum viable product that works perfectly
- 3 accounts only
- Single template (minimal)
- GitHub-only CI/CD

### v1.1 (Next)
Focus: Flexibility without complexity
- Account structure templates (minimal/standard/enterprise)
- YAML config file support
- Interactive CLI mode
- GitLab support

### v1.2
Focus: Production features
- Multi-region support
- Terraform bootstrap option
- Pre-configured stack templates
- Cost estimation

### v2.0
Focus: Enterprise readiness
- Service Control Policies
- Control Tower integration
- Compliance packs (HIPAA, SOC2)
- 5-7 account templates

## Development Patterns

### Adding New Scripts
1. Place in `scripts/` directory
2. Make executable: `chmod +x`
3. Add to Makefile as target
4. Document in README
5. Add error handling and color output
6. Follow existing script style

### Testing Philosophy
Currently manual testing (v1.0 focus on working implementation).
Planned for v1.1:
- Unit tests with bats-core
- Integration tests with localstack
- E2E tests in isolated AWS org (expensive, run periodically)

### Error Handling Pattern
Scripts use:
```bash
set -e  # Exit on error
# Colored output for status
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
# Validate inputs early
# Clean up temp credentials
```

## Cost Considerations

Target audience is cost-conscious:
- Free tier maximization examples
- Billing alerts from day 1
- Documentation on shutting down dev resources
- Monthly cost estimates in README
- Cost optimization guide (BILLING_MANAGEMENT.md)

Default budgets intentionally conservative to prevent surprises.