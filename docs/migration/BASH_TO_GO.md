# Migration Guide: Bash v1 to Go v2

This guide helps you migrate from the bash v1 implementation to the Go v2 implementation.

## Status

**v1 (bash)**: Maintenance mode - Stable, production-ready, no new features
**v2 (Go)**: Active development - Not yet feature-complete

## When to Migrate

### Stick with v1 if:
- ✅ You have existing v1 deployments
- ✅ You need stability
- ✅ The bash scripts meet your needs
- ✅ You want to avoid churn

### Consider v2 if:
- 🚧 You want strong typing
- 🚧 You want better error messages
- 🚧 You want multi-platform frontends (web/mobile/desktop)
- 🚧 You want to contribute to v2 development

**Current recommendation:** Stick with v1 until v2 reaches feature parity.

## Feature Comparison

| Feature | v1 (Bash) | v2 (Go) |
|---------|-----------|---------|
| Account Creation | ✅ Yes | 🚧 In Progress |
| AWS Organizations | ✅ Yes | 🚧 In Progress |
| GitHub CI/CD | ✅ Yes | ❌ Not Yet |
| CDK Bootstrap | ✅ Yes | ❌ Not Yet |
| Billing Alerts | ✅ Yes | ❌ Not Yet |
| Configuration System | ✅ Yes (YAML/JSON/env) | ❌ Not Yet |
| Interactive Mode | ✅ Yes | ❌ Not Yet |
| Dry Run Mode | ✅ Yes | ❌ Not Yet |
| Template Browser | ✅ Yes | ❌ Not Yet |
| Web UI | ❌ No | 🎯 Planned |
| Mobile App | ❌ No | 🎯 Planned |
| Type Safety | ❌ No | ✅ Yes |
| Fast Tests | ⚠️ Moderate | ✅ <100ms |

Legend:
- ✅ Implemented
- 🚧 In Progress
- 🎯 Planned
- ❌ Not Available
- ⚠️ Limited

## Architecture Differences

### v1 (Bash)

```
bash/
├── scripts/
│   ├── setup-complete-project.sh      # Main orchestrator
│   ├── create-project-accounts.sh     # AWS Organizations
│   ├── bootstrap-cdk.sh               # CDK bootstrap
│   ├── setup-github-cicd.sh           # GitHub Actions
│   └── setup-billing-alerts.sh        # AWS Budgets
└── lib/
    ├── config-manager.sh              # Configuration
    └── prerequisite-checker.sh        # Dependencies
```

**Characteristics:**
- Procedural scripts
- Shell-based orchestration
- Direct AWS CLI calls
- Simple configuration files

### v2 (Go)

```
go/
├── cmd/
│   └── aws-bootstrap/               # CLI entry point
├── internal/
│   ├── ports/                       # Interfaces (AWS-specific)
│   ├── domain/                      # Business logic
│   └── adapters/                    # Implementations
│       ├── aws/                     # Real AWS SDK
│       ├── mock/                    # Test doubles
│       └── github/                  # GitHub API
└── pkg/                             # Public libraries
```

**Characteristics:**
- Hexagonal Architecture
- Strong typing
- Testable without AWS credentials
- Single binary distribution

## Migration Path

### Phase 1: Install v2 (TODO)

```bash
# Download binary
curl -L https://github.com/.../releases/latest/download/aws-bootstrap -o aws-bootstrap
chmod +x aws-bootstrap

# Or build from source
cd go
make build
sudo cp bin/aws-bootstrap /usr/local/bin/
```

### Phase 2: Export v1 Configuration

```bash
# v1 uses config files
cat .aws-bootstrap.yml
```

Output:
```yaml
projectCode: TPA
emailPrefix: user@example.com
organizationUnitId: ou-813y-8teevv2l
githubOrg: myorg
githubRepo: myrepo
```

### Phase 3: Run v2 (TODO)

```bash
# v2 will support similar configuration
aws-bootstrap setup \
  --project-code TPA \
  --email-prefix user@example.com \
  --ou-id ou-813y-8teevv2l \
  --github-org myorg \
  --github-repo myrepo
```

### Phase 4: Verify

```bash
# Check accounts were created
aws organizations list-accounts

# Check GitHub Actions OIDC
gh api /repos/myorg/myrepo/actions/oidc/customization/sub
```

## Configuration Mapping

### v1 Configuration File

```yaml
# .aws-bootstrap.yml (v1)
projectCode: TPA
emailPrefix: user@example.com
organizationUnitId: ou-813y-8teevv2l
githubOrg: myorg
githubRepo: myrepo
awsRegion: us-east-1
environments:
  - dev
  - staging
  - prod
billingAlerts:
  enabled: true
  monthlyLimit: 25
  alertThreshold: 15
```

### v2 Configuration (TODO)

```go
// config.go (v2)
type Config struct {
    ProjectCode         string
    EmailPrefix         string
    OrganizationUnitID  string
    GitHubOrg           string
    GitHubRepo          string
    Region              string
    Environments        []Environment
    BillingConfig       *BillingConfig
}
```

## CLI Command Mapping

### v1 Commands

```bash
# Setup everything
bash/scripts/setup-complete-project.sh

# Setup just accounts
bash/scripts/create-project-accounts.sh

# Setup just GitHub
bash/scripts/setup-github-cicd.sh

# Dry run
BOOTSTRAP_DRY_RUN=true bash/scripts/setup-complete-project.sh
```

### v2 Commands (TODO)

```bash
# Setup everything
aws-bootstrap setup --all

# Setup just accounts
aws-bootstrap setup accounts

# Setup just GitHub
aws-bootstrap setup github

# Dry run
aws-bootstrap setup --all --dry-run
```

## Testing Differences

### v1 Tests

```bash
# Run bash tests
cd bash/tests
./test-config-simple.sh
./test-mock-adapters.sh
```

**Characteristics:**
- Shell script tests
- Mock bash functions
- ~30 second execution

### v2 Tests

```bash
# Run Go tests
cd go
make test
```

**Characteristics:**
- Go test framework
- Mock adapters (hexagonal architecture)
- <100ms execution
- Race detection enabled

## Rollback Strategy

If v2 doesn't work, rollback is simple:

```bash
# v1 is still in bash/ directory
cd bash
./scripts/setup-complete-project.sh
```

Both versions can coexist in the monorepo.

## Contributing

### v1 Contributions
- Bug fixes only
- Critical security patches
- No new features

### v2 Contributions
- All new features
- Architecture improvements
- Multi-platform frontends

## Timeline

**Current Status (2025-10)**
- ✅ Monorepo structure
- ✅ Go foundation with hexagonal architecture
- ✅ Domain logic (naming, orchestration)
- ✅ Mock adapters for testing
- 🚧 Real AWS adapter
- 🚧 GitHub adapter
- 🚧 CLI application

**Next Milestones**
1. **v2.0.0-beta** - Feature parity with v1
2. **v2.0.0** - Stable release
3. **v2.1.0** - Web UI
4. **v2.2.0** - Mobile app

## FAQ

### Can I use both v1 and v2?

Yes! The monorepo structure allows both to coexist. v1 is in `bash/`, v2 is in `go/`.

### When will v2 be stable?

Target: Q1 2026 for v2.0.0 stable release.

### Will v1 be removed?

No immediate plans. v1 will stay in maintenance mode indefinitely.

### How do I know which version I'm using?

```bash
# v1
bash/scripts/setup-complete-project.sh --version

# v2
aws-bootstrap version
```

### Can I migrate incrementally?

Yes! You can use v1 for some operations and v2 for others. They operate on the same AWS resources.

### What if I find a bug in v2?

Report it: https://github.com/damon-houk/aws-multi-account-bootstrap/issues

Include:
- Version (v1 or v2)
- Steps to reproduce
- Expected vs actual behavior

## Getting Help

- **Documentation**: See [go/README.md](../../go/README.md)
- **Issues**: https://github.com/damon-houk/aws-multi-account-bootstrap/issues
- **Discussions**: https://github.com/damon-houk/aws-multi-account-bootstrap/discussions

## See Also

- [Hexagonal Architecture](../architecture/HEXAGONAL_ARCHITECTURE.md)
- [Go v2 README](../../go/README.md)
- [Bash v1 README](../../bash/README.md)
- [Root README](../../README.md)
