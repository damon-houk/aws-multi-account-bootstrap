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

### 🚀 [v2 - Go + Multi-Platform](./go) (Active Development) ⭐ **RECOMMENDED**

**Status**: Alpha (in active development)
**Version**: 2.0.0-alpha
**Platforms**: CLI (TUI), Web, Mobile (iOS/Android), Desktop (Mac/Win/Linux)

```bash
# CLI with beautiful TUI
aws-bootstrap create --project XYZ

# API Server for web/mobile apps
aws-bootstrap serve --port 8080
```

**Why v2?**
- ✅ Beautiful terminal UI (Bubbletea)
- ✅ Web dashboard
- ✅ Mobile apps (React Native)
- ✅ Desktop app (Wails)
- ✅ Strong typing (Go + TypeScript)
- ✅ Single binary distribution
- ✅ Better testing

[→ v2 Documentation](./go/README.md) *(coming soon)*

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
│   ├── docs/                # v1 documentation
│   └── README.md            # v1 guide
│
├── go/                      # v2 - Go backend (active)
│   ├── cmd/
│   │   ├── cli/             # CLI tool
│   │   └── server/          # API server
│   ├── internal/
│   │   ├── domain/          # Business logic
│   │   ├── ports/           # Interfaces
│   │   └── adapters/        # AWS/GitHub implementations
│   ├── api/                 # OpenAPI spec
│   └── README.md            # v2 guide
│
├── apps/                    # Frontend applications
│   ├── web/                 # React web dashboard
│   ├── mobile/              # React Native app
│   └── desktop/             # Wails desktop app
│
├── packages/                # Shared TypeScript
│   ├── client/              # API client
│   ├── core/                # Shared business logic
│   └── ui/                  # UI components
│
└── docs/                    # Shared documentation
    ├── architecture/        # Architecture decisions
    ├── migration/           # Migration guides
    └── guides/              # How-to guides
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
- ✅ Easy to extend (add Azure, GitLab, GCP support)
- ✅ Clear separation of concerns
- ✅ Business logic independent of infrastructure

See [Architecture Documentation](./docs/architecture/HEXAGONAL_ARCHITECTURE.md) *(coming soon)* for details.

---

## 🔄 Migration from v1 to v2

Both versions can coexist. You can:

1. **Keep using v1** - It's stable and works great
2. **Try v2 in parallel** - Test while keeping v1
3. **Migrate fully** - When v2 reaches stable

See [Migration Guide](./docs/migration/BASH_TO_GO.md) *(coming soon)* for details.

---

## 💻 Development

### Working on Go backend (v2)

```bash
cd go

# Install dependencies
go mod download

# Run tests
make test

# Build CLI
make build

# Run CLI
./bin/aws-bootstrap --help

# Start API server
./bin/aws-bootstrap serve
```

### Working on frontends (v2)

```bash
# Install dependencies (from root)
pnpm install

# Start web app (development)
cd apps/web
pnpm dev

# Start mobile app
cd apps/mobile
pnpm start

# Build all apps
pnpm build
```

### Working on bash (v1)

```bash
cd bash

# Run tests
./tests/test-config-simple.sh        # Config system (24 tests)
./tests/test-mock-adapters.sh        # Mock adapters (30 tests)

# Test setup (dry-run)
./scripts/setup-complete-project.sh --dry-run
```

---

## 🧪 Testing

### Go Tests (v2)
```bash
cd go
make test                    # Unit tests
make test-integration        # Integration tests (requires AWS)
make test-coverage           # Coverage report
```

### Bash Tests (v1)
```bash
cd bash
./tests/test-config-simple.sh       # Config system (24 tests)
./tests/test-mock-adapters.sh       # Mock adapters (30 tests)
```

### Frontend Tests (v2)
```bash
pnpm test                    # All frontend tests
pnpm test --filter=web       # Web app only
pnpm test --filter=mobile    # Mobile app only
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

### v1 (Bash) - Maintenance Mode
- ✅ v1.0.0 - Stable release
- 🔄 Bug fixes only
- ❌ No new features

### v2 (Go) - Active Development

**Phase 1: Foundation (Current)**
- 🚧 Port domain logic from bash to Go
- 🚧 Create adapters (AWS, GitHub)
- 🚧 Build basic CLI

**Phase 2: Enhanced UX (Q1 2026)**
- 📅 CLI with beautiful TUI (Bubbletea)
- 📅 API server (REST/GraphQL)
- 📅 Web dashboard (React)

**Phase 3: Multi-Platform (Q2 2026)**
- 📅 Mobile apps (iOS/Android with React Native)
- 📅 Desktop app (Mac/Win/Linux with Wails)
- 📅 Full documentation

**Phase 4: v2.0.0 Stable (Q3 2026)**
- 📅 Production-ready
- 📅 Feature parity with v1
- 📅 Multi-cloud support (Azure, GCP)
- 📅 GitLab support

---

## 🤝 Contributing

We welcome contributions! See [CONTRIBUTING.md](./bash/CONTRIBUTING.md) for guidelines.

**Development priorities** (v2):
1. ✅ Hexagonal architecture foundation
2. 🚧 Port domain logic to Go
3. 🚧 Create Go adapters (AWS, GitHub)
4. 📅 Build CLI with TUI
5. 📅 Create API server
6. 📅 Build web dashboard

---

## 📚 Documentation

- **v1 (Bash)**: [bash/README.md](./bash/README.md)
- **v2 (Go)**: [go/README.md](./go/README.md) *(coming soon)*
- **Architecture**: [docs/architecture/](./docs/architecture/) *(coming soon)*
- **Migration**: [docs/migration/BASH_TO_GO.md](./docs/migration/) *(coming soon)*
- **API Docs**: Coming soon in `go/api/`

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
