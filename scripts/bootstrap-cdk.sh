#!/bin/bash

# Script to bootstrap AWS CDK in project accounts
# Usage: ./bootstrap-cdk.sh TPA

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check arguments
if [ "$#" -ne 1 ]; then
    echo -e "${RED}ERROR: Missing required arguments${NC}"
    echo ""
    echo "Usage: $0 <PROJECT_CODE>"
    echo ""
    echo "Example:"
    echo "  $0 TPA"
    echo ""
    echo "Arguments:"
    echo "  PROJECT_CODE  - 3-letter project identifier (e.g., TPA)"
    echo ""
    echo "Note: Reads account IDs from .aws-bootstrap/account-ids.json"
    echo "      (created by create-project-accounts.sh)"
    echo ""
    exit 1
fi

PROJECT_CODE=$1

# Validate PROJECT_CODE length
if [ ${#PROJECT_CODE} -ne 3 ]; then
    echo -e "${RED}ERROR: PROJECT_CODE must be exactly 3 characters${NC}"
    exit 1
fi

echo -e "${GREEN}Bootstrapping CDK for project: ${PROJECT_CODE}${NC}"
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}ERROR: AWS CLI is not installed${NC}"
    exit 1
fi

# Check if logged into AWS
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}ERROR: Not authenticated with AWS${NC}"
    echo "Please run: aws sso login"
    exit 1
fi

# Read account IDs from JSON file created by create-project-accounts.sh
if [ ! -f ".aws-bootstrap/account-ids.json" ]; then
    echo -e "${RED}ERROR: Account IDs file not found${NC}"
    echo "Please run create-project-accounts.sh first"
    exit 1
fi

DEV_ACCOUNT_ID=$(jq -r '.devAccountId' .aws-bootstrap/account-ids.json)
STAGING_ACCOUNT_ID=$(jq -r '.stagingAccountId' .aws-bootstrap/account-ids.json)
PROD_ACCOUNT_ID=$(jq -r '.prodAccountId' .aws-bootstrap/account-ids.json)

echo "Account IDs:"
echo "  Dev:     $DEV_ACCOUNT_ID"
echo "  Staging: $STAGING_ACCOUNT_ID"
echo "  Prod:    $PROD_ACCOUNT_ID"
echo ""

# Get management account ID for trust relationships
MGMT_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Management Account: $MGMT_ACCOUNT_ID"
echo ""

echo -e "${YELLOW}Bootstrapping CDK in all accounts...${NC}"
echo ""

# Bootstrap each account
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

    echo -e "${BLUE}Bootstrapping ${ENV} account (${ACCOUNT_ID})...${NC}"

    # Assume role into the target account
    ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/OrganizationAccountAccessRole"

    CREDENTIALS=$(aws sts assume-role \
        --role-arn "${ROLE_ARN}" \
        --role-session-name "cdk-bootstrap-${ENV}" \
        --output json)

    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Failed to assume role in ${ENV} account${NC}"
        exit 1
    fi

    # Export temporary credentials
    AWS_ACCESS_KEY_ID=$(echo "$CREDENTIALS" | jq -r '.Credentials.AccessKeyId')
    AWS_SECRET_ACCESS_KEY=$(echo "$CREDENTIALS" | jq -r '.Credentials.SecretAccessKey')
    AWS_SESSION_TOKEN=$(echo "$CREDENTIALS" | jq -r '.Credentials.SessionToken')
    export AWS_ACCESS_KEY_ID
    export AWS_SECRET_ACCESS_KEY
    export AWS_SESSION_TOKEN

    # Bootstrap CDK with trust to management account for cross-account deployments
    if cdk bootstrap aws://${ACCOUNT_ID}/us-east-1 \
        --cloudformation-execution-policies arn:aws:iam::aws:policy/AdministratorAccess \
        --trust ${MGMT_ACCOUNT_ID} \
        --trust-for-lookup ${MGMT_ACCOUNT_ID}; then
        echo -e "${GREEN}✓ ${ENV} account bootstrapped${NC}"
    else
        echo -e "${RED}✗ Failed to bootstrap ${ENV} account${NC}"
        unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
        exit 1
    fi

    # Clean up temporary credentials
    unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
    echo ""
done

echo -e "${GREEN}✓ All accounts bootstrapped successfully!${NC}"
echo ""
echo "Next steps:"
echo "1. Set up GitHub Actions CI/CD"
echo "2. Configure billing alerts"
echo ""