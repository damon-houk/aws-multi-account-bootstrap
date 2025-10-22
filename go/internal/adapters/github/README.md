# GitHub Adapter

This package implements the `ports.GitHubClient` interface using the go-github SDK.

## Overview

The GitHub adapter provides real GitHub API integrations for:
- **Repositories** - Creation, deletion, and existence checks
- **Branch Protection** - Configure branch protection rules
- **Secrets & Variables** - Manage repository and environment secrets/variables
- **Environments** - Create deployment environments with reviewers
- **Workflows** - Create and enable GitHub Actions workflows
- **OIDC** - Configure OIDC for cloud provider authentication
- **Git Operations** - Initialize local repos and push to remote
- **Releases** - Create releases and tags
- **Authentication** - User info and authentication checks

## Usage

### Basic Setup

```go
package main

import (
    "context"
    "fmt"
    "log"
    "os"

    "github.com/damonallison/aws-multi-account-bootstrap/v2/internal/adapters/github"
)

func main() {
    ctx := context.Background()

    // Get GitHub token from environment
    token := os.Getenv("GITHUB_TOKEN")
    if token == "" {
        log.Fatal("GITHUB_TOKEN environment variable is required")
    }

    // Create GitHub client
    client, err := github.NewClient(ctx, token)
    if err != nil {
        log.Fatalf("Failed to create GitHub client: %v", err)
    }

    // Get current user
    user, err := client.GetCurrentUser(ctx)
    if err != nil {
        log.Fatalf("Failed to get current user: %v", err)
    }

    fmt.Printf("Authenticated as: %s\n", user)
}
```

### Creating a Repository

```go
// Create a new repository
req := ports.GitHubCreateRepoRequest{
    Org:         "myorg",
    Name:        "myrepo",
    Visibility:  "private",
    Description: "My awesome project",
}

repoURL, err := client.CreateRepository(ctx, req)
if err != nil {
    log.Fatalf("Failed to create repository: %v", err)
}

fmt.Printf("Repository created: %s\n", repoURL)
```

### Setting Up Branch Protection

```go
// Protect the main branch
req := ports.GitHubBranchProtectionRequest{
    Org:            "myorg",
    Repo:           "myrepo",
    Branch:         "main",
    RequireReviews: 1,
    RequireChecks:  true,
    RequiredChecks: []string{"test", "lint", "build"},
}

err := client.SetupBranchProtection(ctx, req)
if err != nil {
    log.Fatalf("Failed to setup branch protection: %v", err)
}
```

### Managing Secrets

```go
// Set a repository secret
err := client.SetRepositorySecret(ctx, "myorg", "myrepo", "AWS_ACCOUNT_ID", "123456789012")
if err != nil {
    log.Fatalf("Failed to set secret: %v", err)
}

// Set a repository variable (non-secret)
err = client.SetRepositoryVariable(ctx, "myorg", "myrepo", "AWS_REGION", "us-east-1")
if err != nil {
    log.Fatalf("Failed to set variable: %v", err)
}

// Set an environment secret
err = client.SetEnvironmentSecret(ctx, "myorg", "myrepo", "production", "API_KEY", "secret123")
if err != nil {
    log.Fatalf("Failed to set environment secret: %v", err)
}
```

### Creating Environments

```go
// Create a production environment with reviewers
req := ports.GitHubCreateEnvironmentRequest{
    Org:              "myorg",
    Repo:             "myrepo",
    Environment:      "production",
    RequireReviewers: true,
    Reviewers:        []string{"admin1", "admin2"},
}

err := client.CreateEnvironment(ctx, req)
if err != nil {
    log.Fatalf("Failed to create environment: %v", err)
}
```

### Creating Workflows

```go
// Create a deployment workflow
workflowContent := `
name: Deploy
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Deploy
        run: echo "Deploying..."
`

req := ports.GitHubCreateWorkflowRequest{
    Org:             "myorg",
    Repo:            "myrepo",
    WorkflowName:    "deploy.yml",
    WorkflowContent: workflowContent,
    CommitMessage:   "Add deployment workflow",
}

err := client.CreateWorkflow(ctx, req)
if err != nil {
    log.Fatalf("Failed to create workflow: %v", err)
}
```

### Setting Up OIDC

```go
// Configure OIDC for AWS
req := ports.GitHubOIDCSetupRequest{
    Org:           "myorg",
    Repo:          "myrepo",
    CloudProvider: "aws",
    RoleARN:       "arn:aws:iam::123456789012:role/GitHubActionsRole",
    Environment:   "production",
}

err := client.SetupOIDC(ctx, req)
if err != nil {
    log.Fatalf("Failed to setup OIDC: %v", err)
}
```

### Initializing a Local Repository

```go
// Initialize local git repo
err := client.InitLocalRepo(ctx, "/path/to/repo", "https://github.com/myorg/myrepo.git", "main")
if err != nil {
    log.Fatalf("Failed to initialize repo: %v", err)
}

// Push to remote
err = client.Push(ctx, "/path/to/repo", "main", false)
if err != nil {
    log.Fatalf("Failed to push: %v", err)
}
```

### Creating Releases

```go
// Create a release
req := ports.GitHubCreateReleaseRequest{
    Org:        "myorg",
    Repo:       "myrepo",
    TagName:    "v1.0.0",
    Name:       "Version 1.0.0",
    Body:       "First stable release",
    Prerelease: false,
}

err := client.CreateRelease(ctx, req)
if err != nil {
    log.Fatalf("Failed to create release: %v", err)
}
```

## Configuration

### GitHub Token

The GitHub client requires a Personal Access Token or GitHub App token with appropriate permissions:

**Required Scopes**:
- `repo` - Full control of private repositories
- `workflow` - Update GitHub Actions workflows
- `admin:org` - Full control of organizations (for org repositories)

**Creating a Token**:
1. Go to GitHub Settings → Developer settings → Personal access tokens
2. Generate new token (classic)
3. Select the required scopes above
4. Save the token securely

**Using the Token**:
```bash
export GITHUB_TOKEN="ghp_your_token_here"
```

## Architecture

This adapter follows **Hexagonal Architecture** (Ports & Adapters):

```
┌─────────────────────────────────────────┐
│     Domain Logic (internal/domain)      │
│   Pure business rules, no GitHub code   │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│   Port Interface (ports.GitHubClient)   │
│   Defines the contract for GitHub ops   │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│     GitHub Adapter (this package)       │
│   Implements port using go-github SDK   │
└─────────────────────────────────────────┘
```

**Benefits**:
- Domain logic doesn't depend on GitHub SDK
- Easy to test with mock adapter
- Can swap implementations (e.g., GitLab, Bitbucket)
- Clear separation of concerns

## Implementation Details

### Secret Encryption

Secrets are encrypted using **NaCl box** (libsodium) before being sent to GitHub:

```go
// Secrets are automatically encrypted by the adapter
err := client.SetRepositorySecret(ctx, "myorg", "myrepo", "SECRET_NAME", "secret-value")
// The value is encrypted using GitHub's public key before transmission
```

### Idempotency

Most operations are idempotent - calling them multiple times with the same parameters is safe:

- ✅ `CreateRepository` - Returns existing repo URL if it exists
- ✅ `SetRepositorySecret` - Updates secret if it already exists
- ✅ `SetRepositoryVariable` - Updates variable if it already exists
- ✅ `SetEnvironmentSecret` - Updates secret if it already exists
- ✅ `CreateEnvironment` - Updates environment if it already exists
- ✅ `CreateWorkflow` - Updates workflow file if it already exists
- ✅ `SetupBranchProtection` - Updates protection rules
- ⚠️  `DeleteRepository` - Destructive operation (not idempotent)
- ⚠️  `CreateRelease` - Creates a new release each time

### Error Handling

All methods return standard Go errors. Use `errors.Is()` or `errors.As()` to check for specific error types:

```go
repoURL, err := client.CreateRepository(ctx, req)
if err != nil {
    // Handle error
    log.Printf("Failed to create repository: %v", err)
    return err
}
```

### Rate Limiting

GitHub API has rate limits:
- **Authenticated requests**: 5,000 requests per hour
- **Unauthenticated**: 60 requests per hour

The go-github client automatically handles rate limiting by waiting when limits are reached.

## Testing

For testing without GitHub credentials, use the mock adapter:

```go
import "github.com/damonallison/aws-multi-account-bootstrap/v2/internal/adapters/mock"

// Use mock adapter for testing
mockClient := mock.NewGitHubClient()
```

For integration tests with real GitHub:

```go
// Set up test GitHub account and token
ctx := context.Background()
token := os.Getenv("GITHUB_TEST_TOKEN")
client, err := github.NewClient(ctx, token)
// ... run integration tests
```

## Implementation Files

- `client.go` - Main client with authentication
- `repositories.go` - Repository operations
- `branches.go` - Branch protection
- `secrets.go` - Secrets and variables (with encryption)
- `environments.go` - Environment operations
- `workflows.go` - Workflow and release operations
- `git.go` - Git operations and OIDC setup

## Related Documentation

- [go-github Documentation](https://pkg.go.dev/github.com/google/go-github/v67/github)
- Bash v1 GitHub Adapters (`bash/scripts/adapters/github/`) - Original implementation
- [Port Interface](../../ports/github.go) - Interface this adapter implements
- [Mock Adapter](../mock/) - Testing implementation

## License

See [LICENSE](../../../../LICENSE) in the repository root.