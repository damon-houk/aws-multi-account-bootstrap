package ports

import "github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/model"

// UsageEstimator estimates resource usage based on profiles and properties
// Port (interface) - implements business rules for mapping templates to usage
type UsageEstimator interface {
	// EstimateUsage converts a template resource + profile into usage metrics
	// Business logic: Extract properties, apply profile multipliers, infer defaults
	// Input: Template resource and usage profile
	// Output: Estimated usage metrics (hours, GB, requests, etc.)
	EstimateUsage(resource model.Resource, profile model.UsageProfile) model.ResourceUsage
}