#!/bin/bash

# Script to create project accounts in AWS Organization
# Usage: ./create-project-accounts.sh TPA damon.o.houk ou-813y-xxxxxxxx

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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
echo "Will create:"
echo "  ${PROJECT_CODE}_DEV     -> ${EMAIL_PREFIX}+${PROJECT_CODE,,}-dev@gmail.com"
echo "  ${PROJECT_CODE}_STAGING -> ${EMAIL_PREFIX}+${PROJECT_CODE,,}-staging@gmail.com"
echo "  ${PROJECT_CODE}_PROD    -> ${EMAIL_PREFIX}+${PROJECT_CODE,,}-prod@gmail.com"
echo ""

read -p "Continue? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

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

echo -e "${YELLOW}Deploying CDK stack...${NC}"

# Export variables for CDK
export PROJECT_CODE=$PROJECT_CODE
export PROJECT_EMAIL=$EMAIL_PREFIX
export OU_ID=$OU_ID

# Deploy CDK stack
if cdk deploy --require-approval never; then
    echo ""
    echo -e "${GREEN}✓ Accounts created successfully!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Check your email (${EMAIL_PREFIX}@gmail.com) for verification emails"
    echo "2. Set up IAM Identity Center if not already configured"
    echo "3. Add the output CLI profiles to your ~/.aws/config"
    echo ""
    echo "View accounts:"
    echo "  aws organizations list-accounts"
    echo ""
else
    echo -e "${RED}✗ CDK deployment failed${NC}"
    exit 1
fi