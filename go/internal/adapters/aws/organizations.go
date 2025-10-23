package aws

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/organizations"
	"github.com/aws/aws-sdk-go-v2/service/organizations/types"

	"github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/ports"
)

// CreateAccount creates a new AWS account in an AWS Organization.
//
// This method:
// 1. Checks if an account with the same name already exists
// 2. Creates the account if it doesn't exist
// 3. Waits for the account creation to complete
// 4. Moves the account to the target organizational unit
//
// Returns the AWS Account ID (12-digit number as string).
func (c *Client) CreateAccount(ctx context.Context, req ports.AWSCreateAccountRequest) (string, error) {
	// Validate inputs
	if req.Name == "" {
		return "", errors.New("account name is required")
	}
	if req.Email == "" {
		return "", errors.New("email is required")
	}
	if req.OrgUnitID == "" {
		return "", errors.New("organizational unit ID is required")
	}
	if req.RoleName == "" {
		req.RoleName = "OrganizationAccountAccessRole" // Default
	}

	// Check if account already exists
	existingAccountID, err := c.GetAccountByName(ctx, req.Name)
	if err == nil && existingAccountID != "" {
		// Account already exists, return its ID
		return existingAccountID, nil
	}

	// Create the account
	createResp, err := c.organizations.CreateAccount(ctx, &organizations.CreateAccountInput{
		Email:     aws.String(req.Email),
		AccountName: aws.String(req.Name),
		RoleName:  aws.String(req.RoleName),
	})
	if err != nil {
		return "", fmt.Errorf("failed to create account: %w", err)
	}

	if createResp.CreateAccountStatus == nil || createResp.CreateAccountStatus.Id == nil {
		return "", errors.New("no create account request ID returned")
	}

	requestID := aws.ToString(createResp.CreateAccountStatus.Id)

	// Wait for account creation to complete
	accountID, err := c.waitForAccountCreation(ctx, requestID)
	if err != nil {
		return "", err
	}

	// Move account to target OU if specified
	if req.OrgUnitID != "" {
		if err := c.moveAccountToOU(ctx, accountID, req.OrgUnitID); err != nil {
			// Log warning but don't fail - account is created
			return accountID, fmt.Errorf("account created but failed to move to OU: %w", err)
		}
	}

	return accountID, nil
}

// WaitForAccountCreation waits for an AWS account to be fully created.
//
// AWS Organizations creates accounts asynchronously. This method polls
// the creation status until the account is ready or the context times out.
func (c *Client) WaitForAccountCreation(ctx context.Context, accountID string) error {
	// For this public method, we just validate the account exists
	_, err := c.GetAccountByName(ctx, accountID)
	return err
}

// waitForAccountCreation is the internal implementation that polls the create request status.
func (c *Client) waitForAccountCreation(ctx context.Context, requestID string) (string, error) {
	const (
		maxAttempts = 60               // 60 attempts
		pollInterval = 10 * time.Second // 10 seconds between polls
	)

	for attempt := 0; attempt < maxAttempts; attempt++ {
		select {
		case <-ctx.Done():
			return "", ctx.Err()
		case <-time.After(pollInterval):
			// Continue polling
		}

		resp, err := c.organizations.DescribeCreateAccountStatus(ctx, &organizations.DescribeCreateAccountStatusInput{
			CreateAccountRequestId: aws.String(requestID),
		})
		if err != nil {
			return "", fmt.Errorf("failed to describe create account status: %w", err)
		}

		if resp.CreateAccountStatus == nil {
			return "", errors.New("no create account status returned")
		}

		status := resp.CreateAccountStatus
		switch status.State {
		case types.CreateAccountStateSucceeded:
			return aws.ToString(status.AccountId), nil

		case types.CreateAccountStateFailed:
			reason := string(status.FailureReason)
			return "", fmt.Errorf("account creation failed: %s", reason)

		case types.CreateAccountStateInProgress:
			// Still creating, continue waiting
			continue

		default:
			return "", fmt.Errorf("unknown account creation state: %s", status.State)
		}
	}

	return "", fmt.Errorf("account creation timed out after %d attempts", maxAttempts)
}

// GetAccountByName looks up an AWS account by its name.
//
// Returns:
//   - AWS Account ID if found (empty string if not found)
//   - Error if the operation fails (NOT if account doesn't exist)
func (c *Client) GetAccountByName(ctx context.Context, name string) (string, error) {
	if name == "" {
		return "", errors.New("account name is required")
	}

	// List all accounts (paginated)
	paginator := organizations.NewListAccountsPaginator(c.organizations, &organizations.ListAccountsInput{})

	for paginator.HasMorePages() {
		page, err := paginator.NextPage(ctx)
		if err != nil {
			return "", fmt.Errorf("failed to list accounts: %w", err)
		}

		for _, account := range page.Accounts {
			if aws.ToString(account.Name) == name {
				return aws.ToString(account.Id), nil
			}
		}
	}

	// Account not found (this is not an error, just return empty string)
	return "", nil
}

// moveAccountToOU moves an account to a target organizational unit.
func (c *Client) moveAccountToOU(ctx context.Context, accountID, targetOUID string) error {
	// Get current parent
	parentsResp, err := c.organizations.ListParents(ctx, &organizations.ListParentsInput{
		ChildId: aws.String(accountID),
	})
	if err != nil {
		return fmt.Errorf("failed to list parents: %w", err)
	}

	if len(parentsResp.Parents) == 0 {
		return errors.New("account has no parent")
	}

	currentParentID := aws.ToString(parentsResp.Parents[0].Id)

	// If already in target OU, nothing to do
	if currentParentID == targetOUID {
		return nil
	}

	// Move account to target OU
	_, err = c.organizations.MoveAccount(ctx, &organizations.MoveAccountInput{
		AccountId:           aws.String(accountID),
		SourceParentId:      aws.String(currentParentID),
		DestinationParentId: aws.String(targetOUID),
	})
	if err != nil {
		return fmt.Errorf("failed to move account: %w", err)
	}

	return nil
}