# Migration Guide: Bash v1 to Go v2

> Guide for migrating from bash v1 to Go v2.

## Current Status (2025-10-25)

**v1 (bash)**: ✅ Stable, production-ready, maintenance mode only
**v2 (Go)**: 🚧 ~80% complete, active development, not yet stable

## When to Use Which Version

**Use v1 if**:
- You need stability NOW
- You have existing v1 deployments
- You want to avoid bleeding edge

**Use v2 if**:
- You want beautiful TUI wizard
- You want single binary distribution
- You want to contribute to development
- You can tolerate some rough edges

**Recommendation**: v1 for production, v2 for testing/contributions

## Feature Comparison (2025-10-25)

| Feature | v1 (Bash) | v2 (Go) |
|---------|-----------|---------|
| **Infrastructure** |||
| AWS Organizations | ✅ | ✅ Complete |
| AWS IAM / OIDC | ✅ | ✅ Complete |
| AWS Budgets | ✅ | ✅ Complete |
| CloudWatch Alarms | ✅ | ✅ Complete |
| CDK Bootstrap | ✅ | ✅ Complete |
| **GitHub** |||
| Repository Setup | ✅ | ✅ Complete |
| Branch Protection | ✅ | ✅ Complete |
| Secrets/Variables | ✅ | ✅ Complete |
| Environments | ✅ | ✅ Complete |
| Workflows | ✅ | ✅ Complete |
| **CLI/UX** |||
| Interactive TUI | ❌ Simple | ✅ Bubbletea wizard |
| Template Browser | ❌ No | ✅ 66+ templates |
| Prerequisites Check | ✅ | ✅ Complete |
| Configuration (Viper) | ⚠️ Custom | 🚧 In Progress |
| Cost Estimation | ⚠️ Static | 🔴 Partial (blocker) |
| Execution Step | ✅ | 🚧 In Progress |
| **Quality** |||
| Type Safety | ❌ | ✅ |
| Fast Tests | ⚠️ <2s | ✅ <100ms |
| Single Binary | ❌ | 🚧 Almost |

Legend: ✅ Complete | 🚧 In Progress | 🔴 Blocked | ❌ Not Available | ⚠️ Limited

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

## v2 Progress (2025-10-25)

**Completed** ✅:
- Hexagonal architecture (ports/adapters)
- AWS adapter (Organizations, IAM, STS, Budgets, CloudWatch, SNS, CDK)
- GitHub adapter (repos, branches, secrets, environments, workflows, OIDC)
- Template loader (66+ cloudonaut/widdix templates)
- Prerequisites checker
- Bubbletea TUI wizard (~80%)

**Remaining**:
- Fix template parser hang (🔴 BLOCKER)
- Complete execution step
- Integration tests
- Single binary release

**Next Release**: v2.0.0-alpha (when blocker fixed)

## FAQ

**Can both versions coexist?**
Yes. v1 in `bash/`, v2 in `go/`. Both work on same AWS resources.

**Will v1 be removed?**
No. v1 stays in maintenance indefinitely.

**When is v2 stable?**
When template parser blocker is fixed and execution step completes.

**Found a bug?**
Report: https://github.com/damon-houk/aws-multi-account-bootstrap/issues

## See Also

- [CLAUDE.md](../../CLAUDE.md) - AI assistant context (read this first!)
- [Go v2 README](../../go/README.md) - v2 status and commands
- [Hexagonal Architecture](../architecture/HEXAGONAL_ARCHITECTURE.md)
- [Bash v1 README](../../bash/README.md)
