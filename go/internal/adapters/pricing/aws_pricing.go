package pricing

import (
	"fmt"

	"github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/cost"
	"github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/model"
	"github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/ports"
)

// AWSPricingAdapter implements ports.ResourcePricer using AWS Pricing API
// Adapter: Connects domain logic to AWS Pricing infrastructure
type AWSPricingAdapter struct {
	pricingClient cost.PricingClient
}

// NewAWSPricingAdapter creates a pricing adapter using AWS Pricing API
func NewAWSPricingAdapter(client cost.PricingClient) ports.ResourcePricer {
	return &AWSPricingAdapter{
		pricingClient: client,
	}
}

// GetPrice returns estimated monthly cost for a resource
func (a *AWSPricingAdapter) GetPrice(usage model.ResourceUsage, region string) (float64, error) {
	// Map resource type to pricing query
	queries := a.buildPricingQueries(usage, region)
	if len(queries) == 0 {
		return 0, fmt.Errorf("unsupported resource type: %s", usage.ResourceType)
	}

	// Fetch pricing for all queries
	totalCost := 0.0
	for _, query := range queries {
		result, err := a.pricingClient.GetPrice(query)
		if err != nil {
			return 0, fmt.Errorf("failed to get price for %s: %w", query.ProductFamily, err)
		}

		// Calculate cost based on usage
		cost := a.calculateCost(usage, result)
		totalCost += cost
	}

	return totalCost, nil
}

// GetPrices batch fetches pricing (more efficient than repeated GetPrice calls)
func (a *AWSPricingAdapter) GetPrices(usages []model.ResourceUsage, region string) (map[string]float64, error) {
	prices := make(map[string]float64)

	for _, usage := range usages {
		price, err := a.GetPrice(usage, region)
		if err != nil {
			// Non-fatal: continue with other resources
			continue
		}
		prices[usage.LogicalID] = price
	}

	return prices, nil
}

// buildPricingQueries maps a resource usage to AWS pricing queries
func (a *AWSPricingAdapter) buildPricingQueries(usage model.ResourceUsage, region string) []cost.PriceQuery {
	queries := make([]cost.PriceQuery, 0)

	switch usage.ResourceType {
	case "AWS::EC2::Instance":
		// EC2 instance pricing
		queries = append(queries, cost.PriceQuery{
			Service:       "AmazonEC2",
			ProductFamily: "Compute Instance",
			Region:        region,
			Attributes: map[string]string{
				"instanceType": usage.InstanceType,
				"tenancy":      "Shared",
				"operatingSystem": "Linux",
			},
		})

	case "AWS::RDS::DBInstance":
		// RDS instance pricing
		queries = append(queries, cost.PriceQuery{
			Service:       "AmazonRDS",
			ProductFamily: "Database Instance",
			Region:        region,
			Attributes: map[string]string{
				"instanceType": usage.InstanceType,
				"deploymentOption": "Single-AZ",
			},
		})

	case "AWS::S3::Bucket":
		// S3 storage pricing
		queries = append(queries, cost.PriceQuery{
			Service:       "AmazonS3",
			ProductFamily: "Storage",
			Region:        region,
			Attributes: map[string]string{
				"storageClass": "General Purpose",
			},
		})

	case "AWS::Lambda::Function":
		// Lambda pricing (invocations + duration)
		queries = append(queries, cost.PriceQuery{
			Service:       "AWSLambda",
			ProductFamily: "Serverless",
			Region:        region,
			Attributes: map[string]string{
				"group": "AWS-Lambda-Requests",
			},
		})

	case "AWS::CloudWatch::Alarm":
		// CloudWatch alarm pricing
		queries = append(queries, cost.PriceQuery{
			Service:       "AmazonCloudWatch",
			ProductFamily: "Alarm",
			Region:        region,
			Attributes:    map[string]string{},
		})

	case "AWS::SNS::Topic":
		// SNS pricing
		queries = append(queries, cost.PriceQuery{
			Service:       "AmazonSNS",
			ProductFamily: "API Request",
			Region:        region,
			Attributes:    map[string]string{},
		})

	case "AWS::DynamoDB::Table":
		// DynamoDB pricing
		queries = append(queries, cost.PriceQuery{
			Service:       "AmazonDynamoDB",
			ProductFamily: "Provisioned IOPS",
			Region:        region,
			Attributes:    map[string]string{},
		})

	case "AWS::SQS::Queue":
		// SQS pricing
		queries = append(queries, cost.PriceQuery{
			Service:       "AmazonSQS",
			ProductFamily: "API Request",
			Region:        region,
			Attributes:    map[string]string{},
		})
	}

	return queries
}

// calculateCost computes monthly cost from pricing result and usage
func (a *AWSPricingAdapter) calculateCost(usage model.ResourceUsage, result cost.PriceResult) float64 {
	switch usage.ResourceType {
	case "AWS::EC2::Instance", "AWS::RDS::DBInstance":
		// Compute instances: hourly price × hours/month × utilization
		return result.UnitPrice * usage.MonthlyHours * usage.UtilizationFactor

	case "AWS::S3::Bucket":
		// Storage: per GB/month × GB × utilization
		return result.UnitPrice * usage.StorageGB * usage.UtilizationFactor

	case "AWS::Lambda::Function":
		// Lambda: invocations + duration (simplified)
		return result.UnitPrice * usage.RequestsPerMonth * usage.UtilizationFactor

	case "AWS::CloudWatch::Alarm":
		// Alarms: flat per alarm
		return result.UnitPrice * usage.Quantity

	case "AWS::SNS::Topic", "AWS::SQS::Queue":
		// Requests: per million requests
		requestsInMillions := usage.RequestsPerMonth / 1000000.0
		return result.UnitPrice * requestsInMillions * usage.UtilizationFactor

	case "AWS::DynamoDB::Table":
		// DynamoDB: capacity units (simplified)
		return result.UnitPrice * usage.Quantity * usage.UtilizationFactor

	default:
		// Default: quantity × unit price × utilization
		return result.UnitPrice * usage.Quantity * usage.UtilizationFactor
	}
}