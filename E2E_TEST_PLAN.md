# End-to-End Test Plan for AWS Multi-Account Bootstrap

## 🎯 Objective
Validate that the MVP (v1.0) works completely end-to-end before building v1.1 features.

## 📋 Test Checklist

### Phase 1: Prerequisites Verification
- [ ] AWS CLI installed and configured
- [ ] AWS CDK installed (`npm install -g aws-cdk`)
- [ ] GitHub CLI (gh) installed and authenticated
- [ ] Node.js 20+ installed
- [ ] jq installed
- [ ] Git installed
- [ ] AWS SSO login completed (`aws sso login`)
- [ ] GitHub CLI authenticated (`gh auth login`)
- [ ] AWS Organizations enabled in management account

### Phase 2: Prepare Test Environment
- [ ] Create a test Organizational Unit (OU) in AWS Console
  - Go to AWS Console → Organizations
  - Create OU (suggested name: "Test-Bootstrap-E2E")
  - Copy the OU ID (format: `ou-xxxx-xxxxxxxx`)
- [ ] Choose test project parameters:
  - PROJECT_CODE: 3-letter code (suggestion: `TST` or `E2E`)
  - EMAIL_PREFIX: Your email prefix for Gmail (e.g., `your.name`)
  - GITHUB_ORG: Your GitHub username
  - REPO_NAME: Test repository name (suggestion: `test-aws-bootstrap`)

### Phase 3: Run Complete Setup
```bash
# Navigate to project directory
cd /path/to/aws-multi-account-bootstrap

# Run the complete setup
cd scripts
./setup-complete-project.sh TST your.email ou-xxxx-xxxxxxxx your-github-username test-aws-bootstrap
```

**Expected Duration:** 5-10 minutes

### Phase 4: Verify AWS Accounts Created
```bash
# List all accounts in organization
aws organizations list-accounts --output table

# Look for:
# - TST_DEV
# - TST_STAGING
# - TST_PROD
```

- [ ] TST_DEV account exists
- [ ] TST_STAGING account exists
- [ ] TST_PROD account exists
- [ ] All accounts are in ACTIVE state

### Phase 5: Verify CDK Bootstrap
For each account, check CDK bootstrap:
```bash
# Get account IDs from output or:
aws organizations list-accounts | jq -r '.Accounts[] | select(.Name | contains("TST")) | "\(.Name): \(.Id)"'

# Check CDK bootstrap bucket exists (for each account)
aws s3 ls --profile <account-profile> | grep cdk-
```

- [ ] Dev account has CDK bootstrap bucket
- [ ] Staging account has CDK bootstrap bucket
- [ ] Prod account has CDK bootstrap bucket

### Phase 6: Verify GitHub Repository
```bash
# Check repository was created
gh repo view your-github-username/test-aws-bootstrap

# Check branches exist
gh api repos/your-github-username/test-aws-bootstrap/branches
```

- [ ] Repository created on GitHub
- [ ] `main` branch exists and is protected
- [ ] `develop` branch exists and is protected
- [ ] Environments configured (dev, staging, prod)
- [ ] GitHub Actions workflows exist (`.github/workflows/`)
- [ ] Initial release v0.1.0 created

### Phase 7: Verify GitHub Actions CI/CD
```bash
# Check workflow runs
gh run list --repo your-github-username/test-aws-bootstrap --limit 5
```

- [ ] CI workflow exists
- [ ] Release workflow exists
- [ ] Initial workflows ran successfully
- [ ] OIDC configuration present in AWS accounts
- [ ] GitHub secrets configured (account IDs, role ARNs)

### Phase 8: Verify Billing Alerts
```bash
# Check CloudWatch alarms (in each account)
aws cloudwatch describe-alarms --profile <account-profile> | grep -i billing

# Check budgets
aws budgets describe-budgets --account-id <account-id>
```

- [ ] CloudWatch billing alarms created ($15 threshold)
- [ ] AWS Budgets created ($25 limit)
- [ ] SNS topics created for alerts
- [ ] Email confirmation received (check inbox)

### Phase 9: Verify Generated Documentation
Check that these files were created in the project root:
- [ ] `CICD_SETUP_SUMMARY.md` - AWS account details
- [ ] `GITHUB_SETUP_SUMMARY.md` - GitHub configuration
- [ ] `BILLING_ALERTS_SUMMARY.md` - Billing configuration
- [ ] `BILLING_MANAGEMENT.md` - Cost management guide
- [ ] `package.json` - Node.js project config
- [ ] `cdk.json` - CDK configuration
- [ ] `tsconfig.json` - TypeScript configuration
- [ ] `README.md` - Project documentation

### Phase 10: Test Deployment Workflow
```bash
# Clone the generated repository
cd /tmp
gh repo clone your-github-username/test-aws-bootstrap
cd test-aws-bootstrap

# Install dependencies
npm install

# Create a test CDK stack
cat > infrastructure/lib/test-stack.ts <<'EOF'
import * as cdk from 'aws-cdk-lib';
import * as s3 from 'aws-cdk-lib/aws-s3';
import { Construct } from 'constructs';

export class TestStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    new s3.Bucket(this, 'TestBucket', {
      versioned: true,
      encryption: s3.BucketEncryption.S3_MANAGED,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });
  }
}
EOF

# Update app.ts to include the stack
# Edit infrastructure/bin/app.ts and add:
# import { TestStack } from '../lib/test-stack';
# new TestStack(app, `${projectCode}-${env}-TestStack`, { ... });

# Test CDK synth
export ENV=dev
export PROJECT_CODE=TST
export CDK_DEFAULT_ACCOUNT=<dev-account-id>
export CDK_DEFAULT_REGION=us-east-1
npx cdk synth

# If synth works, try deploying to dev
npx cdk deploy --all --require-approval never
```

- [ ] CDK synth completes without errors
- [ ] CloudFormation templates generated in `cdk.out/`
- [ ] Deployment to dev account succeeds
- [ ] S3 bucket created in dev account

### Phase 11: Test Git Workflow
```bash
# Create a feature branch
git checkout -b feature/test-deployment

# Commit the changes
git add .
git commit -m "feat: Add test S3 bucket stack

AI: Claude Code"

# Push to GitHub
git push -u origin feature/test-deployment

# Create a pull request
gh pr create --title "Test: Add S3 bucket stack" --body "Testing deployment workflow" --base develop
```

- [ ] Feature branch created
- [ ] PR created successfully
- [ ] CI workflow runs on PR
- [ ] All status checks pass

### Phase 12: Test Semantic Release
```bash
# Merge PR to develop
gh pr merge --merge

# Check that deployment to dev happens
gh run list --limit 3

# Merge develop to main to trigger release
git checkout develop
git pull
git checkout main
git pull
git merge develop
git push

# Verify release created
gh release list
```

- [ ] PR merges to develop successfully
- [ ] Auto-deployment to dev triggered
- [ ] Merge to main creates new release
- [ ] Version number incremented correctly (v0.1.0 → v0.2.0)

---

## 🐛 Issue Tracking

Document any issues found during testing:

### Issues Found
1. **Issue:** [Description]
   - **Severity:** [Critical/High/Medium/Low]
   - **Steps to Reproduce:** [Steps]
   - **Expected:** [What should happen]
   - **Actual:** [What actually happened]
   - **Fix Needed:** [What needs to be fixed]

2. ...

### Improvements Needed
1. **Improvement:** [Description]
   - **Priority:** [High/Medium/Low]
   - **Reason:** [Why this is needed]
   - **Proposed Solution:** [How to fix it]

2. ...

---

## 🧹 Cleanup After Testing

When testing is complete, clean up resources:

```bash
# Delete CloudFormation stacks
aws cloudformation delete-stack --stack-name TST-dev-TestStack
# Wait for deletion
aws cloudformation wait stack-delete-complete --stack-name TST-dev-TestStack

# Delete GitHub repository
gh repo delete your-github-username/test-aws-bootstrap --yes

# Close AWS accounts (via AWS Console)
# 1. Go to AWS Organizations
# 2. Select each test account (TST_DEV, TST_STAGING, TST_PROD)
# 3. Close account (requires removing resources first)
# 4. Delete the test OU

# Delete billing alerts and budgets
aws cloudwatch delete-alarms --alarm-names <alarm-names>
aws budgets delete-budget --account-id <account-id> --budget-name <budget-name>
```

---

## 📊 Test Results Summary

| Test Phase | Status | Notes |
|------------|--------|-------|
| Prerequisites | ⏳ Not Started | |
| Prepare Environment | ⏳ Not Started | |
| Run Setup | ⏳ Not Started | |
| Verify Accounts | ⏳ Not Started | |
| Verify CDK Bootstrap | ⏳ Not Started | |
| Verify GitHub Repo | ⏳ Not Started | |
| Verify CI/CD | ⏳ Not Started | |
| Verify Billing | ⏳ Not Started | |
| Verify Documentation | ⏳ Not Started | |
| Test Deployment | ⏳ Not Started | |
| Test Git Workflow | ⏳ Not Started | |
| Test Semantic Release | ⏳ Not Started | |

**Overall Status:** ⏳ Not Started

**Date Started:** [Date]
**Date Completed:** [Date]
**Tested By:** [Your Name]

---

## 📝 Next Steps After Successful Test

If all tests pass:
1. ✅ Mark v1.0 as production-ready
2. ✅ Update README with "Production Ready" badge
3. ✅ Create GitHub release notes for v1.0
4. ✅ Announce to community (if applicable)
5. ✅ Begin v1.1 feature development

If tests fail:
1. ❌ Document all issues in this file
2. ❌ Create GitHub issues for each bug
3. ❌ Fix critical issues first
4. ❌ Re-run E2E test
5. ❌ Repeat until all tests pass

---

## 🔗 Related Documents

- [README.md](../README.md) - Main project documentation
- [ROADMAP.md](../docs/ROADMAP.md) - Feature roadmap
- [CONTRIBUTING.md](../CONTRIBUTING.md) - Contribution guidelines
- [CLAUDE.md](../CLAUDE.md) - AI assistant instructions

---

**Last Updated:** 2025-10-15
