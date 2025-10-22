# AI Assistant Context for AWS Multi-Account Bootstrap

> **IMPORTANT**: Keep this file updated when making significant changes. This provides context for AI assistants (Claude, GitHub Copilot, etc.) working on this codebase.

## Project Overview

AWS infrastructure automation tool that creates a production-ready multi-account setup with CI/CD in one command.

- **Status**: Monorepo with two versions
- **v1 (Bash)**: Stable, maintenance mode (1.x)
- **v2 (Go)**: Active development, alpha (2.0.0-alpha)
- **Purpose**: Simplify AWS multi-account setup for startups/small teams

## Major Change (2025-10-22)

**Restructured as monorepo** with bash v1 (maintenance) and Go v2 (active development).

**Rationale**:
- Need better UI/UX (web, mobile, desktop)
- Go provides better testing, type safety, single binary distribution
- Bash v1 works well but limited (no GUI, hard to test, hard to distribute)
- Hexagonal architecture from bash provides blueprint for Go version

**Migration**: See `.work/MIGRATION_PLAN_V2.md` for complete plan

---

## Repository Structure

```
aws-multi-account-bootstrap/          # Monorepo root
├── bash/                             # v1 - Bash (maintenance mode)
│   ├── scripts/                      # Bash scripts
│   ├── tests/                        # Test suite (54 tests)
│   ├── docs/                         # v1 documentation
│   ├── Makefile                      # v1 build commands
│   └── README.md                     # v1 user guide
│
├── go/                               # v2 - Go backend (active)
│   ├── cmd/
│   │   ├── cli/                      # CLI tool (future)
│   │   └── server/                   # API server (future)
│   ├── internal/
│   │   ├── domain/                   # Pure business logic
│   │   │   ├── account/              # Multi-account setup
│   │   │   ├── cicd/                 # CI/CD configuration
│   │   │   └── cost/                 # Cost management
│   │   ├── ports/                    # Interfaces
│   │   │   ├── cloudprovider.go      # Cloud operations
│   │   │   └── vcsprovider.go        # VCS operations
│   │   └── adapters/                 # Implementations
│   │       ├── aws/                  # AWS implementations
│   │       ├── github/               # GitHub implementations
│   │       └── mock/                 # Testing mocks
│   ├── api/                          # OpenAPI spec (future)
│   ├── go.mod                        # Go dependencies
│   ├── Makefile                      # Go build commands
│   └── README.md                     # v2 user guide (future)
│
├── apps/                             # Frontend applications (future)
│   ├── web/                          # React web dashboard
│   ├── mobile/                       # React Native (iOS/Android)
│   └── desktop/                      # Wails (Mac/Win/Linux)
│
├── packages/                         # Shared TypeScript (future)
│   ├── client/                       # API client
│   ├── core/                         # Shared business logic
│   └── ui/                           # UI components
│
├── docs/                             # Shared documentation (future)
│   ├── architecture/                 # Architecture decisions
│   ├── migration/                    # Bash → Go migration guide
│   └── guides/                       # How-to guides
│
├── .work/                            # Session artifacts (gitignored)
├── output/                           # Generated projects (gitignored)
├── package.json                      # Monorepo root config
├── turbo.json                        # Turborepo config
├── pnpm-workspace.yaml               # pnpm workspaces
├── README.md                         # Root README (monorepo overview)
└── CLAUDE.md                         # This file
```

---

## Development Conventions

### Git Commits

Always end commit messages with:
```
AI: Claude Code
```

### Versioning

- **v1 (Bash)**: 1.x.x (maintenance, bug fixes only)
- **v2 (Go)**: 2.0.0-alpha, 2.0.0-beta, 2.0.0 (active development)
- See `bash/VERSIONING.md` for v1 strategy

### Working on v1 (Bash)

```bash
cd bash

# Run tests
./tests/test-config-simple.sh        # Config system (24 tests)
./tests/test-mock-adapters.sh        # Mock adapters (30 tests)

# Test setup
./scripts/setup-complete-project.sh --dry-run

# Build
make check-prerequisites
```

**Status**: Maintenance only
- ✅ Bug fixes
- ✅ Security updates
- ❌ No new features
- ❌ No major refactoring

### Working on v2 (Go)

```bash
cd go

# Initialize (first time)
go mod init github.com/damon-houk/aws-multi-account-bootstrap/v2
go mod download

# Run tests
make test

# Build CLI
make build

# Run CLI
./bin/aws-bootstrap --help
```

**Status**: Active development
- 🚧 Porting domain logic from bash
- 🚧 Creating Go adapters
- 📅 Building CLI with TUI
- 📅 Creating API server
- 📅 Building frontends

### Working on Frontends (Future)

```bash
# From root
pnpm install

# Web app
cd apps/web
pnpm dev

# Mobile app
cd apps/mobile
pnpm start

# Build all
pnpm build
```

---

## Architecture: Hexagonal (Ports & Adapters)

Both v1 and v2 use **Hexagonal Architecture**:

```
┌─────────────────────────────────────────┐
│          Domain Logic (Pure)            │
│   Account Setup, CI/CD, Cost Mgmt      │
│   • No AWS CLI calls                    │
│   • No GitHub CLI calls                 │
│   • Pure business rules                 │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│        Ports (Interfaces)               │
│   CloudProvider, VCSProvider            │
│   • Define contracts                    │
│   • Language-agnostic design            │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│        Adapters (Implementations)       │
│   AWS, GitHub, Mock (testing)           │
│   • Implement port interfaces           │
│   • Handle infrastructure details       │
└─────────────────────────────────────────┘
```

**Benefits**:
- ✅ Easy to test (mock adapters, no AWS credentials)
- ✅ Easy to extend (add Azure, GitLab, GCP)
- ✅ Clear separation of concerns
- ✅ Business logic independent of infrastructure
- ✅ v1 architecture directly translates to v2

**Key Files (v1)**:
- `bash/scripts/ports/` - Port definitions
- `bash/scripts/adapters/aws/` - AWS implementations
- `bash/scripts/adapters/github/` - GitHub implementations
- `bash/scripts/adapters/mock/` - Testing mocks
- `bash/tests/test-mock-adapters.sh` - Port validation (30 tests)

**Key Files (v2)** *(coming)*:
- `go/internal/ports/` - Go interfaces
- `go/internal/adapters/aws/` - AWS SDK implementations
- `go/internal/adapters/github/` - go-github implementations
- `go/internal/adapters/mock/` - Testing mocks

---

## What the Tool Does

Creates a production-ready AWS infrastructure:

### 3 AWS Accounts
- **Dev** - Development environment
- **Staging** - Pre-production testing
- **Prod** - Production environment

### Naming Convention
- Account names: `${PROJECT_CODE}_${ENV_UPPER}` (e.g., `TPA_DEV`)
- Emails: `${email}+${project_code}-${env}@gmail.com`
- PROJECT_CODE: 3-character identifier

### Automated CI/CD
- GitHub Actions with OIDC (no stored credentials)
- Branch strategy:
  - `develop` → Dev (auto-deploy)
  - `main` → Staging (auto-deploy)
  - Production (manual approval)

### Cost Management
- Billing alerts: $15 warning
- Monthly budgets: $25 limit per environment
- CloudWatch alarms + AWS Budgets

### Infrastructure
- AWS CDK bootstrap in all accounts
- CloudFormation templates
- Semantic versioning

---

## Current Development Status

### v1 (Bash) - Completed ✅

**Architecture**: Hexagonal (Ports & Adapters)
- ✅ Ports defined (cloud, VCS)
- ✅ Mock adapters (testing)
- ✅ AWS adapters (4 adapters)
- ✅ GitHub adapters (2 adapters)
- ✅ 54 tests passing (24 config + 30 adapter)

**Features**: All complete
- ✅ Multi-account creation
- ✅ CDK bootstrap
- ✅ GitHub CI/CD with OIDC
- ✅ Billing alerts
- ✅ Configuration system (YAML/JSON/env)
- ✅ Dry-run mode
- ✅ Cost estimation

### v2 (Go) - In Progress 🚧

**Phase 1: Repository Restructuring** *(completed)*
- ✅ Move bash to `bash/` subdirectory
- ✅ Create monorepo structure
- ✅ Set up package.json, turbo.json
- ✅ Update README.md and CLAUDE.md
- ✅ Commit restructuring
- ✅ Initialize Go module

**Phase 2: Go Foundation** *(completed)*
- ✅ Create Go port interfaces
- ✅ Port domain logic (account module)
- ✅ Create mock adapters
- ✅ Write tests
- 🚧 Build basic CLI (in progress)

**Phase 3: Real Adapters** *(current - Week 2)*
- ✅ Port AWS adapters to Go (completed 2025-10-22)
  - ✅ AWS Organizations (account creation, management)
  - ✅ AWS IAM (OIDC providers, GitHub Actions roles)
  - ✅ AWS STS (role assumption, caller identity)
  - ✅ AWS Budgets (cost management)
  - ✅ AWS CloudWatch (billing alarms)
  - ✅ AWS SNS (notifications)
  - ✅ AWS CDK (bootstrap)
- 📅 Port GitHub adapters to Go
- 📅 Integration tests

**Phase 4: API Server** *(Week 3)*
- 📅 Create OpenAPI spec
- 📅 Build REST API server
- 📅 Generate TypeScript client

**Phase 5: Frontends** *(Week 4+)*
- 📅 CLI with Bubbletea TUI
- 📅 Web dashboard (React)
- 📅 Mobile apps (React Native)
- 📅 Desktop app (Wails)

---

## Quick Commands

### v1 (Bash)

```bash
cd bash

# Setup
make setup-all PROJECT_CODE=XYZ EMAIL_PREFIX=email \
  OU_ID=ou-xxxx-xxxxxxxx GITHUB_ORG=org REPO_NAME=repo

# Testing
./tests/test-config-simple.sh        # 24 tests
./tests/test-mock-adapters.sh        # 30 tests

# Check prerequisites
make check-prerequisites
```

### v2 (Go) - Coming Soon

```bash
cd go

# Build
make build

# Test
make test

# Run
./bin/aws-bootstrap create --interactive
```

### Monorepo (Root)

```bash
# Install frontend dependencies
pnpm install

# Build all
pnpm build

# Test all
pnpm test

# Run bash tests
pnpm bash:test

# Run Go tests
pnpm go:test
```

---

## Files to Update When Changing Project

1. **This file** (`CLAUDE.md`) - Keep AI context current
2. `CHANGELOG.md` - Document changes
3. `README.md` - User-facing documentation (root)
4. `bash/README.md` - v1 documentation (if changing bash)
5. `go/README.md` - v2 documentation (if changing Go)
6. Tests - Add/update as needed

---

## Important Context

- **No production users** - OK to make breaking changes
- **v1 stable** - Can be used in production
- **v2 in development** - Not ready for production
- **Cost-conscious** - Target: <$100/month for small projects
- **Simplicity first** - One command setup is core value
- **Multi-platform goal** - CLI, Web, Mobile, Desktop

---

## Known Issues

### v1 (Bash)
- YAML support requires `yq` (optional, falls back to JSON)
- Windows support limited (bash required)
- Only 3 accounts (templates coming in v2)
- No GUI (addressed in v2)

### v2 (Go)
- Not yet functional (in early development)
- No releases yet

---

## Technology Stack

### v1 (Bash)
- **Language**: Bash 4+
- **Dependencies**: AWS CLI, GitHub CLI, jq, yq (optional)
- **Testing**: Custom bash test framework
- **Distribution**: Git clone + run scripts

### v2 (Go)
- **Backend**: Go 1.21+
- **AWS**: AWS SDK for Go v2
- **GitHub**: go-github
- **CLI**: cobra (commands), viper (config), bubbletea (TUI)
- **API**: Standard library net/http or fiber
- **Testing**: Go test + testify

### Frontends (v2)
- **Monorepo**: Turborepo + pnpm workspaces
- **Web**: React + Vite + TypeScript
- **Mobile**: React Native + Expo
- **Desktop**: Wails (Go + React)
- **Shared**: TypeScript packages for client + logic

---

## For AI Assistants

When working on this project:

### General
1. Check which version you're working on (bash/ or go/)
2. Run existing tests before making changes
3. Update this file if making structural changes
4. Use `.work/` for temporary artifacts
5. Follow commit message convention (add "AI: Claude Code")

### Working on v1 (Bash)
1. v1 is maintenance mode - only bug fixes
2. Don't add new features to v1
3. Run tests: `cd bash && ./tests/test-config-simple.sh && ./tests/test-mock-adapters.sh`
4. Validate: `cd bash && make check-prerequisites`

### Working on v2 (Go)
1. v2 is active development - new features welcome
2. Follow hexagonal architecture (ports & adapters)
3. Port logic from v1 when possible
4. Write tests for all new code
5. Use `internal/` for non-exported packages
6. Use `pkg/` for exported packages
7. Document all public APIs

### Working on Frontends
1. Use shared packages (`packages/client`, `packages/core`)
2. Follow monorepo conventions (Turborepo)
3. Test across platforms (web + mobile if applicable)
4. Keep platform-specific code minimal

### Migration Strategy
1. v1 and v2 coexist during development
2. Don't break v1 while building v2
3. v1 can be deprecated once v2 reaches stable (v2.0.0)
4. See `.work/MIGRATION_PLAN_V2.md` for detailed plan

---

## Testing Strategy

### v1 (Bash)
- **Config tests**: 24 tests for configuration system
- **Adapter tests**: 30 tests for mock adapters
- **No AWS/GitHub required**: Tests use mocks
- **Fast**: All tests run in <2 seconds

### v2 (Go) - Planned
- **Unit tests**: Test domain logic with mocks
- **Integration tests**: Test adapters with real AWS/GitHub (optional)
- **E2E tests**: Test full workflows
- **Target**: >80% coverage

### Frontends - Planned
- **Unit tests**: Test components and hooks
- **Integration tests**: Test API integration
- **E2E tests**: Test user workflows (Playwright)

---

## Cost Estimation

Typical monthly costs for small projects:

| Environment | Services | Est. Cost |
|-------------|----------|-----------|
| Dev | S3, CloudFormation, CloudWatch | $10-15 |
| Staging | S3, CloudFormation, CloudWatch | $10-15 |
| Prod | S3, CloudFormation, CloudWatch + app | $20-50 |
| **Total** | | **$40-80** |

*Add compute costs (Lambda, ECS, EC2) based on your application needs*

---

## Roadmap

See main [README.md](./README.md) for detailed roadmap.

**Summary**:
- v1: Maintenance mode
- v2 Alpha: Foundation (current)
- v2 Beta: Enhanced UX with TUI and web (Q1 2026)
- v2 Stable: Multi-platform apps (Q2-Q3 2026)

---

Last updated: 2025-10-22 (AWS adapter implementation complete for Go v2)

AI: Claude Code