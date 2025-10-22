# AI Assistant Context for AWS Multi-Account Bootstrap

> **IMPORTANT**: Keep this file updated when making significant changes. This provides context for AI assistants (Claude, GitHub Copilot, etc.) working on this codebase.

## Project Overview

AWS infrastructure automation tool that creates a production-ready multi-account setup with CI/CD in one command.
- **Version**: v0.7.0-alpha (pre-1.0, breaking changes expected)
- **Status**: Active development, refactoring to Hexagonal Architecture
- **Purpose**: Simplify AWS multi-account setup for startups/small teams

## Key Components

### Core Scripts (`/scripts/`)
- `setup-complete-project.sh` - Main orchestrator
- `lib/config-manager.sh` - Configuration system (YAML/JSON/env vars)
- `lib/prerequisite-checker.sh` - Dependency validation
- `lib/ui-helpers.sh` - CLI output formatting

### Configuration System (v0.6.0)
- **Modes**: Interactive (default) vs CI (auto-detected)
- **Sources**: CLI args → Config files → Env vars → Prompts
- **Files**: `.aws-bootstrap.yml` or `.aws-bootstrap.json`
- **Env vars**: `BOOTSTRAP_*` prefix

### Directory Structure
```
/
├── scripts/
│   ├── setup-complete-project.sh    # Main orchestrator
│   ├── ports/                       # Interfaces (Hexagonal Architecture)
│   │   ├── cloud-provider-port.sh   # Cloud operations interface
│   │   └── vcs-provider-port.sh     # VCS operations interface
│   ├── adapters/                    # Implementations
│   │   ├── aws/                     # AWS implementations (coming)
│   │   ├── github/                  # GitHub implementations (coming)
│   │   └── mock/                    # Testing mocks
│   │       ├── mock-cloud-adapter.sh
│   │       └── mock-vcs-adapter.sh
│   ├── domain/                      # Business logic (coming)
│   └── lib/                         # Shared utilities
│       ├── config-manager.sh
│       ├── prerequisite-checker.sh
│       └── ui-helpers.sh
├── docs/
│   ├── ARCHITECTURE_REFACTORING.md  # Hexagonal architecture plan
│   └── ...
├── tests/
│   ├── test-config-simple.sh        # Config tests (24 tests)
│   ├── test-mock-adapters.sh        # Mock adapter tests (30 tests)
│   └── ...
├── output/                          # Generated projects (gitignored)
├── .work/                           # Session artifacts (gitignored)
└── .claude/                         # IDE settings (gitignored)
```

## Development Conventions

### Git Commits
Always end commit messages with:
```
AI: Claude Code
```

### Versioning (IMPORTANT)
- **Current**: v0.x.x (pre-release, breaking changes OK)
- **v1.0.0**: Will be first stable release
- See `VERSIONING.md` for strategy

### Testing
- Run tests: `./tests/test-config-simple.sh`
- Tests work WITHOUT creating AWS/GitHub resources
- Config tests: 24/24 passing
- Mock adapter tests: 30/30 passing (NEW)

### Hexagonal Architecture (v0.7.0-alpha)
**Status**: Foundation complete, implementation in progress

The project is being refactored to Hexagonal Architecture (Ports & Adapters) for:
- **Better testability**: Mock adapters enable fast tests without AWS/GitHub
- **Multi-provider support**: Easy to add GitLab, Azure, GCP
- **Clear separation**: Business logic independent of infrastructure

**Current State**:
- ✅ **Ports** (interfaces): Cloud provider, VCS provider
- ✅ **Mock adapters**: Full test doubles for all port functions
- ✅ **Test suite**: 30 tests validating mock adapters
- 🚧 **AWS adapters**: Extracting existing AWS code (next phase)
- 🚧 **GitHub adapters**: Extracting existing GitHub code (next phase)
- 🚧 **Domain logic**: Pure business rules (next phase)

**Key Files**:
- `scripts/ports/` - Interface definitions
- `scripts/adapters/mock/` - Testing implementations
- `docs/ARCHITECTURE_REFACTORING.md` - Full refactoring plan
- `tests/test-mock-adapters.sh` - Adapter validation tests

**Benefits Achieved**:
- Tests run in <1 second (vs requiring AWS setup)
- Can test account creation logic without AWS Organizations access
- Clear contracts for future providers (GitLab, Azure, GCP)

See `docs/ARCHITECTURE_REFACTORING.md` for complete refactoring plan.

### Working Files
- Use `.work/` for temporary files, test results, session notes
- Never commit: `*_TEST_*.md`, `TEST_*.md`, session artifacts

## Architecture Summary

Creates 3 AWS accounts (dev/staging/prod) with:
1. AWS CDK bootstrap
2. GitHub Actions OIDC (no stored credentials)
3. Automated deployments (develop→dev, main→staging)
4. Billing alerts ($15 warning, $25 budget)
5. Semantic versioning

**PROJECT_CODE**: 3-character identifier used everywhere (e.g., "MYP")

## Current Features

✅ Completed:
- Basic 3-account setup
- GitHub CI/CD with OIDC
- Configuration system (YAML/JSON/env)
- Mode detection (interactive/CI)
- Comprehensive test suite (54 tests total)
- Hexagonal architecture foundation (ports + mock adapters)
- Version reset to v0.x.x

🚧 In Progress:
- Hexagonal architecture implementation (AWS/GitHub adapters)
- GitLab support (architecture ready, awaiting implementation)
- Account templates (minimal/standard/enterprise)
- Multi-region support

## Quick Commands

```bash
# Setup
make setup-all PROJECT_CODE=XYZ EMAIL_PREFIX=email OU_ID=ou-xxxx-xxxxxxxx GITHUB_ORG=username REPO_NAME=repo

# Testing
./tests/test-config-simple.sh        # Config system tests (24 tests)
./tests/test-mock-adapters.sh        # Mock adapter tests (30 tests)

# Check prerequisites
make check-prerequisites

# Deploy
make deploy-dev
make deploy-staging
make deploy-prod
```

## Files to Update When Changing Project

1. **This file** (`CLAUDE.md`) - Keep AI context current
2. `CHANGELOG.md` - Document changes
3. `README.md` - User-facing documentation
4. Tests - Add/update as needed

## Important Context

- **No production users** - OK to make breaking changes
- **Pre-1.0** - Using v0.x.x to indicate instability
- **Cost-conscious** - Target: <$100/month for small projects
- **Simplicity first** - One command setup is core value

## Known Issues

- YAML support requires `yq` (optional, falls back to JSON)
- Windows support limited (bash required)
- Only 3 accounts currently (templates coming)

## For AI Assistants

When working on this project:
1. Check current version and branch
2. Run existing tests before changes
3. Update this file if making structural changes
4. Use `.work/` for temporary artifacts
5. Follow commit message convention (add "AI: Claude Code")
6. Validate with `make check-prerequisites`

Last updated: 2025-10-21 (v0.7.0-alpha - Hexagonal architecture foundation)