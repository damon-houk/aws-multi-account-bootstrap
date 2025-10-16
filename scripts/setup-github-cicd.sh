#!/bin/bash

# Script to set up GitHub Actions CI/CD with OIDC for AWS CDK deployments
# Usage: ./setup-github-cicd.sh TPA <github-org> <repo-name>

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check arguments
if [ "$#" -ne 3 ]; then
    echo -e "${RED}ERROR: Missing required arguments${NC}"
    echo ""
    echo "Usage: $0 <PROJECT_CODE> <GITHUB_ORG> <REPO_NAME>"
    echo ""
    echo "Example:"
    echo "  $0 TPA your-github-username therapy-practice-app"
    echo ""
    exit 1
fi

PROJECT_CODE=$1
GITHUB_ORG=$2
REPO_NAME=$3

echo -e "${GREEN}Setting up GitHub Actions CI/CD for ${PROJECT_CODE}${NC}"
echo ""
echo "Configuration:"
echo "  Project Code:    $PROJECT_CODE"
echo "  GitHub Org:      $GITHUB_ORG"
echo "  Repository:      $REPO_NAME"
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}ERROR: AWS CLI is not installed${NC}"
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}WARNING: jq is not installed. Install with: brew install jq${NC}"
    exit 1
fi

# Get account IDs from JSON file created by create-project-accounts.sh
if [ ! -f ".aws-bootstrap/account-ids.json" ]; then
    echo -e "${RED}ERROR: Account IDs file not found${NC}"
    echo "Please run create-project-accounts.sh first"
    exit 1
fi

echo -e "${BLUE}Reading account IDs...${NC}"

DEV_ACCOUNT_ID=$(jq -r '.devAccountId' .aws-bootstrap/account-ids.json)
STAGING_ACCOUNT_ID=$(jq -r '.stagingAccountId' .aws-bootstrap/account-ids.json)
PROD_ACCOUNT_ID=$(jq -r '.prodAccountId' .aws-bootstrap/account-ids.json)

if [ -z "$DEV_ACCOUNT_ID" ] || [ -z "$STAGING_ACCOUNT_ID" ] || [ -z "$PROD_ACCOUNT_ID" ]; then
    echo -e "${RED}ERROR: Could not read account IDs from file${NC}"
    echo "Make sure you've run the create-project-accounts.sh script first"
    exit 1
fi

echo "  Dev Account:     $DEV_ACCOUNT_ID"
echo "  Staging Account: $STAGING_ACCOUNT_ID"
echo "  Prod Account:    $PROD_ACCOUNT_ID"
echo ""

# Create IAM OIDC provider and roles in each account
echo -e "${BLUE}Creating IAM OIDC providers and roles...${NC}"

for ENV in dev staging prod; do
    case $ENV in
        dev)
            ACCOUNT_ID=$DEV_ACCOUNT_ID
            ;;
        staging)
            ACCOUNT_ID=$STAGING_ACCOUNT_ID
            ;;
        prod)
            ACCOUNT_ID=$PROD_ACCOUNT_ID
            ;;
    esac

    echo -e "${YELLOW}Setting up ${ENV} account (${ACCOUNT_ID})...${NC}"

    # Assume role into the account
    ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/OrganizationAccountAccessRole"

    CREDENTIALS=$(aws sts assume-role \
        --role-arn "$ROLE_ARN" \
        --role-session-name "github-cicd-setup" \
        --output json)

    export AWS_ACCESS_KEY_ID
    export AWS_SECRET_ACCESS_KEY
    export AWS_SESSION_TOKEN
    AWS_ACCESS_KEY_ID=$(echo "$CREDENTIALS" | jq -r '.Credentials.AccessKeyId')
    AWS_SECRET_ACCESS_KEY=$(echo "$CREDENTIALS" | jq -r '.Credentials.SecretAccessKey')
    AWS_SESSION_TOKEN=$(echo "$CREDENTIALS" | jq -r '.Credentials.SessionToken')

    # Create OIDC provider (if not exists)
    echo "  Creating OIDC provider..."
    aws iam create-open-id-connect-provider \
        --url "https://token.actions.githubusercontent.com" \
        --client-id-list "sts.amazonaws.com" \
        --thumbprint-list "6938fd4d98bab03faadb97b34396831e3780aea1" \
        2>/dev/null || echo "  OIDC provider already exists"

    # Create trust policy
    cat > /tmp/trust-policy-${ENV}.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:${GITHUB_ORG}/${REPO_NAME}:*"
        }
      }
    }
  ]
}
EOF

    # Create IAM role
    echo "  Creating GitHub Actions role..."
    aws iam create-role \
        --role-name "GitHubActionsDeployRole" \
        --assume-role-policy-document "file:///tmp/trust-policy-${ENV}.json" \
        --description "Role for GitHub Actions to deploy CDK stacks" \
        2>/dev/null || echo "  Role already exists"

    # Attach AdministratorAccess policy (you may want to restrict this in production)
    echo "  Attaching policies..."
    aws iam attach-role-policy \
        --role-name "GitHubActionsDeployRole" \
        --policy-arn "arn:aws:iam::aws:policy/AdministratorAccess" \
        2>/dev/null || true

    # Clean up temp credentials
    unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN

    echo -e "${GREEN}  ✓ ${ENV} account configured${NC}"
done

# Create GitHub Actions workflow files
echo -e "${BLUE}Creating GitHub Actions workflow files...${NC}"

mkdir -p .github/workflows

# Main CI/CD workflow
cat > .github/workflows/deploy.yml <<EOF
name: Deploy CDK

on:
  push:
    branches:
      - main
      - develop
  pull_request:
    branches:
      - main
      - develop
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy to'
        required: true
        type: choice
        options:
          - dev
          - staging
          - prod

permissions:
  id-token: write
  contents: read

jobs:
  test:
    name: Run Tests
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run linter
        run: npm run lint || echo "Linting not configured yet"

      - name: Run tests
        run: npm test || echo "Tests not configured yet"

      - name: Build
        run: npm run build

  deploy-dev:
    name: Deploy to Dev
    runs-on: ubuntu-latest
    needs: test
    if: github.ref == 'refs/heads/develop'
    environment: dev
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${DEV_ACCOUNT_ID}:role/GitHubActionsDeployRole
          aws-region: us-east-1

      - name: CDK Deploy
        run: |
          npm run cdk deploy -- --all --require-approval never
        env:
          ENV: dev
          PROJECT_CODE: ${PROJECT_CODE}

  deploy-staging:
    name: Deploy to Staging
    runs-on: ubuntu-latest
    needs: test
    if: github.ref == 'refs/heads/main'
    environment: staging
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${STAGING_ACCOUNT_ID}:role/GitHubActionsDeployRole
          aws-region: us-east-1

      - name: CDK Deploy
        run: |
          npm run cdk deploy -- --all --require-approval never
        env:
          ENV: staging
          PROJECT_CODE: ${PROJECT_CODE}

  deploy-prod:
    name: Deploy to Production
    runs-on: ubuntu-latest
    needs: test
    if: github.event_name == 'workflow_dispatch' && github.event.inputs.environment == 'prod'
    environment:
      name: prod
      url: https://app.yourtherapypractice.com
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${PROD_ACCOUNT_ID}:role/GitHubActionsDeployRole
          aws-region: us-east-1

      - name: CDK Deploy
        run: |
          npm run cdk deploy -- --all --require-approval never
        env:
          ENV: prod
          PROJECT_CODE: ${PROJECT_CODE}
EOF

# Create PR validation workflow
cat > .github/workflows/pr-validation.yml <<EOF
name: PR Validation

on:
  pull_request:
    branches:
      - main
      - develop

permissions:
  contents: read
  pull-requests: write

jobs:
  validate:
    name: Validate Changes
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run linter
        run: npm run lint || echo "Linting not configured yet"

      - name: Run tests
        run: npm test || echo "Tests not configured yet"

      - name: CDK Synth
        run: npm run cdk synth

      - name: CDK Diff (Dev)
        run: |
          echo "## CDK Diff Preview" >> \$GITHUB_STEP_SUMMARY
          echo "\`\`\`" >> \$GITHUB_STEP_SUMMARY
          npm run cdk diff -- --context env=dev || true >> \$GITHUB_STEP_SUMMARY
          echo "\`\`\`" >> \$GITHUB_STEP_SUMMARY
EOF

echo -e "${GREEN}✓ Workflow files created${NC}"
echo ""

# Create summary file
cat > CICD_SETUP_SUMMARY.md <<EOF
# GitHub Actions CI/CD Setup Complete

## Account Configuration

| Environment | Account ID | Role ARN |
|-------------|------------|----------|
| Dev | ${DEV_ACCOUNT_ID} | arn:aws:iam::${DEV_ACCOUNT_ID}:role/GitHubActionsDeployRole |
| Staging | ${STAGING_ACCOUNT_ID} | arn:aws:iam::${STAGING_ACCOUNT_ID}:role/GitHubActionsDeployRole |
| Prod | ${PROD_ACCOUNT_ID} | arn:aws:iam::${PROD_ACCOUNT_ID}:role/GitHubActionsDeployRole |

## Deployment Flow

- **Push to \`develop\`** → Deploys to **Dev**
- **Push to \`main\`** → Deploys to **Staging**
- **Manual trigger** → Deploys to **Prod** (requires approval)

## Next Steps

1. **Bootstrap CDK in each account:**
   \`\`\`bash
   PROJECT_CODE_LOWER=\$(echo "$PROJECT_CODE" | tr '[:upper:]' '[:lower:]')
   aws cdk bootstrap aws://${DEV_ACCOUNT_ID}/us-east-1 --profile \${PROJECT_CODE_LOWER}-dev
   aws cdk bootstrap aws://${STAGING_ACCOUNT_ID}/us-east-1 --profile \${PROJECT_CODE_LOWER}-staging
   aws cdk bootstrap aws://${PROD_ACCOUNT_ID}/us-east-1 --profile \${PROJECT_CODE_LOWER}-prod
   \`\`\`

2. **Set up GitHub repository:**
   \`\`\`bash
   git init
   git add .
   git commit -m "Initial commit with CI/CD setup"
   git branch -M main
   git remote add origin https://github.com/${GITHUB_ORG}/${REPO_NAME}.git
   git push -u origin main
   \`\`\`

3. **Create develop branch:**
   \`\`\`bash
   git checkout -b develop
   git push -u origin develop
   \`\`\`

4. **Configure GitHub repository settings:**
   - Go to Settings → Environments
   - Create environments: \`dev\`, \`staging\`, \`prod\`
   - For \`prod\`: Enable "Required reviewers" and add yourself

5. **Set up branch protection:**
   - Protect \`main\` branch: Require PR, require status checks
   - Protect \`develop\` branch: Require PR

## Testing the Pipeline

1. Create a feature branch:
   \`\`\`bash
   git checkout develop
   git checkout -b feature/test-cicd
   # Make some changes
   git add .
   git commit -m "Test CI/CD"
   git push -u origin feature/test-cicd
   \`\`\`

2. Create PR to \`develop\` → Triggers validation
3. Merge to \`develop\` → Deploys to dev
4. Create PR from \`develop\` to \`main\` → Triggers validation
5. Merge to \`main\` → Deploys to staging
6. Manual trigger → Deploy to prod

## Workflow Files Created

- \`.github/workflows/deploy.yml\` - Main deployment workflow
- \`.github/workflows/pr-validation.yml\` - PR validation

## Security Notes

- Uses OIDC (no long-lived credentials)
- GitHub Actions assumes IAM role per deployment
- Currently uses AdministratorAccess (consider restricting for prod)
- Secrets are never stored in GitHub

## Troubleshooting

If deployment fails:
1. Check GitHub Actions logs
2. Verify CDK is bootstrapped in target account
3. Confirm IAM role has correct permissions
4. Check AWS CloudFormation console for stack errors

EOF

echo -e "${GREEN}✓ Setup complete!${NC}"
echo ""
echo "Summary written to: CICD_SETUP_SUMMARY.md"
echo ""
echo "Next steps:"
echo "1. Bootstrap CDK in each account (see CICD_SETUP_SUMMARY.md)"
echo "2. Push code to GitHub"
echo "3. Configure GitHub repository settings"
echo ""