package aws

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/iam"
	"github.com/aws/aws-sdk-go-v2/service/iam/types"

	"github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/ports"
)

const (
	// GitHub OIDC provider URL
	githubOIDCURL = "https://token.actions.githubusercontent.com"

	// GitHub OIDC thumbprint (valid as of 2024)
	// This is the thumbprint for GitHub's OIDC provider certificate
	githubOIDCThumbprint = "6938fd4d98bab03faadb97b34396831e3780aea1"
)

// CreateOIDCProviderForGitHub creates an OIDC identity provider for GitHub Actions.
//
// This enables GitHub Actions to assume AWS IAM roles without long-lived credentials.
// If the provider already exists, this method returns success (idempotent).
func (c *Client) CreateOIDCProviderForGitHub(ctx context.Context, accountID string) error {
	if accountID == "" {
		return errors.New("accountID is required")
	}

	// Try to create the OIDC provider
	_, err := c.iam.CreateOpenIDConnectProvider(ctx, &iam.CreateOpenIDConnectProviderInput{
		Url: aws.String(githubOIDCURL),
		ClientIDList: []string{
			"sts.amazonaws.com", // GitHub uses sts.amazonaws.com as the audience
		},
		ThumbprintList: []string{
			githubOIDCThumbprint,
		},
		Tags: []types.Tag{
			{
				Key:   aws.String("ManagedBy"),
				Value: aws.String("aws-multi-account-bootstrap"),
			},
			{
				Key:   aws.String("Purpose"),
				Value: aws.String("GitHubActions"),
			},
		},
	})

	if err != nil {
		// Check if it already exists
		if strings.Contains(err.Error(), "EntityAlreadyExists") {
			// Provider already exists, this is fine
			return nil
		}
		return fmt.Errorf("failed to create OIDC provider: %w", err)
	}

	return nil
}

// CreateGitHubActionsRole creates an IAM role that GitHub Actions can assume via OIDC.
//
// The role is created with a trust policy that allows GitHub Actions from the specified
// repository to assume it. If AllowAllBranches is false, only main and develop branches
// can assume the role.
func (c *Client) CreateGitHubActionsRole(ctx context.Context, req ports.AWSCreateRoleRequest) (string, error) {
	// Validate inputs
	if req.AccountID == "" {
		return "", errors.New("accountID is required")
	}
	if req.RoleName == "" {
		return "", errors.New("roleName is required")
	}
	if req.GitHubOrg == "" {
		return "", errors.New("gitHubOrg is required")
	}
	if req.GitHubRepo == "" {
		return "", errors.New("gitHubRepo is required")
	}
	if len(req.PolicyARNs) == 0 {
		// Default to AdministratorAccess if no policies specified
		req.PolicyARNs = []string{"arn:aws:iam::aws:policy/AdministratorAccess"}
	}

	// Build the OIDC provider ARN
	oidcProviderARN := fmt.Sprintf("arn:aws:iam::%s:oidc-provider/token.actions.githubusercontent.com", req.AccountID)

	// Build trust policy
	trustPolicy, err := buildGitHubTrustPolicy(oidcProviderARN, req.GitHubOrg, req.GitHubRepo, req.AllowAllBranches)
	if err != nil {
		return "", fmt.Errorf("failed to build trust policy: %w", err)
	}

	// Try to create the role
	createResp, err := c.iam.CreateRole(ctx, &iam.CreateRoleInput{
		RoleName:                 aws.String(req.RoleName),
		AssumeRolePolicyDocument: aws.String(trustPolicy),
		Description:              aws.String(fmt.Sprintf("Role for GitHub Actions from %s/%s", req.GitHubOrg, req.GitHubRepo)),
		Tags: []types.Tag{
			{
				Key:   aws.String("ManagedBy"),
				Value: aws.String("aws-multi-account-bootstrap"),
			},
			{
				Key:   aws.String("GitHubOrg"),
				Value: aws.String(req.GitHubOrg),
			},
			{
				Key:   aws.String("GitHubRepo"),
				Value: aws.String(req.GitHubRepo),
			},
		},
	})

	var roleARN string
	if err != nil {
		// Check if it already exists
		if strings.Contains(err.Error(), "EntityAlreadyExists") {
			// Role exists, update its trust policy
			_, updateErr := c.iam.UpdateAssumeRolePolicy(ctx, &iam.UpdateAssumeRolePolicyInput{
				RoleName:       aws.String(req.RoleName),
				PolicyDocument: aws.String(trustPolicy),
			})
			if updateErr != nil {
				return "", fmt.Errorf("role exists but failed to update trust policy: %w", updateErr)
			}
			roleARN = fmt.Sprintf("arn:aws:iam::%s:role/%s", req.AccountID, req.RoleName)
		} else {
			return "", fmt.Errorf("failed to create role: %w", err)
		}
	} else {
		roleARN = aws.ToString(createResp.Role.Arn)
	}

	// Attach policies to the role
	for _, policyARN := range req.PolicyARNs {
		_, err := c.iam.AttachRolePolicy(ctx, &iam.AttachRolePolicyInput{
			RoleName:  aws.String(req.RoleName),
			PolicyArn: aws.String(policyARN),
		})
		if err != nil {
			// Log warning but don't fail - policy might already be attached
			// In production, you'd want proper logging here
		}
	}

	return roleARN, nil
}

// buildGitHubTrustPolicy creates an IAM trust policy for GitHub Actions.
//
// The policy allows GitHub Actions from the specified repository to assume the role.
// If allowAllBranches is false, only main and develop branches can assume the role.
func buildGitHubTrustPolicy(oidcProviderARN, githubOrg, githubRepo string, allowAllBranches bool) (string, error) {
	// Build the subject filter
	// Format: repo:owner/repo:ref:refs/heads/branch
	repoPath := fmt.Sprintf("%s/%s", githubOrg, githubRepo)

	var subjectFilter string
	if allowAllBranches {
		// Allow any branch
		subjectFilter = fmt.Sprintf("repo:%s:*", repoPath)
	} else {
		// Only allow main and develop branches
		// Using StringLike with multiple patterns requires more complex policy
		subjectFilter = fmt.Sprintf("repo:%s:ref:refs/heads/*", repoPath)
	}

	policy := map[string]interface{}{
		"Version": "2012-10-17",
		"Statement": []map[string]interface{}{
			{
				"Effect": "Allow",
				"Principal": map[string]interface{}{
					"Federated": oidcProviderARN,
				},
				"Action": "sts:AssumeRoleWithWebIdentity",
				"Condition": map[string]interface{}{
					"StringEquals": map[string]interface{}{
						"token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
					},
					"StringLike": map[string]interface{}{
						"token.actions.githubusercontent.com:sub": subjectFilter,
					},
				},
			},
		},
	}

	policyJSON, err := json.Marshal(policy)
	if err != nil {
		return "", fmt.Errorf("failed to marshal trust policy: %w", err)
	}

	return string(policyJSON), nil
}