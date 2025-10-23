package github

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/google/go-github/v67/github"

	"github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/ports"
)

// CreateRepository creates a new GitHub repository.
//
// If the repository already exists, returns its URL (idempotent).
// Returns the HTTPS clone URL.
func (c *Client) CreateRepository(ctx context.Context, req ports.GitHubCreateRepoRequest) (string, error) {
	// Validate inputs
	if req.Org == "" {
		return "", errors.New("organization is required")
	}
	if req.Name == "" {
		return "", errors.New("repository name is required")
	}
	if req.Visibility == "" {
		req.Visibility = "private" // Default to private
	}

	// Check if repository already exists
	exists, err := c.RepositoryExists(ctx, req.Org, req.Name)
	if err != nil {
		return "", fmt.Errorf("failed to check if repository exists: %w", err)
	}

	if exists {
		// Repository exists, get its URL
		repo, _, err := c.client.Repositories.Get(ctx, req.Org, req.Name)
		if err != nil {
			return "", fmt.Errorf("failed to get existing repository: %w", err)
		}
		return repo.GetCloneURL(), nil
	}

	// Determine if this is a personal or org repository
	currentUser, err := c.GetCurrentUser(ctx)
	if err != nil {
		return "", fmt.Errorf("failed to get current user: %w", err)
	}

	// Prepare repository settings
	private := req.Visibility == "private"
	autoInit := false // Don't auto-initialize with README
	hasWiki := false  // Disable wiki

	repo := &github.Repository{
		Name:        &req.Name,
		Private:     &private,
		Description: &req.Description,
		AutoInit:    &autoInit,
		HasWiki:     &hasWiki,
	}

	// Handle visibility for org repos
	if req.Visibility == "internal" {
		visibility := "internal"
		repo.Visibility = &visibility
	}

	var createdRepo *github.Repository
	if strings.EqualFold(req.Org, currentUser) {
		// Create personal repository
		createdRepo, _, err = c.client.Repositories.Create(ctx, "", repo)
	} else {
		// Create organization repository
		createdRepo, _, err = c.client.Repositories.Create(ctx, req.Org, repo)
	}

	if err != nil {
		return "", fmt.Errorf("failed to create repository: %w", err)
	}

	return createdRepo.GetCloneURL(), nil
}

// RepositoryExists checks if a repository exists.
func (c *Client) RepositoryExists(ctx context.Context, org, repo string) (bool, error) {
	if org == "" || repo == "" {
		return false, errors.New("org and repo are required")
	}

	_, resp, err := c.client.Repositories.Get(ctx, org, repo)
	if err != nil {
		// 404 means it doesn't exist
		if resp != nil && resp.StatusCode == 404 {
			return false, nil
		}
		return false, fmt.Errorf("failed to check repository existence: %w", err)
	}

	return true, nil
}

// DeleteRepository deletes a repository (use with caution!).
func (c *Client) DeleteRepository(ctx context.Context, org, repo string) error {
	if org == "" || repo == "" {
		return errors.New("org and repo are required")
	}

	_, err := c.client.Repositories.Delete(ctx, org, repo)
	if err != nil {
		return fmt.Errorf("failed to delete repository: %w", err)
	}

	return nil
}

// GetDefaultBranch returns the default branch name.
func (c *Client) GetDefaultBranch(ctx context.Context, org, repo string) (string, error) {
	if org == "" || repo == "" {
		return "", errors.New("org and repo are required")
	}

	repository, _, err := c.client.Repositories.Get(ctx, org, repo)
	if err != nil {
		return "", fmt.Errorf("failed to get repository: %w", err)
	}

	defaultBranch := repository.GetDefaultBranch()
	if defaultBranch == "" {
		return "", errors.New("repository has no default branch")
	}

	return defaultBranch, nil
}