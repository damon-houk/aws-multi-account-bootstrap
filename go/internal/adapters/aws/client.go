package aws

import (
	"context"
	"errors"
	"fmt"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/budgets"
	"github.com/aws/aws-sdk-go-v2/service/cloudwatch"
	"github.com/aws/aws-sdk-go-v2/service/iam"
	"github.com/aws/aws-sdk-go-v2/service/organizations"
	"github.com/aws/aws-sdk-go-v2/service/sns"
	"github.com/aws/aws-sdk-go-v2/service/sts"

	"github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/ports"
)

// Client implements the ports.AWSClient interface using AWS SDK for Go v2.
//
// This adapter connects the domain logic to real AWS services.
// For testing without AWS credentials, use the mock adapter instead.
type Client struct {
	cfg            aws.Config
	organizations  *organizations.Client
	iam            *iam.Client
	sts            *sts.Client
	budgets        *budgets.Client
	cloudwatch     *cloudwatch.Client
	sns            *sns.Client
}

// NewClient creates a new AWS client with default configuration.
//
// The client uses the default AWS credential chain:
// 1. Environment variables (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
// 2. Shared credentials file (~/.aws/credentials)
// 3. IAM role (for EC2 instances, ECS tasks, Lambda functions)
//
// Returns an error if AWS credentials cannot be loaded.
func NewClient(ctx context.Context) (*Client, error) {
	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to load AWS config: %w", err)
	}

	return NewClientWithConfig(cfg), nil
}

// NewClientWithConfig creates a new AWS client with the provided configuration.
//
// This is useful for testing or when you want to customize the AWS config
// (e.g., specify a region, endpoint, or credentials).
func NewClientWithConfig(cfg aws.Config) *Client {
	return &Client{
		cfg:            cfg,
		organizations:  organizations.NewFromConfig(cfg),
		iam:            iam.NewFromConfig(cfg),
		sts:            sts.NewFromConfig(cfg),
		budgets:        budgets.NewFromConfig(cfg),
		cloudwatch:     cloudwatch.NewFromConfig(cfg),
		sns:            sns.NewFromConfig(cfg),
	}
}

// Compile-time check to ensure Client implements ports.AWSClient
var _ ports.AWSClient = (*Client)(nil)

// Name returns "AWS" for logging and debugging.
func (c *Client) Name() string {
	return "AWS"
}

// GetCallerIdentity returns information about the authenticated AWS principal.
func (c *Client) GetCallerIdentity(ctx context.Context) (*ports.AWSCallerIdentity, error) {
	resp, err := c.sts.GetCallerIdentity(ctx, &sts.GetCallerIdentityInput{})
	if err != nil {
		return nil, fmt.Errorf("failed to get caller identity: %w", err)
	}

	return &ports.AWSCallerIdentity{
		AccountID: aws.ToString(resp.Account),
		UserID:    aws.ToString(resp.UserId),
		ARN:       aws.ToString(resp.Arn),
	}, nil
}

// AssumeRole assumes an IAM role in another AWS account and returns temporary credentials.
func (c *Client) AssumeRole(ctx context.Context, roleARN, sessionName string) (*ports.AWSCredentials, error) {
	if roleARN == "" {
		return nil, errors.New("roleARN is required")
	}
	if sessionName == "" {
		sessionName = "aws-multi-account-bootstrap"
	}

	resp, err := c.sts.AssumeRole(ctx, &sts.AssumeRoleInput{
		RoleArn:         aws.String(roleARN),
		RoleSessionName: aws.String(sessionName),
	})
	if err != nil {
		return nil, fmt.Errorf("failed to assume role %s: %w", roleARN, err)
	}

	if resp.Credentials == nil {
		return nil, fmt.Errorf("no credentials returned from AssumeRole")
	}

	return &ports.AWSCredentials{
		AccessKeyID:     aws.ToString(resp.Credentials.AccessKeyId),
		SecretAccessKey: aws.ToString(resp.Credentials.SecretAccessKey),
		SessionToken:    aws.ToString(resp.Credentials.SessionToken),
		Expiration:      aws.ToTime(resp.Credentials.Expiration),
	}, nil
}