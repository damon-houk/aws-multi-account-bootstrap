package aws

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/sns"
	"github.com/aws/aws-sdk-go-v2/service/sns/types"
)

// CreateSNSTopic creates an AWS SNS topic for notifications.
//
// If a topic with the same name already exists, this method returns
// the ARN of the existing topic (idempotent).
//
// Returns the SNS Topic ARN.
func (c *Client) CreateSNSTopic(ctx context.Context, accountID, topicName string) (string, error) {
	if accountID == "" {
		return "", errors.New("accountID is required")
	}
	if topicName == "" {
		return "", errors.New("topicName is required")
	}

	// Try to create the topic
	createResp, err := c.sns.CreateTopic(ctx, &sns.CreateTopicInput{
		Name: aws.String(topicName),
		Tags: []types.Tag{
			{
				Key:   aws.String("ManagedBy"),
				Value: aws.String("aws-multi-account-bootstrap"),
			},
		},
	})

	if err != nil {
		return "", fmt.Errorf("failed to create SNS topic: %w", err)
	}

	return aws.ToString(createResp.TopicArn), nil
}

// SubscribeEmailToSNSTopic subscribes an email address to an SNS topic.
//
// The email owner will receive a confirmation email and must click the link
// to confirm the subscription.
//
// This method is idempotent - if the subscription already exists, it returns success.
func (c *Client) SubscribeEmailToSNSTopic(ctx context.Context, topicARN, email string) error {
	if topicARN == "" {
		return errors.New("topicARN is required")
	}
	if email == "" {
		return errors.New("email is required")
	}

	// Check if subscription already exists
	exists, err := c.subscriptionExists(ctx, topicARN, email)
	if err != nil {
		return fmt.Errorf("failed to check existing subscriptions: %w", err)
	}
	if exists {
		// Subscription already exists
		return nil
	}

	// Subscribe email to topic
	_, err = c.sns.Subscribe(ctx, &sns.SubscribeInput{
		TopicArn: aws.String(topicARN),
		Protocol: aws.String("email"),
		Endpoint: aws.String(email),
	})

	if err != nil {
		// Check if it's a duplicate subscription error
		if strings.Contains(err.Error(), "already exists") || strings.Contains(err.Error(), "duplicate") {
			return nil
		}
		return fmt.Errorf("failed to subscribe email to SNS topic: %w", err)
	}

	return nil
}

// subscriptionExists checks if an email subscription already exists for a topic.
func (c *Client) subscriptionExists(ctx context.Context, topicARN, email string) (bool, error) {
	paginator := sns.NewListSubscriptionsByTopicPaginator(c.sns, &sns.ListSubscriptionsByTopicInput{
		TopicArn: aws.String(topicARN),
	})

	for paginator.HasMorePages() {
		page, err := paginator.NextPage(ctx)
		if err != nil {
			return false, err
		}

		for _, sub := range page.Subscriptions {
			if aws.ToString(sub.Protocol) == "email" && aws.ToString(sub.Endpoint) == email {
				return true, nil
			}
		}
	}

	return false, nil
}