package ports

import "github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/model"

// ResourcePricer gets pricing information for resources
// Port (interface) - can be implemented by AWS Pricing API, mock data, cached prices, etc.
type ResourcePricer interface {
	// GetPrice returns the estimated monthly cost for a resource's usage
	// Input: Resource usage estimate and AWS region
	// Output: Monthly cost in USD
	// Error: If pricing data unavailable or resource type unsupported
	GetPrice(usage model.ResourceUsage, region string) (float64, error)

	// GetPrices batch fetches pricing for multiple resources
	// More efficient than calling GetPrice repeatedly
	// Returns: Map of logical ID → monthly cost
	GetPrices(usages []model.ResourceUsage, region string) (map[string]float64, error)
}