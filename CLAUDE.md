# AI Assistant Context

> **Purpose**: Terse, optimized context for AI assistants working on this codebase.

## 🔥 CURRENT STATUS (2025-10-25) - READ THIS FIRST

| Component | Status | Location | Notes |
|-----------|--------|----------|-------|
| **v1 (Bash)** | ✅ Stable | `bash/` | 54 tests, maintenance only |
| **v2 Go - AWS Adapter** | ✅ Complete | `go/internal/adapters/aws/` | Full AWS SDK v2 integration |
| **v2 Go - GitHub Adapter** | ✅ Complete | `go/internal/adapters/github/` | Full go-github integration |
| **v2 Go - CLI + TUI** | 🚧 80% | `go/cmd/aws-bootstrap/` | Bubbletea wizard |
| **Template Browser** | ✅ Working | `go/internal/adapters/templates/` | 66+ cloudonaut/widdix templates |
| **Cost Estimation** | 🔴 BLOCKED | `go/internal/domain/templates/` | **Parser hangs on CloudFormation YAML** |

**CRITICAL BLOCKER**: `analyzer.AnalyzeTemplate()` hangs indefinitely when parsing CloudFormation YAML from remote templates. Currently disabled, falling back to bootstrap-only estimates.

**Next Priority**: Fix template parser hang - add timeout + debug logging to `go/internal/domain/templates/analyzer.go`

## Quick Reference

**Purpose**: AWS multi-account setup (dev/staging/prod) + GitHub CI/CD in one command
**Target**: Startups, solo devs, small teams (2-10 people)
**Architecture**: Hexagonal (Ports & Adapters) - AWS-specific, not multi-cloud
**Versions**: v1 (Bash, maintenance) | v2 (Go, active development)

## Quick Commands

```bash
# v1 (Bash) - Maintenance
cd bash
./tests/test-config-simple.sh        # 24 tests
./tests/test-mock-adapters.sh        # 30 tests

# v2 (Go) - Active Development
cd go
make test                             # Unit tests (<100ms)
make build                            # Build CLI binary
./bin/aws-bootstrap create --interactive  # Test TUI wizard

# Debug wizard
./bin/aws-bootstrap create --interactive 2>&1 | tee /tmp/wizard.log

# Clear caches if needed
rm -rf ~/.aws-bootstrap/template-cache/
rm -rf ~/.aws-bootstrap/pricing-cache/
```

## Repository Structure

```
bash/                    # v1 - Maintenance only (54 tests passing)
  scripts/, tests/, docs/, Makefile

go/                      # v2 - Active development
  cmd/aws-bootstrap/     # CLI entry (Cobra + Bubbletea)
  internal/
    domain/              # Pure business logic
      account/           # Account naming, orchestration
      templates/         # Template analysis (🔴 BLOCKER: analyzer.go hangs)
      cost/              # Cost estimation
    ports/               # Interfaces
      aws.go, github.go, template_loader.go, prerequisite_checker.go
    adapters/            # Implementations
      aws/               # ✅ Complete - AWS SDK v2
      github/            # ✅ Complete - go-github
      templates/         # ✅ Complete - GitHub API + filesystem
      system/            # ✅ Complete - Prerequisites checker
      mock/              # For testing
    cli/tui/             # 🚧 80% - Bubbletea wizard
      wizard.go          # Main wizard logic (async ops, 7-step flow)
      views.go           # UI views for each step

docs/                    # Shared documentation
  architecture/HEXAGONAL_ARCHITECTURE.md
  migration/BASH_TO_GO.md

.work/                   # Session notes (gitignored)
```

## Git Conventions

**Commit suffix**: `AI: Claude Code`
**Versioning**: v1 = 1.x.x (maintenance) | v2 = 2.0.0-alpha (active)

---

## Architecture: Hexagonal (Ports & Adapters)

**Pattern**: Domain (pure) → Ports (interfaces) → Adapters (AWS SDK, GitHub API, mocks)

**Why**: Testing without AWS credentials (not for multi-cloud abstraction)

**Structure**:
- `go/internal/domain/` - Pure business logic (no infrastructure)
- `go/internal/ports/` - Interface definitions
- `go/internal/adapters/` - Implementations (aws/, github/, templates/, system/, mock/)

**Key Insight**: AWS-specific design. This tool is for AWS only. Azure/GCP need separate tools.

---

## What the Tool Does

Creates production-ready AWS multi-account infrastructure:
- **3 AWS Accounts**: Dev, Staging, Prod
- **Naming**: `PROJECT_CODE_ENV` (e.g., `TPA_DEV`), emails use Gmail + addressing
- **CI/CD**: GitHub Actions with OIDC (no stored credentials)
- **Branch strategy**: `develop`→Dev, `main`→Staging, `tag`→Prod (manual approval)
- **Cost alerts**: $15 warning, $25 budget per environment
- **Infrastructure**: AWS CDK bootstrap, CloudFormation templates, semantic versioning

**Estimated cost**: $40-80/month baseline (add compute costs for your app)

---

## v2 Development Progress

**Completed (2025-10-22)**:
- ✅ Hexagonal architecture with ports/adapters
- ✅ AWS adapter (Organizations, IAM, STS, Budgets, CloudWatch, SNS, CDK)
- ✅ GitHub adapter (repos, branches, secrets, environments, workflows, OIDC)
- ✅ Template loader (66+ cloudonaut/widdix CloudFormation templates)
- ✅ Prerequisites checker (AWS CLI, GitHub CLI, CDK CLI)

**In Progress (2025-10-23, ~80% complete)**:
- 🚧 CLI with Bubbletea TUI (7-step wizard: Category → Template → Profile → Cost → Bootstrap → Prerequisites → Config → Review → Execute)
- 🚧 Async operations with spinners
- 🚧 Error handling and recovery
- 🔴 **BLOCKER**: Template analyzer hangs on CloudFormation YAML parsing (workaround: bootstrap-only estimates)

**Remaining**:
- 📅 Fix template parser hang (add timeout, debug logging)
- 📅 Implement execution step (create accounts, GitHub repo)
- 📅 Add progress tracking during execution
- 📅 Save configuration to file after completion
- 📅 Single binary distribution
- 📅 Homebrew formula

---

## Known Issues

**v1 (Bash)**:
- YAML requires `yq` (optional, falls back to JSON)
- Windows limited (requires bash)

**v2 (Go)**:
- 🔴 Template parser hangs on CloudFormation YAML (`go/internal/domain/templates/analyzer.go`)
- No releases yet (development binary only)
- Not ready for production

---

## Technology Stack

**v1**: Bash 4+, AWS CLI, GitHub CLI, jq, yq (optional)
**v2**: Go 1.21+, AWS SDK v2, go-github/v67, Cobra, Viper, Bubbletea

---

## For AI Assistants

**Before starting**:
1. Read "CURRENT STATUS" table at top
2. Check `.work/SESSION_*` files for recent context
3. Run tests before changes: `cd bash && ./tests/test-mock-adapters.sh` or `cd go && make test`

**When working on v1**: Maintenance only - bug fixes/security updates, no new features

**When working on v2**:
1. Follow hexagonal architecture (keep domain pure, adapters separate)
2. Write tests with mock adapters
3. Check blocker status before working on template parsing
4. Update this file if changing architecture or status
5. Add `AI: Claude Code` to all commits

**Debugging**:
- Wizard logs: `./bin/aws-bootstrap create --interactive 2>&1 | tee /tmp/wizard.log`
- Clear caches: `rm -rf ~/.aws-bootstrap/{template,pricing}-cache/`
- Check session notes: `.work/SESSION_2025-10-23_CLI_TUI_PROGRESS.md`

---

Last updated: 2025-10-25

AI: Claude Code