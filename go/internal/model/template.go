package model

// UsageProfile represents the 4 growth stages
type UsageProfile string

const (
	ProfileMinimal  UsageProfile = "minimal"  // POC/Testing (10% utilization)
	ProfileLight    UsageProfile = "light"    // Small team (30% utilization)
	ProfileModerate UsageProfile = "moderate" // Startup (60% utilization)
	ProfileHeavy    UsageProfile = "heavy"    // Enterprise (100% utilization)
)

// UsageMultipliers define scaling factors per profile
// These represent expected utilization/scale for resources
var UsageMultipliers = map[UsageProfile]float64{
	ProfileMinimal:  0.10, // 10% - POC/testing workloads
	ProfileLight:    0.30, // 30% - Development/small production
	ProfileModerate: 0.60, // 60% - Growing production
	ProfileHeavy:    1.00, // 100% - Full-scale production
}

// GetMultiplier returns the scaling factor for a profile
func (p UsageProfile) GetMultiplier() float64 {
	multiplier, ok := UsageMultipliers[p]
	if !ok {
		return UsageMultipliers[ProfileLight] // Default to light
	}
	return multiplier
}

// Resource represents an infrastructure component discovered in a template
type Resource struct {
	Type       string                 // e.g., "AWS::EC2::Instance"
	LogicalID  string                 // e.g., "WebServer"
	Properties map[string]interface{} // Raw properties from template
}

// ResourceUsage represents estimated usage for a resource
type ResourceUsage struct {
	ResourceType       string  // e.g., "AWS::EC2::Instance"
	LogicalID          string  // From template
	ServiceName        string  // e.g., "ec2", "rds", "s3"
	InstanceType       string  // e.g., "t3.medium", "db.t3.small"
	Quantity           float64 // Number of units (instances, GB, etc.)
	UtilizationFactor  float64 // Profile multiplier applied
	MonthlyHours       float64 // For compute resources
	StorageGB          float64 // For storage resources
	RequestsPerMonth   float64 // For API/function resources
}

// TemplateAnalysis is the result of analyzing a template
type TemplateAnalysis struct {
	Resources      []Resource         // Discovered resources
	UsageEstimates []ResourceUsage    // Estimated usage per resource
	EstimatedCost  float64            // Total monthly cost
	ByService      map[string]float64 // Cost breakdown by service
	ByResource     map[string]float64 // Cost breakdown by logical ID
	UsageProfile   UsageProfile       // Profile used
	Region         string             // AWS region
	Errors         []string           // Non-fatal errors during analysis
}
