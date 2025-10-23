package account

import (
	"context"
	"fmt"

	"github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/ports"
)

// CreateAllAccounts orchestrates the creation of AWS accounts for all environments.
//
// This is DOMAIN LOGIC - pure business orchestration.
//
// We're honest: This creates AWS accounts, not generic "cloud" accounts.
// But we still use the interface (ports.AWSClient) for:
//   - TESTING: Can use mock AWS client (no credentials needed)
//   - SEPARATION: Business rules stay separate from AWS SDK details
//
// Hexagonal Architecture for TESTING, not for false multi-cloud abstraction.
//
// Parameters:
//   - ctx: Context for cancellation and timeouts
//   - aws: AWS client implementation (real AWS SDK or mock for testing)
//   - config: Business configuration (validated)
//
// Returns:
//   - Slice of AccountInfo for created AWS accounts
//   - Error if any account creation fails
func CreateAllAccounts(
	ctx context.Context,
	aws ports.AWSClient,
	config Config,
) ([]AccountInfo, error) {
	// Validate configuration (business rule)
	if err := config.Validate(); err != nil {
		return nil, fmt.Errorf("invalid configuration: %w", err)
	}

	// Determine environments (business rule: default to all)
	envs := config.Environments
	if len(envs) == 0 {
		envs = AllEnvironments()
	}

	// Create AWS accounts for each environment (business orchestration)
	var accounts []AccountInfo

	for _, env := range envs {
		// Apply business rules (naming conventions)
		accountName := GenerateAccountName(config.ProjectCode, env)
		accountEmail := GenerateAccountEmail(config.EmailPrefix, config.ProjectCode, env)
		roleName := GetOrganizationAccessRoleName()

		// Check if AWS account already exists
		existingID, err := aws.GetAccountByName(ctx, accountName)
		if err != nil {
			return nil, fmt.Errorf("failed to check existing AWS account %s: %w", accountName, err)
		}

		var accountID string
		if existingID != "" {
			// AWS account exists - reuse it
			accountID = existingID
		} else {
			// Create new AWS account
			accountID, err = aws.CreateAccount(ctx, ports.AWSCreateAccountRequest{
				Name:      accountName,
				Email:     accountEmail,
				OrgUnitID: config.OUID,
				RoleName:  roleName,
			})
			if err != nil {
				return nil, fmt.Errorf("failed to create AWS account %s: %w", accountName, err)
			}

			// Wait for AWS account to be ready (Organizations is async)
			if err := aws.WaitForAccountCreation(ctx, accountID); err != nil {
				return nil, fmt.Errorf("AWS account %s creation timed out: %w", accountName, err)
			}
		}

		// Collect account info
		accounts = append(accounts, AccountInfo{
			Name:        accountName,
			Email:       accountEmail,
			AccountID:   accountID,
			Environment: env,
		})
	}

	return accounts, nil
}

// CreateSingleAccount creates an AWS account for a specific environment.
//
// Similar to CreateAllAccounts but for one environment only.
// Useful for adding additional environments later.
//
// Parameters:
//   - ctx: Context for cancellation and timeouts
//   - aws: AWS client implementation
//   - config: Business configuration
//   - env: Specific environment to create
//
// Returns:
//   - AccountInfo for the created AWS account
//   - Error if creation fails
func CreateSingleAccount(
	ctx context.Context,
	aws ports.AWSClient,
	config Config,
	env Environment,
) (*AccountInfo, error) {
	// Validate configuration
	if err := config.Validate(); err != nil {
		return nil, fmt.Errorf("invalid configuration: %w", err)
	}

	// Validate environment
	if err := ValidateEnvironment(env); err != nil {
		return nil, err
	}

	// Apply business rules
	accountName := GenerateAccountName(config.ProjectCode, env)
	accountEmail := GenerateAccountEmail(config.EmailPrefix, config.ProjectCode, env)
	roleName := GetOrganizationAccessRoleName()

	// Check if AWS account already exists
	existingID, err := aws.GetAccountByName(ctx, accountName)
	if err != nil {
		return nil, fmt.Errorf("failed to check existing AWS account: %w", err)
	}

	var accountID string
	if existingID != "" {
		accountID = existingID
	} else {
		// Create new AWS account
		accountID, err = aws.CreateAccount(ctx, ports.AWSCreateAccountRequest{
			Name:      accountName,
			Email:     accountEmail,
			OrgUnitID: config.OUID,
			RoleName:  roleName,
		})
		if err != nil {
			return nil, fmt.Errorf("failed to create AWS account: %w", err)
		}

		// Wait for AWS account to be ready
		if err := aws.WaitForAccountCreation(ctx, accountID); err != nil {
			return nil, fmt.Errorf("AWS account creation timed out: %w", err)
		}
	}

	return &AccountInfo{
		Name:        accountName,
		Email:       accountEmail,
		AccountID:   accountID,
		Environment: env,
	}, nil
}
