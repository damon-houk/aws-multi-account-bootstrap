package aws

import (
	"context"
	"errors"
	"fmt"
	"os/exec"
	"strings"

	"github.com/aws/aws-sdk-go-v2/aws"
)

// BootstrapCDK runs AWS CDK bootstrap in an account.
//
// This method:
// 1. Assumes a role in the target account if needed
// 2. Runs `cdk bootstrap` with the appropriate trust policies
// 3. Configures CloudFormation execution policies
//
// Requirements:
// - AWS CDK CLI must be installed (npm install -g aws-cdk)
// - Appropriate IAM permissions in the target account
func (c *Client) BootstrapCDK(ctx context.Context, accountID, region, trustAccountID string) error {
	// Validate inputs
	if accountID == "" {
		return errors.New("accountID is required")
	}
	if region == "" {
		region = "us-east-1" // Default region
	}

	// If no trust account specified, use the current account
	if trustAccountID == "" {
		callerIdentity, err := c.GetCallerIdentity(ctx)
		if err != nil {
			return fmt.Errorf("failed to get caller identity: %w", err)
		}
		trustAccountID = callerIdentity.AccountID
	}

	// Check if CDK CLI is installed
	if !isCDKInstalled() {
		return errors.New("AWS CDK CLI is not installed. Install it with: npm install -g aws-cdk")
	}

	// Build CDK bootstrap command
	// Format: cdk bootstrap aws://ACCOUNT/REGION --trust TRUST_ACCOUNT --cloudformation-execution-policies POLICY_ARN
	awsEnv := fmt.Sprintf("aws://%s/%s", accountID, region)
	policyARN := "arn:aws:iam::aws:policy/AdministratorAccess"

	args := []string{
		"bootstrap",
		awsEnv,
		"--cloudformation-execution-policies", policyARN,
		"--trust", trustAccountID,
		"--trust-for-lookup", trustAccountID,
	}

	// Run the CDK bootstrap command
	cmd := exec.CommandContext(ctx, "cdk", args...)

	// Capture output
	output, err := cmd.CombinedOutput()
	outputStr := string(output)

	if err != nil {
		// Check if it's already bootstrapped
		if strings.Contains(outputStr, "already exists") || strings.Contains(outputStr, "already bootstrap") {
			// Already bootstrapped, this is fine
			return nil
		}
		return fmt.Errorf("CDK bootstrap failed: %w\nOutput: %s", err, outputStr)
	}

	return nil
}

// isCDKInstalled checks if the AWS CDK CLI is installed.
func isCDKInstalled() bool {
	_, err := exec.LookPath("cdk")
	return err == nil
}

// BootstrapCDKWithCredentials bootstraps CDK using specific AWS credentials.
//
// This is useful when you need to assume a role before bootstrapping.
func (c *Client) BootstrapCDKWithCredentials(ctx context.Context, accountID, region, roleName, trustAccountID string) error {
	// Build role ARN
	roleARN := fmt.Sprintf("arn:aws:iam::%s:role/%s", accountID, roleName)

	// Assume the role
	creds, err := c.AssumeRole(ctx, roleARN, "cdk-bootstrap-session")
	if err != nil {
		return fmt.Errorf("failed to assume role: %w", err)
	}

	// Create a new client with the assumed role credentials
	cfg := c.cfg.Copy()
	cfg.Credentials = aws.CredentialsProviderFunc(func(ctx context.Context) (aws.Credentials, error) {
		return aws.Credentials{
			AccessKeyID:     creds.AccessKeyID,
			SecretAccessKey: creds.SecretAccessKey,
			SessionToken:    creds.SessionToken,
			Source:          "AssumeRole",
			CanExpire:       true,
			Expires:         creds.Expiration,
		}, nil
	})

	// Create a new client with the assumed role credentials
	bootstrapClient := NewClientWithConfig(cfg)

	// Bootstrap using the new client
	return bootstrapClient.BootstrapCDK(ctx, accountID, region, trustAccountID)
}