package pricing

import (
	"github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/model"
	"github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/ports"
)

// MockPricingAdapter implements ports.ResourcePricer with hardcoded prices
// Used for testing without AWS API calls
type MockPricingAdapter struct {
	prices map[string]float64
}

// NewMockPricingAdapter creates a mock pricing adapter with default prices
func NewMockPricingAdapter() ports.ResourcePricer {
	return &MockPricingAdapter{
		prices: map[string]float64{
			// Per-hour prices
			"AWS::EC2::Instance.t3.micro":   0.0104,
			"AWS::EC2::Instance.t3.small":   0.0208,
			"AWS::EC2::Instance.t3.medium":  0.0416,
			"AWS::EC2::Instance.t3.large":   0.0832,
			"AWS::RDS::DBInstance.db.t3.micro":  0.017,
			"AWS::RDS::DBInstance.db.t3.small":  0.034,
			"AWS::RDS::DBInstance.db.t3.medium": 0.068,

			// Per-GB-month prices
			"AWS::S3::Bucket":        0.023,
			"AWS::EBS::Volume.gp3":   0.08,

			// Per-million-requests prices
			"AWS::Lambda::Function":  0.20,
			"AWS::SNS::Topic":        0.50,
			"AWS::SQS::Queue":        0.40,

			// Flat monthly prices
			"AWS::CloudWatch::Alarm": 0.10,

			// DynamoDB per-unit prices
			"AWS::DynamoDB::Table.read":  0.00013,
			"AWS::DynamoDB::Table.write": 0.00065,
		},
	}
}

// GetPrice returns mock monthly cost for a resource
func (m *MockPricingAdapter) GetPrice(usage model.ResourceUsage, region string) (float64, error) {
	// Build key based on resource type and instance type
	key := usage.ResourceType
	if usage.InstanceType != "" {
		key = usage.ResourceType + "." + usage.InstanceType
	}

	// Get base price
	basePrice, ok := m.prices[key]
	if !ok {
		// Default to reasonable estimate if not found
		basePrice = 10.0 // $10/month default
	}

	// Calculate monthly cost based on resource type
	switch usage.ResourceType {
	case "AWS::EC2::Instance", "AWS::RDS::DBInstance":
		// Hourly price × hours/month × utilization
		return basePrice * usage.MonthlyHours * usage.UtilizationFactor, nil

	case "AWS::S3::Bucket":
		// Per-GB-month × GB × utilization
		return basePrice * usage.StorageGB * usage.UtilizationFactor, nil

	case "AWS::Lambda::Function", "AWS::SNS::Topic", "AWS::SQS::Queue":
		// Per-million-requests × (requests / 1M) × utilization
		requestsInMillions := usage.RequestsPerMonth / 1000000.0
		return basePrice * requestsInMillions * usage.UtilizationFactor, nil

	case "AWS::CloudWatch::Alarm":
		// Flat per alarm × quantity
		return basePrice * usage.Quantity, nil

	case "AWS::DynamoDB::Table":
		// Simplified: quantity × price × utilization
		return basePrice * usage.Quantity * usage.UtilizationFactor, nil

	default:
		// Default: quantity × price × utilization
		return basePrice * usage.Quantity * usage.UtilizationFactor, nil
	}
}

// GetPrices batch fetches mock pricing
func (m *MockPricingAdapter) GetPrices(usages []model.ResourceUsage, region string) (map[string]float64, error) {
	prices := make(map[string]float64)

	for _, usage := range usages {
		price, _ := m.GetPrice(usage, region)
		prices[usage.LogicalID] = price
	}

	return prices, nil
}