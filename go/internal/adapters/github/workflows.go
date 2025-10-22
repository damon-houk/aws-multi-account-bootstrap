package github

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/go-github/v67/github"

	"github.com/damonallison/aws-multi-account-bootstrap/v2/internal/ports"
)

// CreateWorkflow creates a workflow file in the repository.
//
// This commits the workflow file to the specified branch (or default branch).
func (c *Client) CreateWorkflow(ctx context.Context, req ports.GitHubCreateWorkflowRequest) error {
	// Validate inputs
	if req.Org == "" {
		return errors.New("organization is required")
	}
	if req.Repo == "" {
		return errors.New("repository name is required")
	}
	if req.WorkflowName == "" {
		return errors.New("workflow name is required")
	}
	if req.WorkflowContent == "" {
		return errors.New("workflow content is required")
	}

	// Determine branch
	branch := req.Branch
	if branch == "" {
		var err error
		branch, err = c.GetDefaultBranch(ctx, req.Org, req.Repo)
		if err != nil {
			return fmt.Errorf("failed to get default branch: %w", err)
		}
	}

	// Workflow path
	workflowPath := fmt.Sprintf(".github/workflows/%s", req.WorkflowName)

	// Check if file already exists
	existingFile, _, resp, err := c.client.Repositories.GetContents(
		ctx,
		req.Org,
		req.Repo,
		workflowPath,
		&github.RepositoryContentGetOptions{Ref: branch},
	)

	var sha *string
	if err == nil && existingFile != nil {
		// File exists, we'll update it
		sha = existingFile.SHA
	} else if resp != nil && resp.StatusCode != 404 {
		// Some other error occurred
		return fmt.Errorf("failed to check existing workflow: %w", err)
	}

	// Commit message
	commitMessage := req.CommitMessage
	if commitMessage == "" {
		if sha == nil {
			commitMessage = fmt.Sprintf("Add %s workflow", req.WorkflowName)
		} else {
			commitMessage = fmt.Sprintf("Update %s workflow", req.WorkflowName)
		}
	}

	// Create or update the file
	opts := &github.RepositoryContentFileOptions{
		Message: &commitMessage,
		Content: []byte(req.WorkflowContent),
		Branch:  &branch,
		SHA:     sha,
	}

	_, _, err = c.client.Repositories.CreateFile(ctx, req.Org, req.Repo, workflowPath, opts)
	if err != nil {
		return fmt.Errorf("failed to create/update workflow file: %w", err)
	}

	return nil
}

// EnableWorkflow enables a workflow file.
//
// Note: GitHub automatically enables workflows when they're created.
// This method is kept for API compatibility but is essentially a no-op.
func (c *Client) EnableWorkflow(ctx context.Context, org, repo, workflowName string) error {
	if org == "" || repo == "" {
		return errors.New("org and repo are required")
	}
	if workflowName == "" {
		return errors.New("workflow name is required")
	}

	// Get workflow ID by name
	workflows, _, err := c.client.Actions.ListWorkflows(ctx, org, repo, nil)
	if err != nil {
		return fmt.Errorf("failed to list workflows: %w", err)
	}

	// Find the workflow
	var workflowID int64
	for _, wf := range workflows.Workflows {
		if wf.GetPath() == fmt.Sprintf(".github/workflows/%s", workflowName) {
			workflowID = wf.GetID()
			break
		}
	}

	if workflowID == 0 {
		return fmt.Errorf("workflow %s not found", workflowName)
	}

	// Enable the workflow
	_, err = c.client.Actions.EnableWorkflowByID(ctx, org, repo, workflowID)
	if err != nil {
		// Ignore error if workflow is already enabled
		if !isWorkflowAlreadyEnabledError(err) {
			return fmt.Errorf("failed to enable workflow: %w", err)
		}
	}

	return nil
}

// CreateRelease creates a release/tag.
func (c *Client) CreateRelease(ctx context.Context, req ports.GitHubCreateReleaseRequest) error {
	// Validate inputs
	if req.Org == "" {
		return errors.New("organization is required")
	}
	if req.Repo == "" {
		return errors.New("repository name is required")
	}
	if req.TagName == "" {
		return errors.New("tag name is required")
	}
	if req.Name == "" {
		req.Name = req.TagName // Use tag name as release name if not specified
	}

	// Create release
	release := &github.RepositoryRelease{
		TagName:    &req.TagName,
		Name:       &req.Name,
		Body:       &req.Body,
		Prerelease: &req.Prerelease,
	}

	_, _, err := c.client.Repositories.CreateRelease(ctx, req.Org, req.Repo, release)
	if err != nil {
		return fmt.Errorf("failed to create release: %w", err)
	}

	return nil
}

// isWorkflowAlreadyEnabledError checks if the error is because the workflow is already enabled.
func isWorkflowAlreadyEnabledError(err error) bool {
	// GitHub returns an error if the workflow is already enabled
	// We check the error message as the API doesn't provide a specific error type
	return err != nil && (
		err.Error() == "Workflow is already enabled" ||
		err.Error() == "workflow is already enabled")
}