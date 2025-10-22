package github

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/go-github/v67/github"

	"github.com/damonallison/aws-multi-account-bootstrap/v2/internal/ports"
)

// CreateEnvironment creates a deployment environment.
//
// This is idempotent - calling multiple times updates the environment settings.
func (c *Client) CreateEnvironment(ctx context.Context, req ports.GitHubCreateEnvironmentRequest) error {
	// Validate inputs
	if req.Org == "" {
		return errors.New("organization is required")
	}
	if req.Repo == "" {
		return errors.New("repository name is required")
	}
	if req.Environment == "" {
		return errors.New("environment name is required")
	}

	// Build environment configuration
	envReq := &github.CreateUpdateEnvironment{
		// Note: We can't set wait_timer or prevent_self_review via API currently
		// These need to be configured via GitHub UI
	}

	// Configure reviewers if specified
	if req.RequireReviewers && len(req.Reviewers) > 0 {
		reviewers := make([]*github.EnvReviewers, len(req.Reviewers))
		for i, reviewer := range req.Reviewers {
			reviewers[i] = &github.EnvReviewers{
				Type: github.String("User"),
				ID:   nil, // Will be looked up by GitHub using login
			}
			// Note: The GitHub API requires reviewer IDs, not usernames
			// For simplicity, we'll need to look up each user
			user, _, err := c.client.Users.Get(ctx, reviewer)
			if err != nil {
				return fmt.Errorf("failed to get user %s: %w", reviewer, err)
			}
			reviewers[i].ID = user.ID
		}
		envReq.Reviewers = reviewers
	}

	// Create or update the environment
	_, _, err := c.client.Repositories.CreateUpdateEnvironment(
		ctx,
		req.Org,
		req.Repo,
		req.Environment,
		envReq,
	)
	if err != nil {
		return fmt.Errorf("failed to create/update environment: %w", err)
	}

	// If we need deployment branch policies, we'd configure them here
	// For now, we allow all branches to deploy to the environment

	return nil
}
