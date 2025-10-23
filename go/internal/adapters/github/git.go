package github

import (
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"

	"github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/ports"
)

// InitLocalRepo initializes a local git repository and configures remote.
//
// This creates a git repository, sets up the remote, and creates an initial commit.
func (c *Client) InitLocalRepo(ctx context.Context, repoPath, remoteURL, defaultBranch string) error {
	if repoPath == "" {
		return errors.New("repository path is required")
	}
	if remoteURL == "" {
		return errors.New("remote URL is required")
	}
	if defaultBranch == "" {
		defaultBranch = "main" // Default
	}

	// Create directory if it doesn't exist
	if err := os.MkdirAll(repoPath, 0755); err != nil {
		return fmt.Errorf("failed to create directory: %w", err)
	}

	// Initialize git repository
	if err := runGitCommand(ctx, repoPath, "init", "-b", defaultBranch); err != nil {
		return fmt.Errorf("failed to initialize git repository: %w", err)
	}

	// Add remote
	if err := runGitCommand(ctx, repoPath, "remote", "add", "origin", remoteURL); err != nil {
		return fmt.Errorf("failed to add remote: %w", err)
	}

	// Create .gitignore if it doesn't exist
	gitignorePath := filepath.Join(repoPath, ".gitignore")
	if _, err := os.Stat(gitignorePath); os.IsNotExist(err) {
		gitignoreContent := "# Dependencies\nnode_modules/\n\n# Build outputs\ndist/\nbuild/\n\n# Environment\n.env\n.env.local\n"
		if err := os.WriteFile(gitignorePath, []byte(gitignoreContent), 0644); err != nil {
			return fmt.Errorf("failed to create .gitignore: %w", err)
		}
	}

	// Add initial files
	if err := runGitCommand(ctx, repoPath, "add", "."); err != nil {
		return fmt.Errorf("failed to add files: %w", err)
	}

	// Create initial commit
	if err := runGitCommand(ctx, repoPath, "commit", "-m", "Initial commit", "--allow-empty"); err != nil {
		return fmt.Errorf("failed to create initial commit: %w", err)
	}

	return nil
}

// Push pushes local repository to remote.
func (c *Client) Push(ctx context.Context, repoPath, branch string, force bool) error {
	if repoPath == "" {
		return errors.New("repository path is required")
	}
	if branch == "" {
		branch = "main" // Default
	}

	args := []string{"push", "origin", branch}
	if force {
		args = append(args, "--force")
	}

	if err := runGitCommand(ctx, repoPath, args...); err != nil {
		return fmt.Errorf("failed to push: %w", err)
	}

	return nil
}

// SetupOIDC configures OIDC trust for cloud provider authentication.
//
// For GitHub, this primarily involves creating repository secrets for the cloud provider role ARN.
// The actual OIDC configuration is done in workflow files.
func (c *Client) SetupOIDC(ctx context.Context, req ports.GitHubOIDCSetupRequest) error {
	if req.Org == "" {
		return errors.New("organization is required")
	}
	if req.Repo == "" {
		return errors.New("repository name is required")
	}
	if req.CloudProvider == "" {
		return errors.New("cloud provider is required")
	}
	if req.RoleARN == "" {
		return errors.New("role ARN is required")
	}

	// Create secret name based on cloud provider and environment
	var secretName string
	if req.Environment != "" {
		secretName = fmt.Sprintf("%s_ROLE_ARN_%s",
			normalizeCloudProvider(req.CloudProvider),
			normalizeEnvironment(req.Environment),
		)

		// Set as environment secret
		if err := c.SetEnvironmentSecret(ctx, req.Org, req.Repo, req.Environment, secretName, req.RoleARN); err != nil {
			return fmt.Errorf("failed to set environment secret: %w", err)
		}
	} else {
		secretName = fmt.Sprintf("%s_ROLE_ARN", normalizeCloudProvider(req.CloudProvider))

		// Set as repository secret
		if err := c.SetRepositorySecret(ctx, req.Org, req.Repo, secretName, req.RoleARN); err != nil {
			return fmt.Errorf("failed to set repository secret: %w", err)
		}
	}

	return nil
}

// runGitCommand runs a git command in the specified directory.
func runGitCommand(ctx context.Context, dir string, args ...string) error {
	cmd := exec.CommandContext(ctx, "git", args...)
	cmd.Dir = dir
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		return fmt.Errorf("git command failed: %w", err)
	}

	return nil
}

// normalizeCloudProvider normalizes cloud provider name for secret naming.
func normalizeCloudProvider(provider string) string {
	switch provider {
	case "aws", "AWS":
		return "AWS"
	case "azure", "Azure", "AZURE":
		return "AZURE"
	case "gcp", "GCP":
		return "GCP"
	default:
		return provider
	}
}

// normalizeEnvironment normalizes environment name for secret naming.
func normalizeEnvironment(env string) string {
	switch env {
	case "dev", "development":
		return "DEV"
	case "staging", "stage":
		return "STAGING"
	case "prod", "production":
		return "PROD"
	default:
		return env
	}
}