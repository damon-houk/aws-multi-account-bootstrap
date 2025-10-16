#!/bin/bash

# Script to create project accounts in AWS Organization
# Usage: ./create-project-accounts.sh TPA damon.o.houk ou-813y-xxxxxxxx

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
    echo "Usage: $0 <PROJECT_CODE> <EMAIL_PREFIX> <OU_ID>"
    echo ""
    echo "Example:"
    echo "  $0 TPA damon.o.houk ou-813y-8teevv2l"
    echo ""
    echo "Arguments:"
    echo "  PROJECT_CODE  - 3-letter project identifier (e.g., TPA)"
    echo "  EMAIL_PREFIX  - Email without @gmail.com (e.g., damon.o.houk)"
    echo "  OU_ID         - Organizational Unit ID (e.g., ou-813y-xxxxxxxx)"
    echo ""
    exit 1
fi

PROJECT_CODE=$1
EMAIL_PREFIX=$2
OU_ID=$3

# Validate PROJECT_CODE length
if [ ${#PROJECT_CODE} -ne 3 ]; then
    echo -e "${RED}ERROR: PROJECT_CODE must be exactly 3 characters${NC}"
    exit 1
fi

# Validate OU_ID format
if [[ ! $OU_ID =~ ^ou- ]]; then
    echo -e "${RED}ERROR: OU_ID must start with 'ou-'${NC}"
    exit 1
fi

echo -e "${GREEN}Creating AWS accounts for project: ${PROJECT_CODE}${NC}"
echo ""
echo "Configuration:"
echo "  Project Code: $PROJECT_CODE"
echo "  Email Prefix: $EMAIL_PREFIX"
echo "  OU ID:        $OU_ID"
echo ""
PROJECT_CODE_LOWER=$(echo "$PROJECT_CODE" | tr '[:upper:]' '[:lower:]')
echo "Will create:"
echo "  ${PROJECT_CODE}_DEV     -> ${EMAIL_PREFIX}+${PROJECT_CODE_LOWER}-dev@gmail.com"
echo "  ${PROJECT_CODE}_STAGING -> ${EMAIL_PREFIX}+${PROJECT_CODE_LOWER}-staging@gmail.com"
echo "  ${PROJECT_CODE}_PROD    -> ${EMAIL_PREFIX}+${PROJECT_CODE_LOWER}-prod@gmail.com"
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

echo -e "${YELLOW}Creating AWS Organization accounts...${NC}"
echo ""

# Get root ID for moving accounts later
ROOT_ID=$(aws organizations list-roots --query 'Roots[0].Id' --output text)

# Arrays to store account info
declare -a ACCOUNT_IDS
declare -a REQUEST_IDS

# Create accounts for each environment
for ENV in dev staging prod; do
    ENV_UPPER=$(echo "$ENV" | tr '[:lower:]' '[:upper:]')
    ACCOUNT_NAME="${PROJECT_CODE}_${ENV_UPPER}"
    EMAIL="${EMAIL_PREFIX}+${PROJECT_CODE_LOWER}-${ENV}@gmail.com"

    echo -e "${BLUE}Creating ${ENV} account: ${ACCOUNT_NAME}${NC}"
    echo "  Email: ${EMAIL}"

    # Check if account already exists
    EXISTING_ACCOUNT=$(aws organizations list-accounts \
        --query "Accounts[?Name=='${ACCOUNT_NAME}'].Id" \
        --output text 2>/dev/null || echo "")

    if [ -n "$EXISTING_ACCOUNT" ]; then
        echo -e "${YELLOW}  Account already exists: ${EXISTING_ACCOUNT}${NC}"
        ACCOUNT_IDS+=("${EXISTING_ACCOUNT}")
        continue
    fi

    # Create the account
    CREATE_OUTPUT=$(aws organizations create-account \
        --email "${EMAIL}" \
        --account-name "${ACCOUNT_NAME}" \
        --role-name "OrganizationAccountAccessRole" \
        --output json)

    REQUEST_ID=$(echo "$CREATE_OUTPUT" | jq -r '.CreateAccountStatus.Id')
    REQUEST_IDS+=("${REQUEST_ID}")

    echo "  Request ID: ${REQUEST_ID}"
done

echo ""
echo -e "${YELLOW}Waiting for account creation to complete...${NC}"
echo "This may take 1-2 minutes per account..."
echo ""

# Wait for each account creation to complete
for i in "${!REQUEST_IDS[@]}"; do
    REQUEST_ID="${REQUEST_IDS[$i]}"

    while true; do
        STATUS_OUTPUT=$(aws organizations describe-create-account-status \
            --create-account-request-id "${REQUEST_ID}" \
            --output json)

        STATE=$(echo "$STATUS_OUTPUT" | jq -r '.CreateAccountStatus.State')

        if [ "$STATE" = "SUCCEEDED" ]; then
            ACCOUNT_ID=$(echo "$STATUS_OUTPUT" | jq -r '.CreateAccountStatus.AccountId')
            ACCOUNT_NAME=$(echo "$STATUS_OUTPUT" | jq -r '.CreateAccountStatus.AccountName')
            ACCOUNT_IDS+=("${ACCOUNT_ID}")
            echo -e "${GREEN}✓ ${ACCOUNT_NAME}: ${ACCOUNT_ID}${NC}"
            break
        elif [ "$STATE" = "FAILED" ]; then
            FAILURE_REASON=$(echo "$STATUS_OUTPUT" | jq -r '.CreateAccountStatus.FailureReason')
            echo -e "${RED}✗ Account creation failed: ${FAILURE_REASON}${NC}"
            exit 1
        else
            echo "  Waiting for ${REQUEST_ID}... (${STATE})"
            sleep 10
        fi
    done
done

echo ""
echo -e "${YELLOW}Moving accounts to OU: ${OU_ID}${NC}"

# Move each account to the target OU
for ACCOUNT_ID in "${ACCOUNT_IDS[@]}"; do
    # Get current parent (should be root)
    CURRENT_PARENT=$(aws organizations list-parents \
        --child-id "${ACCOUNT_ID}" \
        --query 'Parents[0].Id' \
        --output text)

    # Only move if not already in target OU
    if [ "$CURRENT_PARENT" != "$OU_ID" ]; then
        aws organizations move-account \
            --account-id "${ACCOUNT_ID}" \
            --source-parent-id "${CURRENT_PARENT}" \
            --destination-parent-id "${OU_ID}" 2>/dev/null || echo "  (Already in target OU)"
        echo "  Moved ${ACCOUNT_ID} to ${OU_ID}"
    else
        echo "  ${ACCOUNT_ID} already in ${OU_ID}"
    fi
done

echo ""
echo -e "${GREEN}✓ All accounts created successfully!${NC}"
echo ""
echo "Account IDs:"
echo "  DEV:     ${ACCOUNT_IDS[0]}"
echo "  STAGING: ${ACCOUNT_IDS[1]}"
echo "  PROD:    ${ACCOUNT_IDS[2]}"
echo ""
echo "Next steps:"
echo "1. Check your email (${EMAIL_PREFIX}@gmail.com) for verification emails"
echo "2. Wait 30-60 seconds for accounts to be fully ready"
echo "3. Continue with CDK bootstrap"
echo ""

# Store account IDs for subsequent scripts
mkdir -p .aws-bootstrap
cat > .aws-bootstrap/account-ids.json <<EOF
{
  "projectCode": "${PROJECT_CODE}",
  "devAccountId": "${ACCOUNT_IDS[0]}",
  "stagingAccountId": "${ACCOUNT_IDS[1]}",
  "prodAccountId": "${ACCOUNT_IDS[2]}",
  "ouId": "${OU_ID}"
}
EOF

echo "Account IDs saved to: .aws-bootstrap/account-ids.json"
echo ""