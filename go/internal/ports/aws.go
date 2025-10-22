package ports

import (
	"context"
	"time"
)

// AWSClient defines the contract for AWS operations needed for multi-account setup.
//
// This interface is DELIBERATELY AWS-SPECIFIC. We're not pretending to be
// cloud-agnostic because:
//   - AWS Organizations is fundamentally different from Azure Management Groups or GCP Folders
//   - AWS CDK is different from Azure ARM templates or GCP Cloud Foundation Toolkit
//   - AWS Budgets/CloudWatch are different from other cloud cost management
//
// Why keep this interface?
//   - TESTING: Mock implementation enables fast tests without AWS credentials
//   - SEPARATION: Business logic (domain) stays separate from AWS SDK details
//   - CLARITY: Makes dependencies explicit
//
// This is Hexagonal Architecture for TESTING, not for multi-cloud abstraction.
//
// If you need Azure or GCP: Build separate tools. Don't try to abstract them.
type AWSClient interface {
	// AWS Organizations - Account Management

	// CreateAccount creates a new AWS account in an AWS Organization.
	//
	// This is AWS-specific: Creates an account with AWS Organizations API.
	//
	// Returns:
	//   - AWS Account ID (12-digit number as string)
	//   - Error if creation fails
	CreateAccount(ctx context.Context, req AWSCreateAccountRequest) (string, error)

	// WaitForAccountCreation waits for an AWS account to be fully created.
	//
	// AWS Organizations creates accounts asynchronously. This method polls
	// until the account is ready or times out.
	WaitForAccountCreation(ctx context.Context, accountID string) error

	// GetAccountByName looks up an AWS account by its name.
	//
	// Returns:
	//   - AWS Account ID if found (empty string if not found)
	//   - Error if the operation fails (NOT if account doesn't exist)
	GetAccountByName(ctx context.Context, name string) (string, error)

	// AWS IAM - OIDC for GitHub Actions

	// CreateOIDCProviderForGitHub creates an OIDC identity provider for GitHub Actions.
	//
	// This enables GitHub Actions to assume AWS IAM roles without long-lived credentials.
	// AWS-specific: Uses AWS IAM OIDC provider.
	CreateOIDCProviderForGitHub(ctx context.Context, accountID string) error

	// CreateGitHubActionsRole creates an IAM role that GitHub Actions can assume via OIDC.
	//
	// AWS-specific: Creates AWS IAM role with trust policy for GitHub OIDC.
	//
	// Returns:
	//   - IAM Role ARN
	//   - Error if creation fails
	CreateGitHubActionsRole(ctx context.Context, req AWSCreateRoleRequest) (string, error)

	// AWS CDK - Infrastructure as Code

	// BootstrapCDK runs AWS CDK bootstrap in an account.
	//
	// AWS-specific: Creates S3 buckets, ECR repos, and IAM roles for AWS CDK.
	BootstrapCDK(ctx context.Context, accountID, region, trustAccountID string) error

	// AWS Budgets & Cost Management

	// CreateBudget creates an AWS Budget with email notifications.
	//
	// AWS-specific: Uses AWS Budgets API.
	CreateBudget(ctx context.Context, req AWSCreateBudgetRequest) error

	// CreateBillingAlarm creates a CloudWatch billing alarm.
	//
	// AWS-specific: Uses AWS CloudWatch Alarms + SNS for billing alerts.
	CreateBillingAlarm(ctx context.Context, req AWSCreateBillingAlarmRequest) error

	// AWS SNS - Notifications

	// CreateSNSTopic creates an AWS SNS topic for notifications.
	//
	// Returns:
	//   - SNS Topic ARN
	//   - Error if creation fails
	CreateSNSTopic(ctx context.Context, accountID, topicName string) (string, error)

	// SubscribeEmailToSNSTopic subscribes an email address to an SNS topic.
	SubscribeEmailToSNSTopic(ctx context.Context, topicARN, email string) error

	// AWS STS - Cross-Account Access

	// AssumeRole assumes an IAM role in another AWS account.
	//
	// Returns temporary AWS credentials.
	AssumeRole(ctx context.Context, roleARN, sessionName string) (*AWSCredentials, error)

	// GetCallerIdentity returns information about the current AWS credentials.
	GetCallerIdentity(ctx context.Context) (*AWSCallerIdentity, error)

	// Metadata

	// Name returns "AWS" (for logging/debugging).
	Name() string
}

// AWSCreateAccountRequest contains parameters for creating an AWS account.
type AWSCreateAccountRequest struct {
	Name      string // AWS account name (e.g., "TPA-dev")
	Email     string // Root email for the account
	OrgUnitID string // AWS Organization Unit ID (e.g., "ou-813y-xxxxxxxx")
	RoleName  string // Cross-account access role name (usually "OrganizationAccountAccessRole")
}

// AWSCreateRoleRequest contains parameters for creating an AWS IAM role for GitHub Actions.
type AWSCreateRoleRequest struct {
	AccountID        string   // AWS Account ID where role should be created
	RoleName         string   // IAM role name (e.g., "GitHubActionsDeployRole")
	GitHubOrg        string   // GitHub organization name
	GitHubRepo       string   // GitHub repository name
	PolicyARNs       []string // AWS Policy ARNs to attach (e.g., "arn:aws:iam::aws:policy/AdministratorAccess")
	AllowAllBranches bool     // If true, any branch can assume role; if false, only main/develop
}

// AWSCreateBudgetRequest contains parameters for creating an AWS Budget.
type AWSCreateBudgetRequest struct {
	AccountID     string  // AWS Account ID
	BudgetName    string  // Budget name (e.g., "TPA-dev-monthly")
	LimitAmount   float64 // Monthly limit in USD (e.g., 25.00)
	AlertAmount   float64 // Amount to trigger alert (e.g., 15.00)
	Email         string  // Email for notifications
	AlertPercents []int   // Additional alert percentages (e.g., [80, 90, 100])
}

// AWSCreateBillingAlarmRequest contains parameters for creating a CloudWatch billing alarm.
type AWSCreateBillingAlarmRequest struct {
	AccountID string  // AWS Account ID
	AlarmName string  // CloudWatch alarm name
	Threshold float64 // Threshold amount in USD
	TopicARN  string  // SNS topic ARN for notifications
}

// AWSCredentials represents temporary AWS credentials from STS AssumeRole.
type AWSCredentials struct {
	AccessKeyID     string
	SecretAccessKey string
	SessionToken    string
	Expiration      time.Time
}

// AWSCallerIdentity contains information about the authenticated AWS principal.
type AWSCallerIdentity struct {
	AccountID string // AWS Account ID (12-digit number)
	UserID    string // AWS IAM User or Role ID
	ARN       string // Full AWS ARN (e.g., "arn:aws:iam::123456789012:user/admin")
}
