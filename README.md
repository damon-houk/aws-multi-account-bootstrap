# AWS Multi-Account Bootstrap

> **One-command AWS multi-account setup with CI/CD**
>
> Production-ready infrastructure for startups and small teams

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Version](https://img.shields.io/badge/version-v2.0.0--alpha-blue)]()

**Stop spending days configuring AWS infrastructure. Start building your application.**

This tool automates the complete setup of a production-ready AWS multi-account environment with modern CI/CD, semantic versioning, and cost controls.

---

## 📦 Monorepo Structure

This repository contains **two versions** of the AWS Multi-Account Bootstrap tool:

### 🔧 [v1 - Bash](./bash) (Maintenance Mode)

**Status**: Stable, maintenance only
**Version**: 1.x
**Use when**: You prefer scripts, minimal dependencies

```bash
cd bash
make setup-all PROJECT_CODE=XYZ EMAIL_PREFIX=email \
  OU_ID=ou-xxxx-xxxxxxxx GITHUB_ORG=username REPO_NAME=repo
```

[→ v1 Documentation](./bash/README.md)

---

### 🚀 [v2 - Go with CLI/TUI](./go) (Active Development) ⭐ **RECOMMENDED**

**Status**: Alpha (~80% complete)
**Version**: 2.0.0-alpha

```bash
# Interactive TUI wizard
./bin/aws-bootstrap create --interactive

# Or with flags
./bin/aws-bootstrap create --project XYZ --email you@gmail.com ...
```

**Why v2?**
- ✅ Beautiful terminal UI (Bubbletea wizard)
- ✅ Template browser (66+ CloudFormation templates)
- ✅ AWS SDK v2 integration
- ✅ GitHub API integration
- ✅ Strong typing (Go)
- 🚧 Single binary distribution (almost ready)
- ✅ Fast tests (<100ms, no AWS credentials)

[→ v2 Documentation](./go/README.md)

---

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
- Large enterprises needing 10+ accounts
- Teams already using Terraform heavily
- Projects that don't use GitHub (GitLab support coming in v2)

---

## 🚀 Quick Start

### v2 (Go) - Recommended for New Projects

**Prerequisites**:
- Go 1.21+
- AWS CLI configured
- GitHub CLI authenticated

```bash
# Clone the repository
git clone https://github.com/damon-houk/aws-multi-account-bootstrap.git
cd aws-multi-account-bootstrap

# Build the CLI
cd go
make build

# Create multi-account setup
./bin/aws-bootstrap create \
  --project XYZ \
  --email your-email@gmail.com \
  --ou-id ou-xxxx-xxxxxxxx \
  --github-org your-org \
  --repo your-repo

# Or use interactive mode
./bin/aws-bootstrap create --interactive
```

### v1 (Bash) - Stable and Battle-Tested

**Prerequisites**:
- Bash 4+
- AWS CLI configured
- GitHub CLI authenticated
- jq (JSON processor)

```bash
# Clone the repository
git clone https://github.com/damon-houk/aws-multi-account-bootstrap.git
cd aws-multi-account-bootstrap/bash

# Check prerequisites
make check-prerequisites

# Run setup
make setup-all PROJECT_CODE=XYZ EMAIL_PREFIX=email \
  OU_ID=ou-xxxx-xxxxxxxx GITHUB_ORG=username REPO_NAME=repo
```

---

## 📂 Repository Structure

```
aws-multi-account-bootstrap/
├── bash/                    # v1 - Bash (maintenance mode)
│   ├── scripts/             # Bash scripts
│   ├── tests/               # Test suite (54 tests)
│   └── docs/                # v1 documentation
│
├── go/                      # v2 - Go CLI (active)
│   ├── cmd/aws-bootstrap/   # CLI entry point
│   ├── internal/
│   │   ├── domain/          # Pure business logic
│   │   ├── ports/           # Interfaces (AWS-specific)
│   │   ├── adapters/        # Implementations (aws/, github/, templates/, mock/)
│   │   └── cli/tui/         # Bubbletea wizard
│   └── README.md
│
└── docs/                    # Shared documentation
    ├── architecture/        # HEXAGONAL_ARCHITECTURE.md
    └── migration/           # BASH_TO_GO.md
```

---

## 🏗️ Architecture

Both versions use **Hexagonal Architecture** (Ports & Adapters):

```
┌─────────────────────────────────────────┐
│          Domain Logic (Pure)            │
│   Account Setup, CI/CD, Cost Mgmt      │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│        Ports (Interfaces)               │
│   CloudProvider, VCSProvider            │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│        Adapters (Implementations)       │
│   AWS, GitHub, Mock (testing)           │
└─────────────────────────────────────────┘
```

**Benefits**:
- ✅ Easy to test (mock adapters, no AWS credentials needed)
- ✅ Clear separation of concerns
- ✅ Business logic separate from infrastructure

See [Architecture Documentation](./docs/architecture/HEXAGONAL_ARCHITECTURE.md) for details.

**Note**: This tool is AWS-specific by design. Azure/GCP have different multi-account patterns and need separate tools.

---

## 🔄 Migration from v1 to v2

Both versions can coexist. You can:

1. **Keep using v1** - It's stable and works great
2. **Try v2 in parallel** - Test while keeping v1
3. **Migrate fully** - When v2 reaches stable

See [Migration Guide](./docs/migration/BASH_TO_GO.md) for details.

---

## 💻 Development

### v2 (Go)

```bash
cd go

# Run tests (fast, <100ms)
make test

# Build CLI
make build

# Run wizard
./bin/aws-bootstrap create --interactive
```

### v1 (Bash)

```bash
cd bash

# Run tests
./tests/test-config-simple.sh        # 24 tests
./tests/test-mock-adapters.sh        # 30 tests
```

---

## 💰 Cost Estimation

Typical monthly costs for small projects:

| Environment | Estimated Cost |
|-------------|----------------|
| Dev         | $10-15/month   |
| Staging     | $10-15/month   |
| Prod        | $20-50/month   |
| **Total**   | **$40-80/month** |

*Costs include: CloudFormation, CDK, S3, CloudWatch, minimal compute*

---

## 🗺️ Roadmap

### v1 (Bash)
- ✅ Stable, production-ready
- 🔄 Maintenance mode (bug fixes only)

### v2 (Go) - Current Status (~80% complete)

**Completed** ✅:
- Hexagonal architecture
- AWS adapter (Organizations, IAM, STS, Budgets, CloudWatch, SNS, CDK)
- GitHub adapter (repos, branches, secrets, environments, workflows, OIDC)
- Template browser (66+ CloudFormation templates)
- Prerequisites checker
- Bubbletea TUI wizard

**In Progress** 🚧:
- Template parser (🔴 blocker: hangs on CloudFormation YAML)
- Wizard execution step

**Next**:
- Fix template parser
- Complete execution
- Single binary distribution
- v2.0.0-alpha release

---

## 🤝 Contributing

Contributions welcome! See [CONTRIBUTING.md](./bash/CONTRIBUTING.md).

**v2 priorities**:
1. Fix template parser hang
2. Complete wizard execution
3. Integration tests
4. Binary distribution

---

## 📚 Documentation

- **v1 (Bash)**: [bash/README.md](./bash/README.md)
- **v2 (Go)**: [go/README.md](./go/README.md)
- **Architecture**: [docs/architecture/HEXAGONAL_ARCHITECTURE.md](./docs/architecture/HEXAGONAL_ARCHITECTURE.md)
- **Migration**: [docs/migration/BASH_TO_GO.md](./docs/migration/BASH_TO_GO.md)

---

## 📝 License

Apache License 2.0 - see [LICENSE](./LICENSE) for details

---

## 💬 Support

- **Issues**: [GitHub Issues](https://github.com/damon-houk/aws-multi-account-bootstrap/issues)
- **Discussions**: [GitHub Discussions](https://github.com/damon-houk/aws-multi-account-bootstrap/discussions)

---

## 🙏 Acknowledgments

- Built with [Hexagonal Architecture](https://alistair.cockburn.us/hexagonal-architecture/)
- Inspired by AWS best practices and community feedback
- Thanks to all contributors!

---

**Current Version**: 2.0.0-alpha.1
**Status**: v1 (Stable), v2 (Active Development)
**Maintained**: Yes
**Production Ready**: v1 (Yes), v2 (Not Yet)

AI: Claude Code
