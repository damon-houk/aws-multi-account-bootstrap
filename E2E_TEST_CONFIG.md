# E2E Test Configuration

This document contains the configuration details for running end-to-end tests of the AWS Multi-Account Bootstrap tool.

## AWS Organization Details

**Organization ID:** `o-oaupr6vsrx`
**Root ID:** `r-813y`
**Management Account ID:** `781727996085`

## Test Configuration

**Test Email (for new accounts):** `damon.o.houk@gmail.com`

## Organizational Units

**Test OU:** MAB (Multi-Account Bootstrap)
- **OU ID:** `ou-813y-yastq6et`
- **ARN:** `arn:aws:organizations::781727996085:ou/o-oaupr6vsrx/ou-813y-yastq6et`
- **Purpose:** Contains all multi-account bootstrap test accounts

### Other OUs (for reference):
- **WEX TAG**
  - OU ID: `ou-813y-8teevv2l`
  - ARN: `arn:aws:organizations::781727996085:ou/o-oaupr6vsrx/ou-813y-8teevv2l`

## Test Parameters

### E2E Test Accounts (Created 2025-10-16)

**Project Code:** E2E

**AWS Accounts:**
- **Dev:** 485209127530 (E2E_DEV)
- **Staging:** 378842099831 (E2E_STAGING)
- **Prod:** 811572529491 (E2E_PROD)

**Email Addresses:**
- Dev: `damon.o.houk+e2e-dev@gmail.com`
- Staging: `damon.o.houk+e2e-staging@gmail.com`
- Prod: `damon.o.houk+e2e-prod@gmail.com`

All emails delivered to: `damon.o.houk@gmail.com`

**GitHub Configuration:**
- GitHub Org: `damon-houk`
- Repository: `test-aws-bootstrap-e2e`

**IAM Resources Created:**
- OIDC Providers: `arn:aws:iam::{ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com`
- IAM Roles: `arn:aws:iam::{ACCOUNT_ID}:role/GitHubActionsDeployRole`

### Quick Test Command

```bash
cd /Users/damon/IdeaProjects/aws-multi-account-bootstrap

# Full setup with existing accounts (idempotent)
./scripts/setup-complete-project.sh E2E damon.o.houk ou-813y-yastq6et damon-houk test-aws-bootstrap-e2e -y
```

### Alternative Test (if E2E accounts need to be preserved)

```bash
PROJECT_CODE=TST
EMAIL_PREFIX=damon.o.houk
OU_ID=ou-813y-yastq6et
GITHUB_ORG=damon-houk
REPO_NAME=test-aws-bootstrap-tst

./scripts/setup-complete-project.sh TST damon.o.houk ou-813y-yastq6et damon-houk test-aws-bootstrap-tst -y
```

## Cleanup Commands

### Remove E2E Test Accounts (when no longer needed)

```bash
# List accounts
aws organizations list-accounts | jq -r '.Accounts[] | select(.Name | contains("E2E"))'

# Close accounts (requires removing all resources first)
aws organizations close-account --account-id 485209127530  # E2E_DEV
aws organizations close-account --account-id 378842099831  # E2E_STAGING
aws organizations close-account --account-id 811572529491  # E2E_PROD
```

### Remove IAM Resources from Test Accounts

```bash
# For each account, assume role and delete resources
ACCOUNT_ID=485209127530  # Change for each account

CREDENTIALS=$(aws sts assume-role \
  --role-arn "arn:aws:iam::${ACCOUNT_ID}:role/OrganizationAccountAccessRole" \
  --role-session-name "cleanup" \
  --output json)

export AWS_ACCESS_KEY_ID=$(echo "$CREDENTIALS" | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDENTIALS" | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo "$CREDENTIALS" | jq -r '.Credentials.SessionToken')

# Delete IAM role
aws iam detach-role-policy --role-name GitHubActionsDeployRole \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
aws iam delete-role --role-name GitHubActionsDeployRole

# Delete OIDC provider
OIDC_ARN=$(aws iam list-open-id-connect-providers --query 'OpenIDConnectProviderList[0].Arn' --output text)
aws iam delete-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_ARN"

# Delete CDK bootstrap resources
aws cloudformation delete-stack --stack-name CDKToolkit
aws cloudformation wait stack-delete-complete --stack-name CDKToolkit

unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
```

## Notes

- Test accounts incur minimal costs (CDK bootstrap S3/ECR, CloudWatch alarms)
- AWS accounts require 90 days before permanent deletion after being closed
- Keep E2E accounts for regression testing
- Create separate TST accounts for destructive testing
- All test resources should be tagged with `Project: E2E-Test` or `Project: TST-Test`

## Last Updated

**Created:** 2025-10-16
**Last E2E Test:** 2025-10-16 (v1.2.0)
**Test Status:** ✅ Passed (Steps 1-4 of 6)
**Test Report:** See `E2E_TEST_RESULTS.md`
