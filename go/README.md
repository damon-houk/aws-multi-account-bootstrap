# AWS Multi-Account Bootstrap v2 (Go)

> **Status**: Active Development (v2.0.0-alpha, ~80% complete)
>
> Go implementation with strong typing, better testing, single binary distribution, and beautiful TUI wizard.

## Quick Start

```bash
# Run tests
make test

# Development workflow (fmt, vet, test)
make dev

# Build CLI binary
make build

# Run CLI
./bin/aws-bootstrap --help
```

## Current Status

**Completed** ✅:
- AWS adapter (Organizations, IAM, STS, Budgets, CloudWatch, SNS, CDK)
- GitHub adapter (repos, branches, secrets, environments, workflows, OIDC)
- Template loader (66+ cloudonaut/widdix CloudFormation templates)
- Prerequisites checker (AWS CLI, GitHub CLI, CDK CLI)
- CLI with Bubbletea TUI (~80% complete)

**In Progress** 🚧:
- 7-step interactive wizard (Category → Template → Profile → Cost → Bootstrap → Prerequisites → Config → Review → Execute)
- Async operations with progress indicators

**Blocked** 🔴:
- Template analyzer hangs on CloudFormation YAML parsing (currently falling back to bootstrap-only cost estimates)

## Architecture

**Pattern**: Domain (pure) → Ports (interfaces) → Adapters (AWS SDK, GitHub API, mocks)

**Why**: Testing without AWS credentials (not for multi-cloud abstraction)

```
go/
├── cmd/aws-bootstrap/     # CLI with Cobra + Bubbletea TUI
├── internal/
│   ├── domain/            # Pure business logic
│   │   ├── account/       # Account naming, orchestration
│   │   ├── templates/     # Template analysis (🔴 BLOCKER)
│   │   └── cost/          # Cost estimation
│   ├── ports/             # Interfaces
│   │   ├── aws.go, github.go
│   │   ├── template_loader.go
│   │   └── prerequisite_checker.go
│   ├── adapters/          # Implementations
│   │   ├── aws/           # ✅ AWS SDK v2
│   │   ├── github/        # ✅ go-github
│   │   ├── templates/     # ✅ GitHub API + filesystem
│   │   ├── system/        # ✅ Prerequisites
│   │   └── mock/          # For testing
│   └── cli/tui/           # 🚧 Bubbletea wizard
```

**Key Insight**: AWS-specific design. This tool is for AWS only. Azure/GCP need separate tools.

## Testing

All tests use mock adapters - no AWS credentials required:

```bash
# Run all tests
make test

# Verbose output
make test-verbose

# With coverage
make test-coverage
```

**Current test status:**
- ✅ 14 tests passing
- ✅ Race detection enabled
- ✅ <100ms execution time

## Development

### Prerequisites

- Go 1.25.3 or later
- Make

### Workflow

```bash
# Quick development cycle
make dev

# Format code
make fmt

# Run linter (if golangci-lint installed)
make lint

# Build CLI
make build
```

### Adding New Features

1. Define port interface in `internal/ports/`
2. Implement business logic in `internal/domain/`
3. Create mock adapter in `internal/adapters/mock/`
4. Write tests using mock
5. Implement real adapter in `internal/adapters/aws/`

## Next Steps

**Immediate**:
- [ ] Fix template analyzer hang (add timeout + debug logging to `internal/domain/templates/analyzer.go`)
- [ ] Complete wizard execution step (create AWS accounts, GitHub repo)
- [ ] Add progress tracking during execution

**Near-term**:
- [ ] Save configuration to file after completion
- [ ] Add integration tests with real AWS/GitHub
- [ ] Single binary distribution
- [ ] Homebrew formula
- [ ] Shell completions (bash, zsh, fish)

**Future**:
- [ ] Template marketplace/gallery
- [ ] Cost optimization recommendations
- [ ] Multi-region support

## Testing

**Unit Tests** (<100ms, no AWS credentials):
```bash
make test        # All tests with race detection
make test-verbose
make test-coverage
```

**Integration Tests** (optional, requires AWS/GitHub):
```bash
# Not yet implemented
# Will test real AWS SDK and GitHub API integration
```

## Debugging

```bash
# Run wizard with debug output
./bin/aws-bootstrap create --interactive 2>&1 | tee /tmp/wizard.log

# Clear caches if needed
rm -rf ~/.aws-bootstrap/template-cache/
rm -rf ~/.aws-bootstrap/pricing-cache/
```

## Documentation

- [Main README](../README.md) - Monorepo overview
- [CLAUDE.md](../CLAUDE.md) - AI assistant context (read this first!)
- [Hexagonal Architecture](../docs/architecture/HEXAGONAL_ARCHITECTURE.md)
- [Migration Guide](../docs/migration/BASH_TO_GO.md)
- [AWS Adapter](./internal/adapters/aws/README.md)
- [GitHub Adapter](./internal/adapters/github/README.md)

## License

Apache 2.0 - See [LICENSE](../LICENSE)
