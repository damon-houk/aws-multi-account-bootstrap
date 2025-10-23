package aws

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/budgets"
	"github.com/aws/aws-sdk-go-v2/service/budgets/types"
	"github.com/aws/aws-sdk-go-v2/service/cloudwatch"
	cwtypes "github.com/aws/aws-sdk-go-v2/service/cloudwatch/types"

	"github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/ports"
)

// CreateBudget creates an AWS Budget with email notifications.
//
// This method sets up:
// 1. A monthly budget with the specified limit
// 2. Notifications at 80%, 90% (actual spend)
// 3. Notification at 100% (forecasted spend)
// 4. Additional alert thresholds if specified
func (c *Client) CreateBudget(ctx context.Context, req ports.AWSCreateBudgetRequest) error {
	// Validate inputs
	if req.AccountID == "" {
		return errors.New("accountID is required")
	}
	if req.BudgetName == "" {
		return errors.New("budgetName is required")
	}
	if req.LimitAmount <= 0 {
		return errors.New("limitAmount must be positive")
	}
	if req.Email == "" {
		return errors.New("email is required")
	}

	// Default alert thresholds if not specified
	if len(req.AlertPercents) == 0 {
		req.AlertPercents = []int{80, 90, 100}
	}

	// Build notifications
	notifications := make([]types.NotificationWithSubscribers, 0, len(req.AlertPercents)+1)

	// Add actual spend notifications
	for _, percent := range req.AlertPercents {
		if percent >= 100 {
			continue // Handle 100% separately as forecast
		}

		notifications = append(notifications, types.NotificationWithSubscribers{
			Notification: &types.Notification{
				NotificationType:  types.NotificationTypeActual,
				ComparisonOperator: types.ComparisonOperatorGreaterThan,
				Threshold:          float64(percent),
				ThresholdType:     types.ThresholdTypePercentage,
			},
			Subscribers: []types.Subscriber{
				{
					SubscriptionType: types.SubscriptionTypeEmail,
					Address:          aws.String(req.Email),
				},
			},
		})
	}

	// Add forecasted spend notification at 100%
	notifications = append(notifications, types.NotificationWithSubscribers{
		Notification: &types.Notification{
			NotificationType:  types.NotificationTypeForecasted,
			ComparisonOperator: types.ComparisonOperatorGreaterThan,
			Threshold:          100.0,
			ThresholdType:     types.ThresholdTypePercentage,
		},
		Subscribers: []types.Subscriber{
			{
				SubscriptionType: types.SubscriptionTypeEmail,
				Address:          aws.String(req.Email),
			},
		},
	})

	// Calculate time period
	now := time.Now().UTC()
	startOfMonth := time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, time.UTC)
	endOfTime := time.Date(2087, 6, 15, 0, 0, 0, 0, time.UTC) // Far future date

	// Create the budget
	_, err := c.budgets.CreateBudget(ctx, &budgets.CreateBudgetInput{
		AccountId: aws.String(req.AccountID),
		Budget: &types.Budget{
			BudgetName: aws.String(req.BudgetName),
			BudgetType: types.BudgetTypeCost,
			TimeUnit:   types.TimeUnitMonthly,
			BudgetLimit: &types.Spend{
				Amount: aws.String(fmt.Sprintf("%.2f", req.LimitAmount)),
				Unit:   aws.String("USD"),
			},
			CostFilters: map[string][]string{},
			CostTypes: &types.CostTypes{
				IncludeTax:              aws.Bool(true),
				IncludeSubscription:     aws.Bool(true),
				UseBlended:              aws.Bool(false),
				IncludeRefund:           aws.Bool(false),
				IncludeCredit:           aws.Bool(false),
				IncludeUpfront:          aws.Bool(true),
				IncludeRecurring:        aws.Bool(true),
				IncludeOtherSubscription: aws.Bool(true),
				IncludeSupport:          aws.Bool(true),
				IncludeDiscount:         aws.Bool(true),
				UseAmortized:            aws.Bool(false),
			},
			TimePeriod: &types.TimePeriod{
				Start: aws.Time(startOfMonth),
				End:   aws.Time(endOfTime),
			},
		},
		NotificationsWithSubscribers: notifications,
	})

	if err != nil {
		// Check if budget already exists
		if strings.Contains(err.Error(), "DuplicateRecord") || strings.Contains(err.Error(), "AlreadyExists") {
			// Budget already exists, this is fine
			return nil
		}
		return fmt.Errorf("failed to create budget: %w", err)
	}

	return nil
}

// CreateBillingAlarm creates a CloudWatch billing alarm.
//
// Note: Billing metrics are only available in us-east-1 region.
// This method automatically uses us-east-1 for the CloudWatch client.
func (c *Client) CreateBillingAlarm(ctx context.Context, req ports.AWSCreateBillingAlarmRequest) error {
	// Validate inputs
	if req.AccountID == "" {
		return errors.New("accountID is required")
	}
	if req.AlarmName == "" {
		return errors.New("alarmName is required")
	}
	if req.Threshold <= 0 {
		return errors.New("threshold must be positive")
	}
	if req.TopicARN == "" {
		return errors.New("topicARN is required")
	}

	// Create CloudWatch client for us-east-1 (billing metrics only available there)
	cfg := c.cfg.Copy()
	cfg.Region = "us-east-1"
	cwClient := cloudwatch.NewFromConfig(cfg)

	// Create the alarm
	_, err := cwClient.PutMetricAlarm(ctx, &cloudwatch.PutMetricAlarmInput{
		AlarmName:          aws.String(req.AlarmName),
		AlarmDescription:   aws.String(fmt.Sprintf("Billing alert when charges exceed $%.2f", req.Threshold)),
		MetricName:         aws.String("EstimatedCharges"),
		Namespace:          aws.String("AWS/Billing"),
		Statistic:          cwtypes.StatisticMaximum,
		Period:             aws.Int32(21600), // 6 hours
		EvaluationPeriods:  aws.Int32(1),
		Threshold:          aws.Float64(req.Threshold),
		ComparisonOperator: cwtypes.ComparisonOperatorGreaterThanThreshold,
		Dimensions: []cwtypes.Dimension{
			{
				Name:  aws.String("Currency"),
				Value: aws.String("USD"),
			},
		},
		AlarmActions: []string{req.TopicARN},
		TreatMissingData: aws.String("notBreaching"),
	})

	if err != nil {
		return fmt.Errorf("failed to create billing alarm: %w", err)
	}

	return nil
}