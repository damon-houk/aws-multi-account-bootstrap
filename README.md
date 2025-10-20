# AWS Multi-Account Bootstrap

> 🚀 Bootstrap a complete AWS multi-account infrastructure with GitHub CI/CD in one command

[![Version](https://img.shields.io/badge/version-v0.6.0--dev-orange.svg)](VERSIONING.md)
[![Status](https://img.shields.io/badge/status-pre--release-yellow.svg)](VERSIONING.md)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

> ⚠️ **Pre-1.0 Notice**: This project is in active development. Breaking changes may occur between any v0.x releases. See [VERSIONING.md](VERSIONING.md) for details.

**Stop spending days configuring AWS infrastructure. Start building your application.**

This tool automates the complete setup of a production-ready AWS multi-account environment with modern CI/CD, semantic versioning, and cost controls—all in a single command.

## ✨ What You Get

In **one command**, this tool sets up:

- ✅ **3 AWS Accounts** (dev, staging, prod) in your AWS Organization
- ✅ **AWS CDK Bootstrapped** in all accounts
- ✅ **GitHub Repository** with branch protection and environments
- ✅ **CI/CD Pipeline** with GitHub Actions (OIDC, no credentials stored)
- ✅ **Semantic Versioning** with automated releases
- ✅ **Billing Alerts** ($15 alert, $25 budget per account)
- ✅ **Cost Estimation** with real-time AWS pricing
- ✅ **Dry-Run Mode** preview before creating resources
- ✅ **Complete Documentation** auto-generated for your project

**Before:** Days of manual AWS console clicking, YAML editing, and documentation writing.

**After:** One command. Five minutes. Done. ✨

---

## 🎯 Who Is This For?

**Perfect for:**
- 🏢 **Startups** who need AWS best practices without enterprise complexity
- 👨‍💻 **Solo Developers** building SaaS products
- 👥 **Small Teams** (2-10 people) who want to move fast
- 🎓 **Learning** AWS multi-account architecture
- 🚀 **Side Projects** that might become serious

**Not ideal for:**
- Large enterprises needing 10+ accounts (but see our [roadmap](#roadmap))
- Teams already using Terraform (check out [alternatives](#alternatives))
- Projects that don't use GitHub (GitLab support coming soon)

---

## Quick Start

### Prerequisites

```bash
# Check you have everything (takes 30 seconds)
make check-prerequisites
```

You need:
- AWS account with Organizations enabled
- AWS CLI configured (`aws sso login`)
- AWS CDK installed (`npm install -g aws-cdk`)
- GitHub CLI (`brew install gh`)
- Node.js 20+, jq, git

### One-Command Setup

```bash
# 1. Create an OU in AWS Console, get its ID (ou-xxxx-xxxxxxxx)

# 2. Preview what will be created (dry-run mode)
make setup-all \
  PROJECT_CODE=MYP \
  EMAIL_PREFIX=your.email \
  OU_ID=ou-xxxx-xxxxxxxx \
  GITHUB_ORG=your-github-username \
  REPO_NAME=my-project \
  DRY_RUN=true

# 3. Run the actual setup (remove DRY_RUN=true)
make setup-all \
  PROJECT_CODE=MYP \
  EMAIL_PREFIX=your.email \
  OU_ID=ou-xxxx-xxxxxxxx \
  GITHUB_ORG=your-github-username \
  REPO_NAME=my-project
```

**That's it!** ☕ Go get coffee. Come back to:
- 3 AWS accounts created and configured
- GitHub repository with CI/CD live
- First release (v0.1.0) published
- Billing alerts active
- Documentation generated

---

## 📖 What Happens Behind the Scenes

### 1. AWS Infrastructure (2-3 minutes)

Creates accounts in your AWS Organization:
```
Root
└── YOUR-PROJECT OU
    ├── MYP_DEV
    ├── MYP_STAGING
    └── MYP_PROD
```

Bootstraps AWS CDK in each account with:
- S3 bucket for assets
- ECR repository for containers
- IAM roles for deployments
- KMS keys for encryption

### 2. GitHub Repository (1 minute)

Creates and configures repository:
- ✅ Branch protection (main, develop)
- ✅ Environments (dev, staging, prod)
- ✅ OIDC provider for secure deployments
- ✅ GitHub Actions workflows
- ✅ Semantic release automation
- ✅ Issue labels and templates

### 3. CI/CD Pipeline (30 seconds)

Sets up automated deployments:
```
Push to develop  → Deploy to dev
Push to main     → Deploy to staging + Create release
Manual trigger   → Deploy to prod (requires approval)
```

### 4. Cost Controls (1 minute)

Configures billing alerts for each account:
- Email alert at $15 spending
- Budget alerts at 60%, 90%, 100% of $25
- Forecast alerts for predicted overages
- Monthly reset

---

## 🎨 Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     AWS Organization                         │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Management Account                                   │  │
│  │  - Organization root                                  │  │
│  │  - Billing consolidated                              │  │
│  └──────────────────────────────────────────────────────┘  │
│                           │                                  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  YOUR-PROJECT OU                                      │  │
│  │  ├── DEV Account                                      │  │
│  │  │   - Auto-deploy from develop branch               │  │
│  │  │   - Lower resources, can be shut down             │  │
│  │  │                                                    │  │
│  │  ├── STAGING Account                                  │  │
│  │  │   - Auto-deploy from main branch                  │  │
│  │  │   - Production-like environment                   │  │
│  │  │                                                    │  │
│  │  └── PROD Account                                     │  │
│  │      - Manual deploy with approval                    │  │
│  │      - Full monitoring & backups                      │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                           │
                           │ OIDC
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                     GitHub Repository                        │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Branches                                             │  │
│  │  - main (protected)                                   │  │
│  │  - develop (protected)                                │  │
│  │  - feature/* (PR required)                           │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  GitHub Actions Workflows                             │  │
│  │  - PR validation (tests + CDK diff)                  │  │
│  │  - Auto-deploy to dev/staging                        │  │
│  │  - Manual deploy to prod                             │  │
│  │  - Semantic release                                   │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## 💰 Cost Estimation

Get accurate, up-to-date AWS cost estimates before you start:

```bash
# Estimate costs for the basic setup
./scripts/estimate-costs.sh

# Estimate with additional services
./scripts/estimate-costs.sh --stacks api-lambda,static-website

# Estimate for different regions
./scripts/estimate-costs.sh --region eu-west-1

# List available stack types
./scripts/estimate-costs.sh --list-stacks
```

The estimator uses the **AWS Pricing API** for real-time pricing and includes:
- Base infrastructure costs (CloudWatch, S3, ECR)
- Usage-based estimates (minimal, light, moderate, heavy)
- Additional stack costs (API Gateway, Lambda, RDS, etc.)
- Region-specific pricing

## 📋 Usage Examples

### Deploy Your First Stack

```bash
# 1. Create a CDK stack
cat > infrastructure/lib/my-stack.ts <<EOF
import * as cdk from 'aws-cdk-lib';
import * as s3 from 'aws-cdk-lib/aws-s3';

export class MyStack extends cdk.Stack {
  constructor(scope: cdk.App, id: string, props?: cdk.StackProps) {
    super(scope, id, props);
    
    new s3.Bucket(this, 'MyBucket', {
      versioned: true,
      encryption: s3.BucketEncryption.S3_MANAGED,
    });
  }
}
EOF

# 2. Test locally
npm run cdk synth

# 3. Deploy to dev
make deploy-dev

# 4. Push to GitHub for automated deployment
git checkout -b feature/add-s3-bucket
git add .
git commit -m "feat: Add S3 bucket for data storage"
git push

# 5. Create PR → Merge to develop → Auto-deploys to dev!
```

### Semantic Commit Messages

Versioning is automated based on commit messages:

```bash
# Patch release (0.1.0 → 0.1.1)
git commit -m "fix: Correct timezone handling"

# Minor release (0.1.0 → 0.2.0)
git commit -m "feat: Add user authentication"

# Major release (0.1.0 → 1.0.0)
git commit -m "feat!: Redesign API

BREAKING CHANGE: All endpoints now require API key"

# No release
git commit -m "docs: Update README"
git commit -m "chore: Update dependencies"
```

### Adjust Billing Alerts

```bash
# Edit thresholds
vim setup-billing-alerts.sh
# Change line ~60:
# ALERT_THRESHOLD[prod]=50  # Alert at $50
# BUDGET_LIMIT[prod]=100     # Budget limit $100

# Rerun setup
make setup-billing PROJECT_CODE=MYP EMAIL=you@example.com
```

### Add a New Account

```bash
# Coming in v1.1 - for now, run setup again with updated config
# Or add manually via AWS Console + re-run bootstrap
```

---

## 📚 Documentation

### Configuration Guide

**New!** Flexible configuration system with support for:
- YAML/JSON configuration files
- Environment variables
- Interactive prompts
- CI/CD mode with auto-detection

See [Configuration Guide](docs/CONFIGURATION.md) for complete details on:
- Execution modes (interactive vs CI)
- Configuration precedence rules
- Config file formats (YAML/JSON)
- Environment variable usage
- Examples for teams and CI pipelines

### Generated Project Location

All generated project files are created in the `output/{PROJECT_CODE}/` directory. For example, if your `PROJECT_CODE` is `MYP`, your project will be located at:

```
output/MYP/
├── infrastructure/        # CDK infrastructure code
├── src/                   # Application source code
├── .github/workflows/     # CI/CD workflows
├── CICD_SETUP_SUMMARY.md
├── GITHUB_SETUP_SUMMARY.md
├── BILLING_ALERTS_SUMMARY.md
├── package.json
└── ... other project files
```

This keeps the bootstrap tool repository clean and allows you to easily manage multiple projects.

### Setup Summary Files

After setup completes, you'll find these documentation files in your project directory (`output/{PROJECT_CODE}/`):

- **CICD_SETUP_SUMMARY.md** - AWS account IDs and configuration
- **GITHUB_SETUP_SUMMARY.md** - GitHub repository settings
- **BILLING_ALERTS_SUMMARY.md** - Cost alert configuration
- **BILLING_MANAGEMENT.md** - Complete cost management guide

View any summary:
```bash
cd output/MYP              # Navigate to your project
cat CICD_SETUP_SUMMARY.md  # View AWS configuration
cat GITHUB_SETUP_SUMMARY.md     # View GitHub setup
cat BILLING_ALERTS_SUMMARY.md   # View billing alerts
```

---

## 🛠️ Commands Reference

### Setup Commands
```bash
make setup-all              # Complete automated setup
make create-accounts        # Just create AWS accounts
make bootstrap              # Just bootstrap CDK
make setup-cicd             # Just setup GitHub Actions
make setup-github           # Just create GitHub repo
make setup-billing          # Just setup billing alerts
```

### Development Commands
```bash
make install                # Install dependencies
make build                  # Build TypeScript
make test                   # Run tests
make lint                   # Run linter
make watch                  # Watch for changes
```

### Deployment Commands
```bash
make synth                  # Synthesize CloudFormation
make diff                   # Show differences
make deploy-dev             # Deploy to dev
make deploy-staging         # Deploy to staging
make deploy-prod            # Deploy to production
```

### Information Commands
```bash
make account-info PROJECT_CODE=MYP    # Show account IDs
make list-accounts                     # List all accounts
make check-prerequisites               # Check installed tools
```

---

## 💰 Cost Breakdown

### Bootstrap Infrastructure Costs

The baseline infrastructure created by this tool costs **nearly nothing** without any deployed application stacks:

| Component | Cost per Account | 3 Accounts Total |
|-----------|------------------|------------------|
| **CDK Bootstrap S3 Bucket** | ~$0.023/mo | ~$0.07/mo |
| **CDK Bootstrap ECR Repo** | $0 (no images) | $0 |
| **IAM Roles & Policies** | $0 (always free) | $0 |
| **AWS Budgets** | $0 (first 2 free) | $0 |
| **SNS Email Notifications** | $0 (email free) | $0 |
| **CloudWatch Alarms** | $0.10/alarm (optional) | $0.30/mo |
| **Baseline Total** | ~$0.13/mo | **~$0.40/mo** |

### Application Costs (Your CDK Stacks)

Once you deploy your application stacks, costs depend on what you build:

| Environment | Monthly Estimate | Example Workload |
|-------------|------------------|------------------|
| **Dev** | $10-100 | Small EC2/Lambda, RDS dev instance, S3 |
| **Staging** | $50-200 | Similar to prod but smaller instances |
| **Prod** | $100-500+ | Production EC2/ECS, RDS, CloudFront, etc. |
| **Total** | **$160-800+/mo** | Full application across all environments |

**Key Point:** The bootstrap tool itself costs less than $0.50/month. Your application costs depend entirely on what infrastructure you deploy with CDK.

### Cost Optimization Tips

**Bootstrap infrastructure:**
- Billing alerts are completely free (AWS Budgets + SNS)
- CloudWatch billing alarms are optional ($0.30/mo total)
- S3 storage costs scale with CDK asset uploads (minimal)

**Your application infrastructure:**
- Use AWS Free Tier where possible
- Shut down dev resources when not in use
- Use smaller instance sizes in dev/staging
- Delete unused CloudFormation stacks
- Tag all resources for cost tracking
- Review AWS Cost Explorer weekly

See [BILLING_MANAGEMENT.md](docs/BILLING_MANAGEMENT.md) for detailed cost optimization strategies.

---

## 🔐 Security

This tool implements AWS security best practices:

✅ **No Long-Lived Credentials**
- GitHub Actions uses OIDC (OpenID Connect)
- Temporary credentials per deployment
- No access keys stored in GitHub

✅ **Least Privilege**
- Separate IAM roles per environment
- Minimal permissions for each role
- Can be further restricted per your needs

✅ **Audit Logging**
- CloudTrail enabled organization-wide
- All API calls logged
- Centralized in management account

✅ **Encryption**
- Data encrypted at rest (KMS)
- Data encrypted in transit (TLS 1.2+)
- Secrets in AWS Secrets Manager

✅ **Branch Protection**
- No direct commits to main/develop
- Pull request required
- Status checks must pass
- Code review required (configurable)

**Security Recommendations:**
1. Enable MFA on all accounts
2. Reduce IAM permissions from AdministratorAccess
3. Enable AWS Config for compliance
4. Enable GuardDuty for threat detection
5. Regular security audits

---

## Roadmap

### Current (v0.6.0-dev)
- [x] 3-account setup (dev, staging, prod)
- [x] GitHub CI/CD with OIDC
- [x] Semantic versioning
- [x] Billing alerts
- [x] Mode-based configuration system
- [x] YAML/JSON config file support

### Next Releases (v0.x)
- [ ] GitLab CI/CD support
- [ ] Account structure templates (minimal/standard/enterprise)
- [ ] Interactive setup wizard
- [ ] Multi-region support
- [ ] Pre-configured stack templates
- [ ] Dry-run mode

### v1.0.0 (Future - When Stable)
First stable release when:
- Core features complete
- CLI interface finalized
- Production users successful
- Comprehensive test coverage

### v2.0.0 (Future - Major Enhancement)
- [ ] Service Control Policies (SCPs)
- [ ] AWS Control Tower integration
- [ ] Compliance packs (HIPAA, SOC2, etc.)
- [ ] SSO/Identity Center setup
- [ ] Enterprise features

[See full roadmap →](docs/ROADMAP.md)

---

## 🤝 Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for details.

**Ways to contribute:**
- 🐛 Report bugs
- 💡 Suggest features
- 📖 Improve documentation
- 🧪 Add tests
- 💻 Submit pull requests

---

## Alternatives

| Tool | Best For | Pros | Cons |
|------|----------|------|------|
| **aws-multi-account-bootstrap** (this) | Modern dev teams, startups | Simple, GitHub-first, batteries included | Only 3 accounts (for now) |
| [aws-multi-account-multi-region-bootstrapping-terraform](https://github.com/oliverschenk/aws-multi-account-multi-region-bootstrapping-terraform) | Enterprise, Terraform users | Comprehensive, 5+ accounts, multi-region | Complex setup, CodeCommit only |
| [terraform-aws-cdk_bootstrap](https://github.com/grendel-consulting/terraform-aws-cdk_bootstrap) | Control Tower + Terraform users | Terraform-native CDK bootstrap | Just bootstrap, not full setup |
| AWS Control Tower | Large enterprises (50+ accounts) | AWS-managed, comprehensive | Expensive, complex, overkill for small teams |
| Manual Setup | Learning AWS | Full control, educational | Days of work, error-prone |

---

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

Inspired by AWS best practices and the pain of setting up multi-account infrastructure manually too many times.

Built with:
- [AWS CDK](https://aws.amazon.com/cdk/)
- [GitHub Actions](https://github.com/features/actions)
- [Semantic Release](https://semantic-release.gitbook.io/)
- Lots of ☕ and determination

---

## 💬 Support

- 📖 [Documentation](docs/)
- 🐛 [Issue Tracker](https://github.com/damon-houk/aws-multi-account-bootstrap/issues)
- 💡 [Discussions](https://github.com/damon-houk/aws-multi-account-bootstrap/discussions)
- 📧 Email: damon.o.houk@gmail.com

---

<div align="center">

**If this saved you time, please ⭐ star the repo!**

Made with ❤️ for developers who want to ship, not configure infrastructure.

[Get Started](#quick-start) • [Documentation](docs/) • [Contributing](CONTRIBUTING.md)

</div>