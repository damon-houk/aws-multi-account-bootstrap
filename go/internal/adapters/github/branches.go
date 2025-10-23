package github

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/go-github/v67/github"

	"github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/ports"
)

// SetupBranchProtection creates or updates branch protection rules.
//
// This is idempotent - calling multiple times with the same settings is safe.
func (c *Client) SetupBranchProtection(ctx context.Context, req ports.GitHubBranchProtectionRequest) error {
	// Validate inputs
	if req.Org == "" {
		return errors.New("organization is required")
	}
	if req.Repo == "" {
		return errors.New("repository name is required")
	}
	if req.Branch == "" {
		return errors.New("branch name is required")
	}

	// Build protection request
	protection := &github.ProtectionRequest{
		RequiredStatusChecks: nil,
		RequiredPullRequestReviews: nil,
		EnforceAdmins: false,
		AllowForcePushes: github.Bool(false),
		AllowDeletions: github.Bool(false),
	}

	// Configure required status checks
	if req.RequireChecks && len(req.RequiredChecks) > 0 {
		checks := convertToStatusChecks(req.RequiredChecks)
		protection.RequiredStatusChecks = &github.RequiredStatusChecks{
			Strict: true, // Require branches to be up to date before merging
			Checks: &checks,
		}
	}

	// Configure pull request reviews
	if req.RequireReviews > 0 {
		protection.RequiredPullRequestReviews = &github.PullRequestReviewsEnforcementRequest{
			DismissStaleReviews:          true,
			RequireCodeOwnerReviews:      false,
			RequiredApprovingReviewCount: req.RequireReviews,
		}
	}

	// Update branch protection
	_, _, err := c.client.Repositories.UpdateBranchProtection(
		ctx,
		req.Org,
		req.Repo,
		req.Branch,
		protection,
	)
	if err != nil {
		return fmt.Errorf("failed to update branch protection: %w", err)
	}

	return nil
}

// convertToStatusChecks converts check names to GitHub RequiredStatusCheck format.
func convertToStatusChecks(checks []string) []*github.RequiredStatusCheck {
	result := make([]*github.RequiredStatusCheck, len(checks))
	for i, check := range checks {
		result[i] = &github.RequiredStatusCheck{
			Context: check,
		}
	}
	return result
}