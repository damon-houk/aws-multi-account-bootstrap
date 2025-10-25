# Hexagonal Architecture

> Concise reference for AWS Multi-Account Bootstrap v2 architecture.

## Pattern

**Domain (pure)** → **Ports (interfaces)** → **Adapters (implementations)**

**Purpose**: Testing without AWS credentials (not for multi-cloud abstraction)

## Key Decision: AWS-Specific Design

- This tool is **AWS-only** (not multi-cloud)
- Azure/GCP have different multi-account patterns - they need separate tools
- We use hexagonal for **testing**, not for cloud abstraction

## Structure

```
go/
├── internal/
│   ├── ports/              # INTERFACES (contracts)
│   │   └── aws.go          # AWSClient interface (AWS-specific)
│   │
│   ├── domain/             # BUSINESS LOGIC (pure Go)
│   │   └── account/
│   │       ├── naming.go   # Account naming conventions
│   │       └── orchestration.go  # Account creation workflow
│   │
│   └── adapters/           # IMPLEMENTATIONS
│       ├── aws/            # Real AWS SDK adapter
│       ├── mock/           # Test doubles
│       └── github/         # GitHub API adapter
```

## Components

### Ports (Interfaces)

Define contracts between domain and infrastructure. Deliberately AWS-specific (not cloud-agnostic).

```go
// ports/aws.go
type AWSClient interface {
    CreateAccount(ctx context.Context, req AWSCreateAccountRequest) (string, error)
    BootstrapCDK(ctx context.Context, accountID, region string) error
    CreateBudget(ctx context.Context, req AWSCreateBudgetRequest) error
}
```

### Domain (Business Logic)

Pure Go with zero infrastructure dependencies.

```go
// domain/account/naming.go
func GenerateAccountName(projectCode string, env Environment) string {
    return fmt.Sprintf("%s_%s", projectCode, strings.ToUpper(string(env)))
}
```

### Adapters (Implementations)

**Mock** (testing):
```go
// adapters/mock/aws.go - Returns fake data, <100ms, no AWS credentials
```

**Real** (✅ Complete):
```go
// adapters/aws/ - Uses AWS SDK v2 (Organizations, IAM, STS, Budgets, etc.)
```

## Testing

**Unit tests** (fast, no credentials):
```bash
make test  # <100ms, uses mocks
```

**Integration tests** (optional, requires AWS):
```bash
# Not yet implemented
```

## Benefits

- **Fast tests** - <100ms, no network calls
- **No credentials needed** - Developers can test locally
- **Clear separation** - Business logic separate from AWS SDK
- **Maintainable** - Easy to change business rules or upgrade SDK

## What This is NOT

**NOT multi-cloud abstraction:**
- AWS Organizations ≠ Azure Management Groups ≠ GCP Folders
- AWS CDK ≠ Azure ARM ≠ GCP Deployment Manager
- We use hexagonal for **testing**, not for multi-cloud abstraction

**If you need Azure/GCP**: Build separate tools. Each cloud is different - embrace it.

## See Also

- [Go v2 README](../../go/README.md)
- [AWS Adapter](../../go/internal/adapters/aws/README.md)
- [GitHub Adapter](../../go/internal/adapters/github/README.md)
