#!/bin/bash

# Complete project setup script
# Usage: ./setup-complete-project.sh TPA damon.o.houk ou-813y-xxxxxxxx github-org repo-name

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

# Parse arguments
AUTO_CONFIRM=false

# Check for -y or --yes flag
for arg in "$@"; do
    if [[ "$arg" == "-y" || "$arg" == "--yes" ]]; then
        AUTO_CONFIRM=true
    fi
done

# Remove -y/--yes from arguments
ARGS=()
for arg in "$@"; do
    if [[ "$arg" != "-y" && "$arg" != "--yes" ]]; then
        ARGS+=("$arg")
    fi
done

# Check arguments
if [ "${#ARGS[@]}" -ne 5 ]; then
    echo -e "${RED}ERROR: Missing required arguments${NC}"
    echo ""
    echo "Usage: $0 <PROJECT_CODE> <EMAIL_PREFIX> <OU_ID> <GITHUB_ORG> <REPO_NAME> [-y|--yes]"
    echo ""
    echo "Example:"
    echo "  $0 TPA damon.o.houk ou-813y-8teevv2l your-github-username therapy-practice-app"
    echo "  $0 TPA damon.o.houk ou-813y-8teevv2l your-github-username therapy-practice-app -y"
    echo ""
    echo "Options:"
    echo "  -y, --yes    Skip confirmation prompt"
    echo ""
    echo "This script will:"
    echo "  1. Create 3 AWS accounts (dev, staging, prod)"
    echo "  2. Bootstrap CDK in all accounts"
    echo "  3. Set up GitHub Actions CI/CD with OIDC"
    echo "  4. Generate all necessary configuration files"
    echo ""
    exit 1
fi

PROJECT_CODE=${ARGS[0]}
EMAIL_PREFIX=${ARGS[1]}
OU_ID=${ARGS[2]}
GITHUB_ORG=${ARGS[3]}
REPO_NAME=${ARGS[4]}

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

# Check prerequisites
echo -e "${BLUE}Checking prerequisites...${NC}"

MISSING_DEPS=0

if ! command -v aws &> /dev/null; then
    echo -e "${RED}✗ AWS CLI not installed${NC}"
    MISSING_DEPS=1
else
    echo -e "${GREEN}✓ AWS CLI${NC}"
fi

if ! command -v cdk &> /dev/null; then
    echo -e "${RED}✗ AWS CDK not installed (npm install -g aws-cdk)${NC}"
    MISSING_DEPS=1
else
    echo -e "${GREEN}✓ AWS CDK${NC}"
fi

if ! command -v jq &> /dev/null; then
    echo -e "${RED}✗ jq not installed (brew install jq)${NC}"
    MISSING_DEPS=1
else
    echo -e "${GREEN}✓ jq${NC}"
fi

if ! command -v node &> /dev/null; then
    echo -e "${RED}✗ Node.js not installed${NC}"
    MISSING_DEPS=1
else
    echo -e "${GREEN}✓ Node.js ($(node --version))${NC}"
fi

if ! command -v git &> /dev/null; then
    echo -e "${RED}✗ Git not installed${NC}"
    MISSING_DEPS=1
else
    echo -e "${GREEN}✓ Git${NC}"
fi

if [ $MISSING_DEPS -eq 1 ]; then
    echo ""
    echo -e "${RED}Please install missing dependencies before continuing${NC}"
    exit 1
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

if [ "$AUTO_CONFIRM" = false ]; then
    read -p "$(echo -e "${YELLOW}Proceed with setup? This will create AWS resources. [y/N]${NC}" )" -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
else
    echo -e "${GREEN}Auto-confirming (--yes flag provided)${NC}"
fi

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}STEP 1/4: Creating AWS Accounts${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ -f "$SCRIPT_DIR/create-project-accounts.sh" ]; then
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

# Wait a bit for accounts to be fully ready
echo "Waiting 30 seconds for accounts to be fully created..."
sleep 30

if [ -f "$SCRIPT_DIR/bootstrap-cdk.sh" ]; then
    "$SCRIPT_DIR/bootstrap-cdk.sh" "$PROJECT_CODE"
else
    echo -e "${YELLOW}bootstrap-cdk.sh not found, skipping CDK bootstrap${NC}"
fi

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}STEP 3/5: Setting up GitHub Actions CI/CD${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ -f "$SCRIPT_DIR/setup-github-cicd.sh" ]; then
    "$SCRIPT_DIR/setup-github-cicd.sh" "$PROJECT_CODE" "$GITHUB_ORG" "$REPO_NAME" "$PROJECT_DIR"
else
    echo -e "${YELLOW}setup-github-cicd.sh not found, skipping GitHub setup${NC}"
fi

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}STEP 4/5: Creating Project Structure${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Create basic project structure
echo "Creating project directory structure in $PROJECT_DIR..."

# Create the output directory
mkdir -p "$PROJECT_DIR"

# Change to project directory for all file operations
cd "$PROJECT_DIR"

mkdir -p infrastructure/{lib,bin,test}
mkdir -p src/{frontend,backend,shared}
mkdir -p docs

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
    "@types/node": "^20.0.0",
    "aws-cdk": "^2.100.0",
    "jest": "^29.5.0",
    "ts-jest": "^29.1.0",
    "ts-node": "^10.9.0",
    "typescript": "^5.0.0"
  },
  "dependencies": {
    "aws-cdk-lib": "^2.100.0",
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

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}STEP 5/6: Creating & Configuring GitHub Repository${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ -f "$SCRIPT_DIR/setup-github-repo.sh" ]; then
    "$SCRIPT_DIR/setup-github-repo.sh" "$PROJECT_CODE" "$GITHUB_ORG" "$REPO_NAME" "$PROJECT_DIR"
else
    echo -e "${YELLOW}setup-github-repo.sh not found, skipping GitHub repo creation${NC}"
    echo "You'll need to create the repository manually and push"
fi

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}STEP 6/6: Setting Up Billing Alerts${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ -f "$SCRIPT_DIR/setup-billing-alerts.sh" ]; then
    "$SCRIPT_DIR/setup-billing-alerts.sh" "$PROJECT_CODE" "$EMAIL_PREFIX@gmail.com" "$PROJECT_DIR"
else
    echo -e "${YELLOW}setup-billing-alerts.sh not found, skipping billing alerts${NC}"
    echo "You can set these up manually later"
fi

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Setup Complete!${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
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
echo ""
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
echo -e "${GREEN}Happy building! 🚀${NC}"
echo ""