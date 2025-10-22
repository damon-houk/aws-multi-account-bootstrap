#!/bin/bash

# Complete project setup script
# Usage: ./setup-complete-project.sh [PROJECT_CODE] [EMAIL_PREFIX] [OU_ID] [GITHUB_ORG] [REPO_NAME] [--dry-run]
#
# Configuration precedence:
#   Interactive mode: CLI args > Config file > Prompts
#   CI mode: CLI args > Environment variables > Config file > Error
#
# Options:
#   --dry-run    Preview what would be created without actually creating resources

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source config manager
# shellcheck source=scripts/lib/config-manager.sh
source "$SCRIPT_DIR/lib/config-manager.sh"

# Source cost estimator (with AWS Pricing API support)
# shellcheck source=scripts/lib/cost-estimator.sh
source "$SCRIPT_DIR/lib/cost-estimator.sh" 2>/dev/null || source "$(dirname "$0")/lib/cost-estimator.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║   AWS Multi-Account Project Setup with GitHub CI/CD      ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Detect mode
MODE=$(detect_mode)

# Parse CLI arguments (optional)
CLI_PROJECT_CODE=""
CLI_EMAIL_PREFIX=""
CLI_OU_ID=""
CLI_GITHUB_ORG=""
CLI_REPO_NAME=""
DRY_RUN=false

# Check for --dry-run flag
for arg in "$@"; do
    if [ "$arg" = "--dry-run" ]; then
        DRY_RUN=true
        break
    fi
done

# Parse positional arguments (filter out --dry-run)
POSITIONAL_ARGS=()
for arg in "$@"; do
    if [ "$arg" != "--dry-run" ]; then
        POSITIONAL_ARGS+=("$arg")
    fi
done

# Assign positional arguments
if [ "${#POSITIONAL_ARGS[@]}" -ge 1 ]; then CLI_PROJECT_CODE="${POSITIONAL_ARGS[0]}"; fi
if [ "${#POSITIONAL_ARGS[@]}" -ge 2 ]; then CLI_EMAIL_PREFIX="${POSITIONAL_ARGS[1]}"; fi
if [ "${#POSITIONAL_ARGS[@]}" -ge 3 ]; then CLI_OU_ID="${POSITIONAL_ARGS[2]}"; fi
if [ "${#POSITIONAL_ARGS[@]}" -ge 4 ]; then CLI_GITHUB_ORG="${POSITIONAL_ARGS[3]}"; fi
if [ "${#POSITIONAL_ARGS[@]}" -ge 5 ]; then CLI_REPO_NAME="${POSITIONAL_ARGS[4]}"; fi

# Show dry-run mode banner if enabled
if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║                    DRY RUN MODE ENABLED                  ║${NC}"
    echo -e "${YELLOW}║   No resources will be created. Preview mode only.       ║${NC}"
    echo -e "${YELLOW}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
fi

# Show config file info if in interactive mode
if [ "$MODE" = "interactive" ]; then
    show_config_info
    echo ""
fi

# Load configuration values using mode-based precedence
PROJECT_CODE=$(get_config "PROJECT_CODE" "$CLI_PROJECT_CODE")
EMAIL_PREFIX=$(get_config "EMAIL_PREFIX" "$CLI_EMAIL_PREFIX")
OU_ID=$(get_config "OU_ID" "$CLI_OU_ID")
GITHUB_ORG=$(get_config "GITHUB_ORG" "$CLI_GITHUB_ORG")
REPO_NAME=$(get_config "REPO_NAME" "$CLI_REPO_NAME")

# Handle missing values based on mode
if [ "$MODE" = "ci" ]; then
    # CI mode: Error if any value is missing
    MISSING=()
    [ -z "$PROJECT_CODE" ] && MISSING+=("PROJECT_CODE")
    [ -z "$EMAIL_PREFIX" ] && MISSING+=("EMAIL_PREFIX")
    [ -z "$OU_ID" ] && MISSING+=("OU_ID")
    [ -z "$GITHUB_ORG" ] && MISSING+=("GITHUB_ORG")
    [ -z "$REPO_NAME" ] && MISSING+=("REPO_NAME")

    if [ ${#MISSING[@]} -gt 0 ]; then
        echo -e "${RED}ERROR: Missing required configuration in CI mode${NC}"
        echo ""
        echo "Missing: ${MISSING[*]}"
        echo ""
        echo "Set via:"
        echo "  • CLI arguments: $0 PROJECT_CODE EMAIL_PREFIX OU_ID GITHUB_ORG REPO_NAME"
        echo "  • Environment variables: BOOTSTRAP_PROJECT_CODE, BOOTSTRAP_EMAIL_PREFIX, etc."
        echo "  • Config file: .aws-bootstrap.yml or .aws-bootstrap.json"
        echo ""
        exit 1
    fi
else
    # Interactive mode: Prompt for missing values
    if [ -z "$PROJECT_CODE" ]; then
        echo -e "${BLUE}Project Code${NC}"
        echo "Enter a 3-letter code for your project (e.g., TPA for Therapy Practice App)"
        while true; do
            read -r -p "Project Code (3 uppercase letters): " PROJECT_CODE
            if validate_project_code "$PROJECT_CODE"; then
                break
            else
                echo -e "${RED}Invalid project code. Must be exactly 3 uppercase letters/numbers.${NC}"
            fi
        done
        echo ""
    fi

    if [ -z "$EMAIL_PREFIX" ]; then
        echo -e "${BLUE}Email Address${NC}"
        echo "Enter your Gmail address (we'll use + addressing for account emails)"
        echo "Example: your.email@gmail.com"
        while true; do
            read -r -p "Email: " EMAIL_PREFIX
            if validate_email_prefix "$EMAIL_PREFIX"; then
                break
            else
                echo -e "${RED}Invalid email format.${NC}"
            fi
        done
        echo ""
    fi

    if [ -z "$OU_ID" ]; then
        echo -e "${BLUE}Organization Unit ID${NC}"
        echo "Enter the AWS Organization Unit ID where accounts should be created"
        echo "Format: ou-xxxx-xxxxxxxx"
        echo "Find this in AWS Organizations console"
        while true; do
            read -r -p "OU ID: " OU_ID
            if validate_ou_id "$OU_ID"; then
                break
            else
                echo -e "${RED}Invalid OU ID format. Must be: ou-xxxx-xxxxxxxx${NC}"
            fi
        done
        echo ""
    fi

    if [ -z "$GITHUB_ORG" ]; then
        echo -e "${BLUE}GitHub Organization/Username${NC}"
        read -r -p "GitHub Org: " GITHUB_ORG
        echo ""
    fi

    if [ -z "$REPO_NAME" ]; then
        echo -e "${BLUE}Repository Name${NC}"
        read -r -p "Repo Name: " REPO_NAME
        echo ""
    fi
fi

# Define project output directory
PROJECT_DIR="$SCRIPT_DIR/../output/$PROJECT_CODE"

echo -e "${GREEN}Project Setup Configuration${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Project Code:    $PROJECT_CODE"
echo "  Email Prefix:    $EMAIL_PREFIX"
echo "  OU ID:           $OU_ID"
echo "  GitHub Org:      $GITHUB_ORG"
echo "  Repository:      $REPO_NAME"
echo "  Output Dir:      $PROJECT_DIR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Display cost estimate
display_inline_cost 3
echo ""

# Check prerequisites
# Source the prerequisite checker
# shellcheck source=scripts/lib/prerequisite-checker.sh
if [ -f "$SCRIPT_DIR/lib/prerequisite-checker.sh" ]; then
    # The enhanced prerequisite checker requires bash 4+
    # If we're in bash 3, try to re-exec with bash 5 if available
    if [ "${BASH_VERSINFO[0]}" -lt 4 ] && command -v /opt/homebrew/bin/bash &> /dev/null; then
        echo -e "${BLUE}Note: Re-running prerequisite check with Bash 5 for enhanced UX${NC}"
        echo ""
        /opt/homebrew/bin/bash "$SCRIPT_DIR/lib/prerequisite-checker.sh" || {
            echo ""
            echo -e "${RED}Prerequisite check failed${NC}"
            exit 1
        }
    elif [ "${BASH_VERSINFO[0]}" -ge 4 ]; then
        # We're already in bash 4+, source it directly
        source "$SCRIPT_DIR/lib/prerequisite-checker.sh"
    else
        # Bash 3 and no bash 5 available - show helpful message
        echo -e "${YELLOW}Enhanced prerequisite checker requires Bash 4+${NC}"
        echo "You're running Bash ${BASH_VERSION}"
        echo ""
        echo "For the best experience, install Bash 5:"
        echo "  brew install bash"
        echo ""
        echo "Continuing with basic prerequisite check..."
        echo ""
    fi

    if [ "$MODE" = "ci" ]; then
        # In CI mode, use simple prerequisite checker
        check_prerequisites_simple || {
            echo ""
            echo -e "${RED}Setup cannot continue without required dependencies${NC}"
            exit 1
        }
    else
        # In interactive mode, use the full prerequisite checker
        check_prerequisites || {
            echo ""
            echo -e "${RED}Setup cannot continue without required dependencies${NC}"
            exit 1
        }
    fi
else
    # Fallback if prerequisite-checker.sh not found
    echo -e "${BLUE}Checking prerequisites...${NC}"

    MISSING_COUNT=0

    if ! command -v aws &> /dev/null; then
        echo -e "${RED}✗ AWS CLI not installed${NC}"
        MISSING_COUNT=1
    else
        echo -e "${GREEN}✓ AWS CLI${NC}"
    fi

    if ! command -v cdk &> /dev/null; then
        echo -e "${RED}✗ AWS CDK not installed (npm install -g aws-cdk)${NC}"
        MISSING_COUNT=1
    else
        echo -e "${GREEN}✓ AWS CDK${NC}"
    fi

    if ! command -v jq &> /dev/null; then
        echo -e "${RED}✗ jq not installed${NC}"
        MISSING_COUNT=1
    else
        echo -e "${GREEN}✓ jq${NC}"
    fi

    if ! command -v node &> /dev/null; then
        echo -e "${RED}✗ Node.js not installed${NC}"
        MISSING_COUNT=1
    else
        NODE_VERSION=$(node --version | sed 's/v//')
        NODE_MAJOR=$(echo "$NODE_VERSION" | cut -d. -f1)
        if [ "$NODE_MAJOR" -lt 20 ]; then
            echo -e "${YELLOW}⚠ Node.js ${NODE_VERSION} (requires ≥20.0.0)${NC}"
            MISSING_COUNT=1
        else
            echo -e "${GREEN}✓ Node.js (v${NODE_VERSION})${NC}"
        fi
    fi

    if ! command -v git &> /dev/null; then
        echo -e "${RED}✗ Git not installed${NC}"
        MISSING_COUNT=1
    else
        echo -e "${GREEN}✓ Git${NC}"
    fi

    if ! command -v gh &> /dev/null; then
        echo -e "${RED}✗ GitHub CLI not installed${NC}"
        MISSING_COUNT=1
    else
        echo -e "${GREEN}✓ GitHub CLI${NC}"
    fi

    if [ $MISSING_COUNT -eq 1 ]; then
        echo ""
        echo -e "${RED}Please install missing dependencies before continuing${NC}"
        exit 1
    fi
fi

# Check AWS authentication
echo ""
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}ERROR: Not authenticated with AWS${NC}"
    echo "Please run: aws sso login"
    exit 1
fi

CALLER_IDENTITY=$(aws sts get-caller-identity)
echo -e "${GREEN}✓ Authenticated as: $(echo "$CALLER_IDENTITY" | jq -r '.Arn')${NC}"
echo ""

# Check GitHub authentication
if ! gh auth status &> /dev/null; then
    if [ "$MODE" = "ci" ]; then
        echo -e "${RED}ERROR: Not authenticated with GitHub${NC}"
        echo "Cannot run in CI mode without GitHub authentication."
        echo "Please run: gh auth login"
        exit 1
    else
        echo -e "${YELLOW}Not authenticated with GitHub${NC}"
        echo "Authenticating with GitHub..."
        gh auth login || {
            echo -e "${RED}GitHub authentication failed${NC}"
            exit 1
        }
    fi
fi

GITHUB_USER=$(gh api user -q .login)
echo -e "${GREEN}✓ Authenticated with GitHub as: ${GITHUB_USER}${NC}"
echo ""

if [ "$MODE" = "interactive" ]; then
    read -p "$(echo -e "${YELLOW}Proceed with setup? This will create AWS resources. [y/N]${NC}" )" -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
else
    echo -e "${GREEN}Auto-confirming (CI mode)${NC}"
fi

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}STEP 1/4: Creating AWS Accounts${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY RUN] Would create the following AWS accounts:${NC}"
    echo ""
    echo "  • ${PROJECT_CODE}-dev (${EMAIL_PREFIX}+${PROJECT_CODE}-dev@gmail.com)"
    echo "  • ${PROJECT_CODE}-staging (${EMAIL_PREFIX}+${PROJECT_CODE}-staging@gmail.com)"
    echo "  • ${PROJECT_CODE}-prod (${EMAIL_PREFIX}+${PROJECT_CODE}-prod@gmail.com)"
    echo ""
    echo "  Organization Unit: ${OU_ID}"
    echo "  IAM Role: OrganizationAccountAccessRole"
    echo ""
elif [ -f "$SCRIPT_DIR/create-project-accounts.sh" ]; then
    "$SCRIPT_DIR/create-project-accounts.sh" "$PROJECT_CODE" "$EMAIL_PREFIX" "$OU_ID"
else
    echo -e "${YELLOW}create-project-accounts.sh not found, skipping account creation${NC}"
    echo "Assuming accounts already exist..."
fi

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}STEP 2/4: Bootstrapping CDK${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY RUN] Would bootstrap AWS CDK in the following accounts:${NC}"
    echo ""
    echo "  • ${PROJECT_CODE}-dev account (us-east-1 region)"
    echo "  • ${PROJECT_CODE}-staging account (us-east-1 region)"
    echo "  • ${PROJECT_CODE}-prod account (us-east-1 region)"
    echo ""
    echo "  This creates CloudFormation stack: CDKToolkit"
    echo "  Includes S3 bucket for CDK assets and ECR repository for container images"
    echo ""
else
    # Wait a bit for accounts to be fully ready
    echo "Waiting 30 seconds for accounts to be fully created..."
    sleep 30

    if [ -f "$SCRIPT_DIR/bootstrap-cdk.sh" ]; then
        "$SCRIPT_DIR/bootstrap-cdk.sh" "$PROJECT_CODE"
    else
        echo -e "${YELLOW}bootstrap-cdk.sh not found, skipping CDK bootstrap${NC}"
    fi
fi

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}STEP 3/5: Setting up GitHub Actions CI/CD${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY RUN] Would configure GitHub Actions OIDC authentication:${NC}"
    echo ""
    echo "  AWS IAM OIDC Identity Providers:"
    echo "  • ${PROJECT_CODE}-dev account: token.actions.githubusercontent.com"
    echo "  • ${PROJECT_CODE}-staging account: token.actions.githubusercontent.com"
    echo "  • ${PROJECT_CODE}-prod account: token.actions.githubusercontent.com"
    echo ""
    echo "  IAM Roles for GitHub Actions:"
    echo "  • ${PROJECT_CODE}-dev: GitHubActionsRole"
    echo "  • ${PROJECT_CODE}-staging: GitHubActionsRole"
    echo "  • ${PROJECT_CODE}-prod: GitHubActionsRole"
    echo ""
    echo "  Trust relationship: ${GITHUB_ORG}/${REPO_NAME}"
    echo ""
elif [ -f "$SCRIPT_DIR/setup-github-cicd.sh" ]; then
    "$SCRIPT_DIR/setup-github-cicd.sh" "$PROJECT_CODE" "$GITHUB_ORG" "$REPO_NAME" "$PROJECT_DIR"
else
    echo -e "${YELLOW}setup-github-cicd.sh not found, skipping GitHub setup${NC}"
fi

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}STEP 4/5: Creating Project Structure${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY RUN] Would create project structure in: ${PROJECT_DIR}${NC}"
    echo ""
    echo "  Directory structure:"
    echo "  ├── infrastructure/"
    echo "  │   ├── lib/"
    echo "  │   ├── bin/"
    echo "  │   └── test/"
    echo "  ├── src/"
    echo "  │   ├── frontend/"
    echo "  │   ├── backend/"
    echo "  │   └── shared/"
    echo "  ├── docs/"
    echo "  ├── .github/workflows/"
    echo "  ├── package.json"
    echo "  ├── tsconfig.json"
    echo "  ├── cdk.json"
    echo "  ├── .gitignore"
    echo "  ├── README.md"
    echo "  └── Makefile"
    echo ""
else
    # Create basic project structure
    echo "Creating project directory structure in $PROJECT_DIR..."

    # Create the output directory
    mkdir -p "$PROJECT_DIR"

    # Change to project directory for all file operations
    cd "$PROJECT_DIR"

    mkdir -p infrastructure/{lib,bin,test}
    mkdir -p src/{frontend,backend,shared}
    mkdir -p docs
fi

# Skip file creation in dry-run mode
if [ "$DRY_RUN" != true ]; then
    # Change to project directory for all file operations
    cd "$PROJECT_DIR"

    # Create package.json
    PROJECT_CODE_LOWER=$(echo "$PROJECT_CODE" | tr '[:upper:]' '[:lower:]')
    cat > package.json <<PACKAGE_EOF
{
  "name": "${PROJECT_CODE_LOWER}-app",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "build": "tsc",
    "watch": "tsc -w",
    "test": "jest",
    "cdk": "cdk",
    "lint": "eslint . --ext .ts"
  },
  "devDependencies": {
    "@types/jest": "^29.5.0",
    "@types/node": "^22.0.0",
    "aws-cdk": "^2.220.0",
    "jest": "^29.5.0",
    "ts-jest": "^29.1.0",
    "ts-node": "^10.9.0",
    "typescript": "^5.6.0"
  },
  "dependencies": {
    "aws-cdk-lib": "^2.220.0",
    "constructs": "^10.0.0"
  }
}
PACKAGE_EOF

# Create tsconfig.json
cat > tsconfig.json <<TSCONFIG_EOF
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "lib": ["es2020"],
    "declaration": true,
    "strict": true,
    "noImplicitAny": true,
    "strictNullChecks": true,
    "noImplicitThis": true,
    "alwaysStrict": true,
    "noUnusedLocals": false,
    "noUnusedParameters": false,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": false,
    "inlineSourceMap": true,
    "inlineSources": true,
    "experimentalDecorators": true,
    "strictPropertyInitialization": false,
    "typeRoots": ["./node_modules/@types"],
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true
  },
  "exclude": ["node_modules", "cdk.out"]
}
TSCONFIG_EOF

# Create cdk.json
cat > cdk.json <<CDK_EOF
{
  "app": "npx ts-node --prefer-ts-exts infrastructure/bin/app.ts",
  "watch": {
    "include": [
      "infrastructure/**"
    ],
    "exclude": [
      "README.md",
      "cdk*.json",
      "**/*.d.ts",
      "**/*.js",
      "tsconfig.json",
      "package*.json",
      "yarn.lock",
      "node_modules",
      "test"
    ]
  },
  "context": {
    "@aws-cdk/aws-lambda:recognizeLayerVersion": true,
    "@aws-cdk/core:checkSecretUsage": true,
    "@aws-cdk/core:target-partitions": [
      "aws",
      "aws-cn"
    ],
    "@aws-cdk-containers/ecs-service-extensions:enableDefaultLogDriver": true,
    "@aws-cdk/aws-ec2:uniqueImdsv2TemplateName": true,
    "@aws-cdk/aws-ecs:arnFormatIncludesClusterName": true,
    "@aws-cdk/aws-iam:minimizePolicies": true,
    "@aws-cdk/core:validateSnapshotRemovalPolicy": true,
    "@aws-cdk/aws-codepipeline:crossAccountKeyAliasStackSafeResourceName": true,
    "@aws-cdk/aws-s3:createDefaultLoggingPolicy": true,
    "@aws-cdk/aws-sns-subscriptions:restrictSqsDescryption": true,
    "@aws-cdk/aws-apigateway:disableCloudWatchRole": true,
    "@aws-cdk/core:enablePartitionLiterals": true,
    "@aws-cdk/aws-events:eventsTargetQueueSameAccount": true,
    "@aws-cdk/aws-iam:standardizedServicePrincipals": true,
    "@aws-cdk/aws-ecs:disableExplicitDeploymentControllerForCircuitBreaker": true,
    "@aws-cdk/aws-iam:importedRoleStackSafeDefaultPolicyName": true,
    "@aws-cdk/aws-s3:serverAccessLogsUseBucketPolicy": true,
    "@aws-cdk/aws-route53-patters:useCertificate": true,
    "@aws-cdk/customresources:installLatestAwsSdkDefault": false,
    "@aws-cdk/aws-rds:databaseProxyUniqueResourceName": true,
    "@aws-cdk/aws-codedeploy:removeAlarmsFromDeploymentGroup": true,
    "@aws-cdk/aws-apigateway:authorizerChangeDeploymentLogicalId": true,
    "@aws-cdk/aws-ec2:launchTemplateDefaultUserData": true,
    "@aws-cdk/aws-secretsmanager:useAttachedSecretResourcePolicyForSecretTargetAttachments": true,
    "@aws-cdk/aws-redshift:columnId": true,
    "@aws-cdk/aws-stepfunctions-tasks:enableEmrServicePolicyV2": true,
    "@aws-cdk/aws-ec2:restrictDefaultSecurityGroup": true,
    "@aws-cdk/aws-apigateway:requestValidatorUniqueId": true,
    "@aws-cdk/aws-kms:aliasNameRef": true,
    "@aws-cdk/aws-autoscaling:generateLaunchTemplateInsteadOfLaunchConfig": true,
    "@aws-cdk/core:includePrefixInUniqueNameGeneration": true,
    "@aws-cdk/aws-efs:denyAnonymousAccess": true,
    "@aws-cdk/aws-opensearchservice:enableOpensearchMultiAzWithStandby": true,
    "@aws-cdk/aws-lambda-nodejs:useLatestRuntimeVersion": true,
    "@aws-cdk/aws-efs:mountTargetOrderInsensitiveLogicalId": true,
    "@aws-cdk/aws-rds:auroraClusterChangeScopeOfInstanceParameterGroupWithEachParameters": true,
    "@aws-cdk/aws-appsync:useArnForSourceApiAssociationIdentifier": true,
    "@aws-cdk/aws-rds:preventRenderingDeprecatedCredentials": true,
    "@aws-cdk/aws-codepipeline-actions:useNewDefaultBranchForCodeCommitSource": true,
    "@aws-cdk/aws-cloudwatch-actions:changeLambdaPermissionLogicalIdForLambdaAction": true,
    "@aws-cdk/aws-codepipeline:crossAccountKeysDefaultValueToFalse": true,
    "@aws-cdk/aws-codepipeline:defaultPipelineTypeToV2": true,
    "@aws-cdk/aws-kms:reduceCrossAccountRegionPolicyScope": true,
    "@aws-cdk/aws-eks:nodegroupNameAttribute": true,
    "@aws-cdk/aws-ec2:ebsDefaultGp3Volume": true,
    "@aws-cdk/aws-ecs:removeDefaultDeploymentAlarm": true,
    "@aws-cdk/custom-resources:logApiResponseDataPropertyTrueDefault": false,
    "@aws-cdk/aws-s3:keepNotificationInImportedBucket": false
  },
  "projectCode": "${PROJECT_CODE}",
  "projectName": "${PROJECT_CODE_LOWER}-app"
}
CDK_EOF

# Create .gitignore
cat > .gitignore <<GITIGNORE_EOF
# CDK
*.js
!jest.config.js
*.d.ts
node_modules
cdk.out
.cdk.staging

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db

# Logs
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Environment
.env
.env.local
.env.*.local

# Build
dist/
build/
*.tsbuildinfo

# Testing
coverage/
.nyc_output/

# Misc
.cache/
tmp/
temp/
GITIGNORE_EOF

# Create README
cat > README.md <<README_EOF
# ${PROJECT_CODE} - Therapy Practice Management Application

## Project Structure

\`\`\`
.
├── infrastructure/     # AWS CDK infrastructure code
│   ├── bin/           # CDK app entry point
│   ├── lib/           # CDK stacks and constructs
│   └── test/          # Infrastructure tests
├── src/
│   ├── frontend/      # React/Next.js application
│   ├── backend/       # Lambda functions and APIs
│   └── shared/        # Shared types and utilities
├── .github/
│   └── workflows/     # GitHub Actions CI/CD
└── docs/              # Documentation

\`\`\`

## Prerequisites

- Node.js 20+
- AWS CLI configured
- AWS CDK installed (\`npm install -g aws-cdk\`)

## Getting Started

1. **Install dependencies:**
   \`\`\`bash
   npm install
   \`\`\`

2. **Deploy to dev:**
   \`\`\`bash
   export ENV=dev
   npm run cdk deploy -- --all
   \`\`\`

## Development Workflow

- **Feature branch** → Create PR → Auto-validate
- **Merge to \`develop\`** → Auto-deploy to dev
- **Merge to \`main\`** → Auto-deploy to staging
- **Manual trigger** → Deploy to prod (requires approval)

## Account IDs

See \`CICD_SETUP_SUMMARY.md\` for account details.

## Commands

\`\`\`bash
npm run build          # Compile TypeScript
npm run test           # Run tests
npm run cdk synth      # Synthesize CloudFormation
npm run cdk diff       # Compare deployed stack with current state
npm run cdk deploy     # Deploy stack to AWS
\`\`\`

## Documentation

See \`docs/\` directory for detailed documentation.
README_EOF

# Create a basic CDK app
cat > infrastructure/bin/app.ts <<APP_EOF
#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';

const app = new cdk.App();

const projectCode = app.node.tryGetContext('projectCode') || '${PROJECT_CODE}';
const env = process.env.ENV || 'dev';

// TODO: Import and instantiate your stacks here
// Example:
// import { InfrastructureStack } from '../lib/infrastructure-stack';
// new InfrastructureStack(app, \`\${projectCode}-\${env}-Infrastructure\`, {
//   env: {
//     account: process.env.CDK_DEFAULT_ACCOUNT,
//     region: process.env.CDK_DEFAULT_REGION || 'us-east-1',
//   },
//   tags: {
//     Project: projectCode,
//     Environment: env,
//   },
// });

app.synth();
APP_EOF

# Create a placeholder stack
cat > infrastructure/lib/.gitkeep <<GITKEEP_EOF
# CDK stack files go here
GITKEEP_EOF

echo -e "${GREEN}✓ Project structure created${NC}"
echo ""

# Install dependencies to generate package-lock.json
echo "Installing dependencies..."
npm install --silent
echo -e "${GREEN}✓ Dependencies installed and package-lock.json generated${NC}"
echo ""

# Initialize git if not already initialized
if [ ! -d ".git" ]; then
    echo "Initializing git repository..."
    git init
    git add .
    git commit -m "Initial commit: Project setup complete"
    echo -e "${GREEN}✓ Git repository initialized${NC}"
else
    echo -e "${YELLOW}Git repository already exists${NC}"
fi

fi  # End of file creation block (dry-run check)

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}STEP 5/6: Creating & Configuring GitHub Repository${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY RUN] Would create GitHub repository:${NC}"
    echo ""
    echo "  Repository: ${GITHUB_ORG}/${REPO_NAME}"
    echo "  Visibility: Private"
    echo "  Auto-init: Yes (with README)"
    echo ""
    echo "  Would configure:"
    echo "  • Repository secrets for AWS account IDs"
    echo "  • GitHub Actions workflows for CI/CD"
    echo "  • Branch protection rules"
    echo "  • Push initial commit"
    echo ""
elif [ -f "$SCRIPT_DIR/setup-github-repo.sh" ]; then
    if [ "$MODE" = "ci" ]; then
        "$SCRIPT_DIR/setup-github-repo.sh" "$PROJECT_CODE" "$GITHUB_ORG" "$REPO_NAME" "$PROJECT_DIR" --yes
    else
        "$SCRIPT_DIR/setup-github-repo.sh" "$PROJECT_CODE" "$GITHUB_ORG" "$REPO_NAME" "$PROJECT_DIR"
    fi
else
    echo -e "${YELLOW}setup-github-repo.sh not found, skipping GitHub repo creation${NC}"
    echo "You'll need to create the repository manually and push"
fi

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}STEP 6/6: Setting Up Billing Alerts${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY RUN] Would create billing alerts:${NC}"
    echo ""
    echo "  CloudWatch Alarms in each account:"
    echo "  • ${PROJECT_CODE}-dev: Warning at \$15, Budget \$25"
    echo "  • ${PROJECT_CODE}-staging: Warning at \$15, Budget \$25"
    echo "  • ${PROJECT_CODE}-prod: Warning at \$15, Budget \$25"
    echo ""
    echo "  SNS notifications to: ${EMAIL_PREFIX}@gmail.com"
    echo ""
elif [ -f "$SCRIPT_DIR/setup-billing-alerts.sh" ]; then
    "$SCRIPT_DIR/setup-billing-alerts.sh" "$PROJECT_CODE" "$EMAIL_PREFIX@gmail.com" "$PROJECT_DIR"
else
    echo -e "${YELLOW}setup-billing-alerts.sh not found, skipping billing alerts${NC}"
    echo "You can set these up manually later"
fi

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}✓ Dry Run Complete!${NC}"
else
    echo -e "${GREEN}✓ Setup Complete!${NC}"
fi
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# TODO: Offer to save configuration in interactive mode
# Commented out until we test end-to-end - config manager is ready but needs integration testing
# if [ "$MODE" = "interactive" ]; then
#     declare -A CONFIG_DATA
#     CONFIG_DATA[PROJECT_CODE]="$PROJECT_CODE"
#     CONFIG_DATA[EMAIL_PREFIX]="$EMAIL_PREFIX"
#     CONFIG_DATA[OU_ID]="$OU_ID"
#     CONFIG_DATA[GITHUB_ORG]="$GITHUB_ORG"
#     CONFIG_DATA[REPO_NAME]="$REPO_NAME"
#
#     # Go back to bootstrap root directory for config file
#     cd "$SCRIPT_DIR/.."
#     save_config_prompt CONFIG_DATA
# fi

echo ""
if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}Dry Run Summary - What WOULD be created:${NC}"
    echo "  • 3 AWS accounts (dev, staging, prod)"
    echo "  • CDK bootstrap in all accounts"
    echo "  • GitHub Actions OIDC authentication"
    echo "  • GitHub repository with CI/CD workflows"
    echo "  • Branch protection and environments"
    echo "  • Billing alerts (\$15 warning, \$25 budget)"
    echo "  • Complete project structure with CDK setup"
    echo ""

    # Display cost breakdown for dry-run
    display_dry_run_costs 3

    echo -e "${BLUE}To execute this setup for real:${NC}"
    echo "  Run the same command without --dry-run flag"
else
    echo -e "${BLUE}Summary:${NC}"
    echo "  • 3 AWS accounts created (dev, staging, prod)"
    echo "  • CDK bootstrapped in all accounts"
    echo "  • GitHub Actions CI/CD configured"
    echo "  • GitHub repository created and configured"
    echo "  • Semantic versioning enabled"
    echo "  • Branch protection enabled"
    echo "  • Environments configured (dev, staging, prod)"
    echo "  • Billing alerts configured (\$15 alert, \$25 limit per account)"
    echo "  • Project structure initialized"
    echo "  • Initial release v0.1.0 created"
fi
echo ""
if [ "$DRY_RUN" != true ]; then
    echo -e "${BLUE}Next Steps:${NC}"
    echo ""
    echo "1. ${YELLOW}IMPORTANT: Confirm SNS email subscriptions!${NC}"
    echo "   Check ${EMAIL_PREFIX}@gmail.com for confirmation emails"
    echo ""
    echo "2. Navigate to your project directory:"
    echo "   ${CYAN}cd $PROJECT_DIR${NC}"
    echo ""
    echo "3. Review the setup summaries:"
    echo "   ${CYAN}cat CICD_SETUP_SUMMARY.md${NC}"
    echo "   ${CYAN}cat GITHUB_SETUP_SUMMARY.md${NC}"
    echo "   ${CYAN}cat BILLING_ALERTS_SUMMARY.md${NC}"
    echo ""
    echo "4. Install dependencies:"
    echo "   ${CYAN}npm install${NC}"
    echo ""
    echo "5. Start building your infrastructure:"
    echo "   • Add CDK stacks to infrastructure/lib/"
    echo "   • Use semantic commits: ${CYAN}git commit -m \"feat: Add new feature\"${NC}"
    echo "   • Test locally: ${CYAN}npm run cdk synth${NC}"
    echo "   • Deploy to dev: ${CYAN}ENV=dev npm run cdk deploy${NC}"
fi
echo ""
echo -e "${YELLOW}Important:${NC} Use semantic commit messages:"
echo "  • ${CYAN}feat:${NC} New feature (minor version bump)"
echo "  • ${CYAN}fix:${NC} Bug fix (patch version bump)"
echo "  • ${CYAN}feat!:${NC} Breaking change (major version bump)"
echo ""
echo -e "${YELLOW}Repository:${NC} https://github.com/${GITHUB_ORG}/${REPO_NAME}"
echo ""
echo -e "${BLUE}Project Directory:${NC} $PROJECT_DIR"
echo ""
echo -e "${BLUE}Generated Files Location:${NC}"
echo "  All project files have been created in:"
echo "  ${CYAN}$PROJECT_DIR${NC}"
echo ""

# Display detailed cost breakdown at the end (only for non-dry-run)
if [ "$DRY_RUN" != true ]; then
    display_cost_breakdown 3 true
fi

echo -e "${GREEN}Happy building! 🚀${NC}"
echo ""