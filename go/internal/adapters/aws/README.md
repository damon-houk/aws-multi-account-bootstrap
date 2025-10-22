# AWS Adapter

This package implements the `ports.AWSClient` interface using AWS SDK for Go v2.

## Overview

The AWS adapter provides real AWS service integrations for:
- **AWS Organizations** - Multi-account management
- **AWS IAM** - OIDC providers and roles for GitHub Actions
- **AWS STS** - Temporary credentials and role assumption
- **AWS Budgets** - Cost management and budget alerts
- **AWS CloudWatch** - Billing alarms
- **AWS SNS** - Email notifications
- **AWS CDK** - Infrastructure bootstrapping

## Usage

### Basic Setup

```go
package main

import (
    "context"
    "fmt"
    "log"

    "github.com/damonallison/aws-multi-account-bootstrap/v2/internal/adapters/aws"
    "github.com/damonallison/aws-multi-account-bootstrap/v2/internal/ports"
)

func main() {
    ctx := context.Background()

    // Create AWS client with default credentials
    client, err := aws.NewClient(ctx)
    if err != nil {
        log.Fatalf("Failed to create AWS client: %v", err)
    }

    // Get current AWS identity
    identity, err := client.GetCallerIdentity(ctx)
    if err != nil {
        log.Fatalf("Failed to get caller identity: %v", err)
    }

    fmt.Printf("Authenticated as: %s (%s)\n", identity.ARN, identity.AccountID)
}
```

### Creating an AWS Account

```go
// Create a new AWS account in an organization
req := ports.AWSCreateAccountRequest{
    Name:      "MyCompany-Dev",
    Email:     "aws+dev@mycompany.com",
    OrgUnitID: "ou-xxxx-yyyyyyyy",
    RoleName:  "OrganizationAccountAccessRole",
}

accountID, err := client.CreateAccount(ctx, req)
if err != nil {
    log.Fatalf("Failed to create account: %v", err)
}

fmt.Printf("Account created: %s\n", accountID)
```

### Setting up GitHub Actions OIDC

```go
// Create OIDC provider for GitHub Actions
err := client.CreateOIDCProviderForGitHub(ctx, accountID)
if err != nil {
    log.Fatalf("Failed to create OIDC provider: %v", err)
}

// Create IAM role for GitHub Actions
roleReq := ports.AWSCreateRoleRequest{
    AccountID:        accountID,
    RoleName:         "GitHubActionsDeployRole",
    GitHubOrg:        "myorg",
    GitHubRepo:       "myrepo",
    PolicyARNs:       []string{"arn:aws:iam::aws:policy/AdministratorAccess"},
    AllowAllBranches: false, // Only main and develop
}

roleARN, err := client.CreateGitHubActionsRole(ctx, roleReq)
if err != nil {
    log.Fatalf("Failed to create role: %v", err)
}

fmt.Printf("Role created: %s\n", roleARN)
```

### Creating a Budget

```go
// Create a monthly budget with alerts
budgetReq := ports.AWSCreateBudgetRequest{
    AccountID:     accountID,
    BudgetName:    "MyCompany-Dev-Monthly",
    LimitAmount:   25.00,
    AlertAmount:   15.00,
    Email:         "billing@mycompany.com",
    AlertPercents: []int{80, 90, 100},
}

err := client.CreateBudget(ctx, budgetReq)
if err != nil {
    log.Fatalf("Failed to create budget: %v", err)
}
```

### Creating Billing Alarms

```go
// Create SNS topic for alerts
topicARN, err := client.CreateSNSTopic(ctx, accountID, "BillingAlerts")
if err != nil {
    log.Fatalf("Failed to create SNS topic: %v", err)
}

// Subscribe email to topic
err = client.SubscribeEmailToSNSTopic(ctx, topicARN, "billing@mycompany.com")
if err != nil {
    log.Fatalf("Failed to subscribe email: %v", err)
}

// Create CloudWatch billing alarm
alarmReq := ports.AWSCreateBillingAlarmRequest{
    AccountID: accountID,
    AlarmName: "BillingAlert-15USD",
    Threshold: 15.00,
    TopicARN:  topicARN,
}

err = client.CreateBillingAlarm(ctx, alarmReq)
if err != nil {
    log.Fatalf("Failed to create billing alarm: %v", err)
}
```

### Bootstrapping CDK

```go
// Bootstrap AWS CDK in an account
err := client.BootstrapCDK(ctx, accountID, "us-east-1", trustAccountID)
if err != nil {
    log.Fatalf("Failed to bootstrap CDK: %v", err)
}
```

### Assuming a Role

```go
// Assume a role in another account
roleARN := "arn:aws:iam::123456789012:role/MyRole"
creds, err := client.AssumeRole(ctx, roleARN, "my-session")
if err != nil {
    log.Fatalf("Failed to assume role: %v", err)
}

fmt.Printf("Temporary credentials expire at: %s\n", creds.Expiration)
```

## Configuration

The AWS client uses the standard AWS SDK credential chain:

1. **Environment variables**:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `AWS_SESSION_TOKEN` (optional)
   - `AWS_REGION`

2. **Shared credentials file** (`~/.aws/credentials`):
   ```ini
   [default]
   aws_access_key_id = YOUR_KEY
   aws_secret_access_key = YOUR_SECRET
   ```

3. **IAM role** (when running on AWS infrastructure):
   - EC2 instance profiles
   - ECS task roles
   - Lambda execution roles

4. **AWS SSO**:
   ```bash
   aws sso login --profile my-profile
   export AWS_PROFILE=my-profile
   ```

## Requirements

- **AWS SDK for Go v2** (installed via go.mod)
- **AWS CLI** (for SSO authentication)
- **AWS CDK CLI** (for CDK bootstrap operations)
  ```bash
  npm install -g aws-cdk
  ```

## IAM Permissions

The AWS client requires the following IAM permissions:

### Organizations
- `organizations:CreateAccount`
- `organizations:DescribeCreateAccountStatus`
- `organizations:ListAccounts`
- `organizations:ListParents`
- `organizations:MoveAccount`

### IAM
- `iam:CreateOpenIDConnectProvider`
- `iam:CreateRole`
- `iam:UpdateAssumeRolePolicy`
- `iam:AttachRolePolicy`

### STS
- `sts:AssumeRole`
- `sts:GetCallerIdentity`

### Budgets
- `budgets:CreateBudget`

### CloudWatch
- `cloudwatch:PutMetricAlarm`

### SNS
- `sns:CreateTopic`
- `sns:Subscribe`
- `sns:ListSubscriptionsByTopic`

## Architecture

This adapter follows **Hexagonal Architecture** (Ports & Adapters):

```
┌─────────────────────────────────────────┐
│     Domain Logic (internal/domain)      │
│   Pure business rules, no AWS code     │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│      Port Interface (ports.AWSClient)   │
│   Defines the contract for AWS ops     │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│     AWS Adapter (this package)          │
│   Implements port using AWS SDK v2      │
└─────────────────────────────────────────┘
```

**Benefits**:
- Domain logic doesn't depend on AWS SDK
- Easy to test with mock adapter
- Can swap implementations (e.g., LocalStack for testing)
- Clear separation of concerns

## Testing

For testing without AWS credentials, use the mock adapter:

```go
import "github.com/damonallison/aws-multi-account-bootstrap/v2/internal/adapters/mock"

// Use mock adapter for testing
mockClient := mock.NewAWSClient()
```

For integration tests with real AWS:

```go
// Set up test AWS account and credentials
ctx := context.Background()
client, err := aws.NewClient(ctx)
// ... run integration tests
```

## Error Handling

All methods return standard Go errors. Use `errors.Is()` or `errors.As()` to check for specific error types:

```go
accountID, err := client.CreateAccount(ctx, req)
if err != nil {
    // Handle error
    log.Printf("Failed to create account: %v", err)
    return err
}
```

## Idempotency

Most operations are idempotent - calling them multiple times with the same parameters is safe:

- ✅ `CreateAccount` - Returns existing account if name matches
- ✅ `CreateOIDCProviderForGitHub` - Succeeds if provider exists
- ✅ `CreateGitHubActionsRole` - Updates trust policy if role exists
- ✅ `CreateSNSTopic` - Returns existing topic ARN
- ✅ `SubscribeEmailToSNSTopic` - No-op if subscription exists
- ✅ `CreateBudget` - Succeeds if budget exists
- ✅ `BootstrapCDK` - Succeeds if already bootstrapped

## Implementation Files

- `client.go` - Main client and STS operations
- `organizations.go` - AWS Organizations (account management)
- `iam.go` - IAM and OIDC operations
- `budgets.go` - AWS Budgets and CloudWatch alarms
- `sns.go` - SNS topics and subscriptions
- `cdk.go` - CDK bootstrap operations

## Related Documentation

- [AWS SDK for Go v2 Documentation](https://aws.github.io/aws-sdk-go-v2/docs/)
- Bash v1 AWS Adapters (`bash/scripts/adapters/aws/`) - Original implementation
- [Port Interface](../../ports/aws.go) - Interface this adapter implements
- [Mock Adapter](../mock/) - Testing implementation

## License

See [LICENSE](../../../../LICENSE) in the repository root.
