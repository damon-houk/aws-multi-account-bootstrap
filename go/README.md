# AWS Multi-Account Bootstrap v2 (Go)

> **Status**: Active Development (v2.0.0-alpha)
>
> This is the v2 implementation built with Go. It provides strong typing, better performance, and foundation for multi-platform frontends (web, mobile, desktop).

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

## Architecture

This implementation uses **Hexagonal Architecture (Ports & Adapters)** with an honest, AWS-specific design:

```
go/
├── cmd/
│   └── aws-bootstrap/     # CLI entry point
├── internal/
│   ├── ports/             # Interfaces (AWS-specific)
│   │   └── aws.go         # AWSClient interface
│   ├── domain/            # Business logic (pure Go)
│   │   └── account/       # Account management domain
│   └── adapters/          # Implementations
│       ├── aws/           # Real AWS SDK adapter (TODO)
│       └── mock/          # Test doubles
└── pkg/                   # Public libraries
```

### Key Design Decisions

**AWS-Specific Interface**
- This tool is designed for AWS, not generic cloud
- The `AWSClient` interface is deliberately AWS-specific
- Operations like `BootstrapCDK`, `CreateOIDCProviderForGitHub`, `CreateBudget` are AWS-only
- Other clouds (Azure, GCP) have fundamentally different multi-account patterns

**Why Hexagonal Architecture?**
- **Testing**: Mock adapters enable fast tests (<100ms) without AWS credentials
- **Separation**: Business logic stays separate from AWS SDK details
- **Clarity**: Makes dependencies explicit

**Not for Multi-Cloud**
- We're honest: This is AWS-only
- Azure and GCP need separate tools
- False cloud abstractions create complexity without value

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

## Roadmap

- [ ] Implement real AWS adapter (AWS SDK v2)
- [ ] Implement GitHub adapter
- [ ] Build CLI application structure
- [ ] Add billing/budget domain logic
- [ ] Create configuration system
- [ ] Build web frontend
- [ ] Build mobile app (React Native)

## Migration from v1

See [Migration Guide](../docs/migration/BASH_TO_GO.md) for details on migrating from bash v1 to Go v2.

## Testing Philosophy

**Unit Tests**
- Use mock adapters
- Test business logic in isolation
- Fast (<1ms per test)
- No external dependencies

**Integration Tests** (TODO)
- Use AWS LocalStack or similar
- Test real AWS SDK integration
- Slower but verify actual AWS behavior

## Documentation

- [Hexagonal Architecture](../docs/architecture/HEXAGONAL_ARCHITECTURE.md)
- [AWS Client Interface](./internal/ports/aws.go)
- [Domain Logic](./internal/domain/account/)
- [Mock Adapters](./internal/adapters/mock/)

## License

Apache 2.0 - See [LICENSE](../LICENSE) for details
