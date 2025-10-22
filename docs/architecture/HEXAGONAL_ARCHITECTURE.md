# Hexagonal Architecture (Ports & Adapters)

This document explains the hexagonal architecture implementation in AWS Multi-Account Bootstrap v2.

## Overview

Hexagonal Architecture (also known as Ports and Adapters) separates business logic from infrastructure concerns. This provides testability and maintainability benefits.

## Our Implementation

### Key Decision: AWS-Specific, Not Multi-Cloud

**We are honest about our scope:**
- This tool is designed specifically for AWS
- We do NOT abstract cloud providers generically
- Azure and GCP have fundamentally different multi-account patterns
- False abstractions create complexity without value

**Why use Hexagonal Architecture then?**
- **Testing**: Mock adapters enable fast tests without AWS credentials
- **Separation**: Business logic stays separate from AWS SDK details
- **Clarity**: Makes dependencies explicit

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

### 1. Ports (Interfaces)

Ports define the contract between domain logic and external systems.

**Example: `ports/aws.go`**

```go
type AWSClient interface {
    CreateAccount(ctx context.Context, req AWSCreateAccountRequest) (string, error)
    BootstrapCDK(ctx context.Context, accountID, region, trustAccountID string) error
    CreateBudget(ctx context.Context, req AWSCreateBudgetRequest) error
    // ... AWS-specific operations
}
```

**Key Points:**
- Deliberately AWS-specific
- Not pretending to be cloud-agnostic
- Includes AWS-only concepts (CDK, Organizations, Budgets)

### 2. Domain Logic

Pure business rules with no infrastructure dependencies.

**Example: `domain/account/naming.go`**

```go
func GenerateAccountName(projectCode string, env Environment) string {
    return fmt.Sprintf("%s_%s", projectCode, strings.ToUpper(string(env)))
}

func GenerateAccountEmail(emailPrefix, projectCode string, env Environment) string {
    prefix := strings.TrimSuffix(emailPrefix, "@gmail.com")
    return fmt.Sprintf("%s+%s-%s@gmail.com",
        prefix,
        strings.ToLower(projectCode),
        strings.ToLower(string(env)))
}
```

**Key Points:**
- Zero AWS imports
- Pure Go functions
- Easily testable
- Business rules are explicit

### 3. Adapters (Implementations)

Adapters implement the port interfaces.

#### Mock Adapter (for testing)

**Example: `adapters/mock/aws.go`**

```go
type AWSClient struct {
    accounts       map[string]*mockAWSAccount
    accountsByName map[string]string
    operations     []string  // Records what was called
    nextAccountID  int64
}

func (m *AWSClient) CreateAccount(ctx context.Context, req ports.AWSCreateAccountRequest) (string, error) {
    accountID := fmt.Sprintf("%012d", m.nextAccountID)
    m.nextAccountID++

    m.accounts[accountID] = &mockAWSAccount{
        ID:    accountID,
        Name:  req.Name,
        Email: req.Email,
    }

    return accountID, nil
}
```

**Benefits:**
- Tests run in <100ms
- No AWS credentials needed
- Deterministic behavior
- Can verify business logic worked correctly

#### Real AWS Adapter (TODO)

Will use AWS SDK for Go v2:

```go
type AWSClient struct {
    orgsClient     *organizations.Client
    iamClient      *iam.Client
    budgetsClient  *budgets.Client
    // ... other AWS clients
}
```

## Testing Philosophy

### Unit Tests

Use mock adapters to test business logic in isolation:

```go
func TestCreateAllAccounts(t *testing.T) {
    // Create mock AWS client
    mockAWS := mock.NewAWSClient()

    // Configure business rules
    config := Config{
        ProjectCode: "TPA",
        EmailPrefix: "user",
        OUID:        "ou-813y-8teevv2l",
    }

    // Call domain logic
    accounts, err := CreateAllAccounts(ctx, mockAWS, config)

    // Verify results
    assert.NoError(t, err)
    assert.Len(t, accounts, 3)  // dev, staging, prod

    // Verify mock was called correctly
    ops := mockAWS.GetOperations()
    assert.Contains(t, ops, "CreateAccount(TPA_DEV, ...)")
}
```

**Results:**
- ✅ 14 tests passing
- ✅ <100ms execution time
- ✅ No AWS credentials required

### Integration Tests (Future)

Will test real AWS SDK integration:

```go
func TestAWSAdapter_CreateAccount_Integration(t *testing.T) {
    if testing.Short() {
        t.Skip("Skipping integration test")
    }

    // Use real AWS client
    awsClient := aws.NewClient(cfg)

    // Test actual AWS operations
    // ...
}
```

## Benefits

### 1. Fast Tests

```bash
$ make test
Running tests...
ok github.com/damonallison/.../account 0.096s
```

- No network calls
- No AWS API latency
- Instant feedback

### 2. Test Without Credentials

Developers can:
- Run full test suite locally
- Verify business logic
- Contribute without AWS account

### 3. Clear Separation

Business rules are explicit and separate from:
- AWS SDK quirks
- Network calls
- Rate limiting
- Authentication

### 4. Maintainability

Easy to:
- Understand what the code does
- Change business rules
- Upgrade AWS SDK version
- Add new AWS operations

## What This Is NOT

### Not Multi-Cloud Abstraction

We **deliberately** do not abstract AWS behind a generic "cloud" interface because:

1. **AWS Organizations ≠ Azure Management Groups ≠ GCP Folders**
   - Different concepts
   - Different capabilities
   - Different best practices

2. **AWS CDK ≠ Azure ARM ≠ GCP Deployment Manager**
   - Different tooling
   - Different approaches
   - Cannot be abstracted

3. **False Abstractions Create Problems**
   - Leaky abstractions
   - Lowest common denominator
   - Complexity without benefit

### Honest Engineering

We use hexagonal architecture for **testing**, not for **multi-cloud dreams**.

If you need Azure or GCP:
- Build a separate tool
- Don't try to abstract them together
- Each cloud is different - embrace it

## Evolution

As the project grows, we might add:

1. **More Ports**
   - GitHub API port
   - GitLab API port (for CI/CD)
   - Terraform Cloud API port

2. **More Adapters**
   - LocalStack adapter (for local testing)
   - Fake adapter (for demos)

3. **More Domain Logic**
   - Billing domain
   - Security domain
   - Compliance domain

But we will **never** create a generic "CloudProvider" that pretends AWS, Azure, and GCP are the same.

## References

- [Hexagonal Architecture (Alistair Cockburn)](https://alistair.cockburn.us/hexagonal-architecture/)
- [Ports & Adapters Pattern](https://herbertograca.com/2017/09/14/ports-adapters-architecture/)
- [Go Project Layout](https://github.com/golang-standards/project-layout)
- [AWS SDK for Go v2](https://aws.github.io/aws-sdk-go-v2/)

## See Also

- [Go v2 README](../../go/README.md)
- [AWS Client Port](../../go/internal/ports/aws.go)
- [Domain Logic](../../go/internal/domain/account/)
- [Mock Adapters](../../go/internal/adapters/mock/)
