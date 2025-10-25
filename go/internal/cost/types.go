package cost

import "time"

// ServiceCode maps user-friendly service names to AWS Pricing API service names
var ServiceCode = map[string]string{
	"cloudwatch": "AmazonCloudWatch",
	"lambda":     "awslambda",
	"s3":         "AmazonS3",
	"ec2":        "AmazonEC2",
	"rds":        "AmazonRDS",
	"dynamodb":   "AmazonDynamoDB",
	"sns":        "AmazonSNS",
	"sqs":        "AmazonSQS",
	"config":     "AWSConfig",
	"cloudtrail": "AWSCloudTrail",
}

// PriceQuery represents a query to the AWS Pricing API
type PriceQuery struct {
	Service       string            // AWS service code (e.g., "AmazonCloudWatch")
	ProductFamily string            // Product family (e.g., "Alarm", "API Request")
	Region        string            // AWS region (e.g., "us-east-1")
	Attributes    map[string]string // Additional filters (e.g., usagetype, instance type)
}

// PriceResult contains the result of a pricing query
type PriceResult struct {
	Query      PriceQuery
	SKU        string    // AWS SKU identifier
	UnitPrice  float64   // Price per unit (parsed from string)
	Unit       string    // Unit of measurement (e.g., "Alarms", "GB", "Requests")
	Currency   string    // Currency code (typically "USD")
	FetchedAt  time.Time // When fetched
	FromCache  bool      // Whether from cache
}

// ServiceUsage represents usage of a specific AWS service
// The metrics map contains service-specific usage quantities
type ServiceUsage struct {
	Service string             // User-friendly service name (e.g., "cloudwatch", "lambda")
	Region  string             // AWS region
	Metrics map[string]float64 // Service-specific usage metrics

	// Example metrics by service:
	// cloudwatch: {"alarms": 10, "custom_metrics": 50, "log_data_gb": 5}
	// lambda: {"invocations": 1000000, "duration_gb_seconds": 10000}
	// s3: {"standard_storage_gb": 100, "requests_get": 100000, "requests_put": 10000}
	// ec2: {"t3_medium_hours": 730, "ebs_gp3_gb": 100}
	// rds: {"db_t3_micro_hours": 730, "storage_gb": 20}
	// dynamodb: {"read_capacity_units": 25, "write_capacity_units": 25, "storage_gb": 10}
}

// ResourceCost represents the cost of a specific resource/component
type ResourceCost struct {
	Service     string  // Service name (e.g., "CloudWatch")
	Component   string  // Component/resource type (e.g., "Alarms", "Custom Metrics")
	Description string  // Human-readable description
	Quantity    float64 // Usage quantity
	Unit        string  // Unit of measurement
	UnitPrice   float64 // Price per unit
	MonthlyCost float64 // Total cost (Quantity * UnitPrice, adjusted for billing)
}

// ServiceCost aggregates costs for a service
type ServiceCost struct {
	Service   string         // Service name (e.g., "CloudWatch")
	Region    string         // AWS region
	Resources []ResourceCost // Individual resource costs
	Total     float64        // Total cost for this service
}

// AccountCost aggregates costs for an account
type AccountCost struct {
	Name     string        // Account name (e.g., "Production")
	Services []ServiceCost // Services in this account
	Total    float64       // Total cost for this account
}

// CostEstimate contains the complete cost breakdown
type CostEstimate struct {
	// Summary
	TotalMonthly float64 // Total monthly cost
	Currency     string  // Currency (typically "USD")

	// Breakdowns
	ByAccount []AccountCost // Per-account breakdown
	ByService []ServiceCost // Per-service breakdown (aggregated)

	// Metadata
	GeneratedAt time.Time // When generated
	CacheHits   int       // Number of prices from cache
	CacheMisses int       // Number of prices fetched from API
	Errors      []string  // Any non-fatal errors encountered
}

// EstimateRequest specifies what to estimate
type EstimateRequest struct {
	// Services to estimate (can be flat or organized by account)
	Services []ServiceUsage   // Simple list (single account)
	Accounts []AccountRequest // Or organize by account

	// If neither Services nor Accounts specified, returns error
}

// AccountRequest represents services for a specific account
type AccountRequest struct {
	Name     string         // Account name
	Services []ServiceUsage // Services in this account
}

// DefaultBootstrapEstimate returns a minimal bootstrap setup
func DefaultBootstrapEstimate() EstimateRequest {
	baseServices := []ServiceUsage{
		{
			Service: "cloudwatch",
			Region:  "us-east-1",
			Metrics: map[string]float64{
				"alarms": 2, // Budget alarm + anomaly detector
			},
		},
		{
			Service: "sns",
			Region:  "us-east-1",
			Metrics: map[string]float64{
				"notifications": 100, // ~100 notifications/month
			},
		},
	}

	return EstimateRequest{
		Accounts: []AccountRequest{
			{Name: "Dev", Services: baseServices},
			{Name: "Staging", Services: baseServices},
			{Name: "Production", Services: baseServices},
		},
	}
}

// PricingClient fetches pricing data from AWS
type PricingClient interface {
	// GetPrice fetches price for a specific query
	GetPrice(query PriceQuery) (PriceResult, error)

	// GetPrices fetches multiple prices (for batch operations)
	GetPrices(queries []PriceQuery) ([]PriceResult, error)
}

// CostCalculator calculates costs based on usage
type CostCalculator interface {
	// Estimate calculates total cost
	Estimate(request EstimateRequest) (CostEstimate, error)
}
