package ports

import "context"

// GitHubClient defines the contract for GitHub/VCS operations needed for CI/CD setup.
//
// This interface is DELIBERATELY GitHub-SPECIFIC. We're not pretending to be
// VCS-agnostic because:
//   - GitHub Actions is fundamentally different from GitLab CI or Jenkins
//   - GitHub's OIDC integration is unique to GitHub
//   - GitHub Environments and branch protection are GitHub-specific
//
// Why keep this interface?
//   - TESTING: Mock implementation enables fast tests without GitHub credentials
//   - SEPARATION: Business logic (domain) stays separate from GitHub SDK details
//   - CLARITY: Makes dependencies explicit
//
// This is Hexagonal Architecture for TESTING, not for multi-VCS abstraction.
//
// If you need GitLab or Bitbucket: Build separate tools. Don't try to abstract them.
type GitHubClient interface {
	// Repository Management

	// CreateRepository creates a new GitHub repository.
	//
	// Returns the repository HTTPS clone URL.
	CreateRepository(ctx context.Context, req GitHubCreateRepoRequest) (string, error)

	// RepositoryExists checks if a repository exists.
	RepositoryExists(ctx context.Context, org, repo string) (bool, error)

	// DeleteRepository deletes a repository (use with caution!).
	DeleteRepository(ctx context.Context, org, repo string) error

	// Branch Management

	// SetupBranchProtection creates branch protection rules.
	SetupBranchProtection(ctx context.Context, req GitHubBranchProtectionRequest) error

	// GetDefaultBranch returns the default branch name (e.g., "main").
	GetDefaultBranch(ctx context.Context, org, repo string) (string, error)

	// Secrets & Configuration

	// SetRepositorySecret sets a repository-level secret.
	SetRepositorySecret(ctx context.Context, org, repo, name, value string) error

	// SetRepositoryVariable sets a repository-level variable (non-secret).
	SetRepositoryVariable(ctx context.Context, org, repo, name, value string) error

	// Environments

	// CreateEnvironment creates a deployment environment.
	CreateEnvironment(ctx context.Context, req GitHubCreateEnvironmentRequest) error

	// SetEnvironmentSecret sets an environment-level secret.
	SetEnvironmentSecret(ctx context.Context, org, repo, environment, name, value string) error

	// Workflows & CI/CD

	// CreateWorkflow creates a workflow file in the repository.
	//
	// This commits the workflow file to the default branch.
	CreateWorkflow(ctx context.Context, req GitHubCreateWorkflowRequest) error

	// EnableWorkflow enables a workflow file.
	EnableWorkflow(ctx context.Context, org, repo, workflowName string) error

	// OIDC Configuration

	// SetupOIDC configures OIDC trust for cloud provider authentication.
	//
	// This may involve creating workflow files or repository settings.
	SetupOIDC(ctx context.Context, req GitHubOIDCSetupRequest) error

	// Git Operations

	// InitLocalRepo initializes a local git repository and configures remote.
	InitLocalRepo(ctx context.Context, repoPath, remoteURL, defaultBranch string) error

	// Push pushes local repository to remote.
	Push(ctx context.Context, repoPath, branch string, force bool) error

	// Releases & Tags

	// CreateRelease creates a release/tag.
	CreateRelease(ctx context.Context, req GitHubCreateReleaseRequest) error

	// Utility Functions

	// GetCurrentUser returns the authenticated user's username.
	GetCurrentUser(ctx context.Context) (string, error)

	// IsAuthenticated checks if the client is authenticated.
	IsAuthenticated(ctx context.Context) (bool, error)

	// Metadata

	// Name returns "GitHub" (for logging/debugging).
	Name() string
}

// GitHubCreateRepoRequest contains parameters for creating a GitHub repository.
type GitHubCreateRepoRequest struct {
	Org         string // Organization or username
	Name        string // Repository name
	Visibility  string // "private", "public", or "internal"
	Description string // Repository description (optional)
}

// GitHubBranchProtectionRequest contains parameters for branch protection.
type GitHubBranchProtectionRequest struct {
	Org            string   // Organization or username
	Repo           string   // Repository name
	Branch         string   // Branch to protect (e.g., "main")
	RequireReviews int      // Number of required reviews (0 to disable)
	RequireChecks  bool     // Require status checks to pass
	RequiredChecks []string // List of required status check names (optional)
}

// GitHubCreateEnvironmentRequest contains parameters for creating a deployment environment.
type GitHubCreateEnvironmentRequest struct {
	Org              string   // Organization or username
	Repo             string   // Repository name
	Environment      string   // Environment name (e.g., "production")
	RequireReviewers bool     // Require manual approval
	Reviewers        []string // List of reviewer usernames (optional)
}

// GitHubCreateWorkflowRequest contains parameters for creating a workflow file.
type GitHubCreateWorkflowRequest struct {
	Org            string // Organization or username
	Repo           string // Repository name
	WorkflowName   string // Workflow file name (e.g., "deploy.yml")
	WorkflowContent string // Content of the workflow file
	CommitMessage  string // Commit message (optional)
	Branch         string // Branch to commit to (optional, defaults to default branch)
}

// GitHubOIDCSetupRequest contains parameters for OIDC configuration.
type GitHubOIDCSetupRequest struct {
	Org           string // Organization or username
	Repo          string // Repository name
	CloudProvider string // Cloud provider (e.g., "aws", "azure", "gcp")
	RoleARN       string // ARN or identifier of the cloud role
	Environment   string // Environment to limit scope (optional)
}

// GitHubCreateReleaseRequest contains parameters for creating a release.
type GitHubCreateReleaseRequest struct {
	Org        string // Organization or username
	Repo       string // Repository name
	TagName    string // Tag name (e.g., "v1.0.0")
	Name       string // Human-readable release name
	Body       string // Release notes (optional)
	Prerelease bool   // Is this a prerelease?
}