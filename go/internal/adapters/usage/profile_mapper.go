package usage

import (
	"fmt"
	"strings"

	"github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/model"
	"github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/ports"
)

// ProfileMapper implements ports.UsageEstimator
// Business logic: Maps resource properties + usage profile → usage metrics
type ProfileMapper struct{}

// NewProfileMapper creates a usage estimator based on profiles
func NewProfileMapper() ports.UsageEstimator {
	return &ProfileMapper{}
}

// EstimateUsage estimates resource usage based on properties and profile
func (m *ProfileMapper) EstimateUsage(resource model.Resource, profile model.UsageProfile) model.ResourceUsage {
	usage := model.ResourceUsage{
		ResourceType:      resource.Type,
		LogicalID:         resource.LogicalID,
		UtilizationFactor: 1.0, // Profile is baked into usage metrics, not applied as multiplier
	}

	// Map resource type to service name
	usage.ServiceName = m.extractServiceName(resource.Type)

	// Estimate usage based on resource type
	switch resource.Type {
	case "AWS::EC2::Instance":
		m.estimateEC2Usage(&usage, resource, profile)
	case "AWS::RDS::DBInstance":
		m.estimateRDSUsage(&usage, resource, profile)
	case "AWS::S3::Bucket":
		m.estimateS3Usage(&usage, resource, profile)
	case "AWS::Lambda::Function":
		m.estimateLambdaUsage(&usage, resource, profile)
	case "AWS::CloudWatch::Alarm":
		m.estimateCloudWatchAlarmUsage(&usage, resource, profile)
	case "AWS::SNS::Topic":
		m.estimateSNSUsage(&usage, resource, profile)
	case "AWS::DynamoDB::Table":
		m.estimateDynamoDBUsage(&usage, resource, profile)
	case "AWS::SQS::Queue":
		m.estimateSQSUsage(&usage, resource, profile)
	default:
		// Default estimation
		usage.Quantity = 1
	}

	return usage
}

// estimateEC2Usage estimates EC2 instance usage
func (m *ProfileMapper) estimateEC2Usage(usage *model.ResourceUsage, resource model.Resource, profile model.UsageProfile) {
	// Extract instance type from properties
	if instanceType, ok := resource.Properties["InstanceType"].(string); ok {
		usage.InstanceType = instanceType
	} else {
		usage.InstanceType = "t3.medium" // Default
	}

	// Monthly hours based on profile
	// Minimal: 73 hours (10% of 730)
	// Light: 219 hours (30% of 730)
	// Moderate: 438 hours (60% of 730)
	// Heavy: 730 hours (100% - always on)
	hoursPerMonth := 730.0
	usage.MonthlyHours = hoursPerMonth * profile.GetMultiplier()
	usage.Quantity = 1
}

// estimateRDSUsage estimates RDS database usage
func (m *ProfileMapper) estimateRDSUsage(usage *model.ResourceUsage, resource model.Resource, profile model.UsageProfile) {
	// Extract DB instance class
	if instanceClass, ok := resource.Properties["DBInstanceClass"].(string); ok {
		usage.InstanceType = instanceClass
	} else {
		usage.InstanceType = "db.t3.small" // Default
	}

	// RDS typically runs 24/7 even in lower environments
	// Profile affects utilization (connections, queries) not uptime
	usage.MonthlyHours = 730.0
	usage.Quantity = 1
}

// estimateS3Usage estimates S3 bucket usage
func (m *ProfileMapper) estimateS3Usage(usage *model.ResourceUsage, resource model.Resource, profile model.UsageProfile) {
	// S3 storage based on profile
	storageByProfile := map[model.UsageProfile]float64{
		model.ProfileMinimal:  1.0,    // 1 GB
		model.ProfileLight:    10.0,   // 10 GB
		model.ProfileModerate: 100.0,  // 100 GB
		model.ProfileHeavy:    1000.0, // 1 TB
	}

	usage.StorageGB = storageByProfile[profile]
	usage.RequestsPerMonth = usage.StorageGB * 100 // Estimate: 100 requests per GB
	usage.Quantity = 1
}

// estimateLambdaUsage estimates Lambda function usage
func (m *ProfileMapper) estimateLambdaUsage(usage *model.ResourceUsage, resource model.Resource, profile model.UsageProfile) {
	// Lambda invocations based on profile
	invocationsByProfile := map[model.UsageProfile]float64{
		model.ProfileMinimal:  10000,    // 10K invocations/month
		model.ProfileLight:    100000,   // 100K invocations/month
		model.ProfileModerate: 1000000,  // 1M invocations/month
		model.ProfileHeavy:    10000000, // 10M invocations/month
	}

	usage.RequestsPerMonth = invocationsByProfile[profile]
	usage.Quantity = 1
}

// estimateCloudWatchAlarmUsage estimates CloudWatch alarm usage
func (m *ProfileMapper) estimateCloudWatchAlarmUsage(usage *model.ResourceUsage, resource model.Resource, profile model.UsageProfile) {
	// Alarms are flat monthly cost per alarm
	usage.Quantity = 1
	// Utilization = 1.0 (alarms always active)
	usage.UtilizationFactor = 1.0
}

// estimateSNSUsage estimates SNS topic usage
func (m *ProfileMapper) estimateSNSUsage(usage *model.ResourceUsage, resource model.Resource, profile model.UsageProfile) {
	// SNS notifications based on profile
	notificationsByProfile := map[model.UsageProfile]float64{
		model.ProfileMinimal:  100,   // 100 notifications/month
		model.ProfileLight:    1000,  // 1K notifications/month
		model.ProfileModerate: 10000, // 10K notifications/month
		model.ProfileHeavy:    100000, // 100K notifications/month
	}

	usage.RequestsPerMonth = notificationsByProfile[profile]
	usage.Quantity = 1
}

// estimateDynamoDBUsage estimates DynamoDB table usage
func (m *ProfileMapper) estimateDynamoDBUsage(usage *model.ResourceUsage, resource model.Resource, profile model.UsageProfile) {
	// DynamoDB capacity units based on profile
	capacityByProfile := map[model.UsageProfile]float64{
		model.ProfileMinimal:  5.0,  // 5 RCU/WCU
		model.ProfileLight:    10.0, // 10 RCU/WCU
		model.ProfileModerate: 25.0, // 25 RCU/WCU
		model.ProfileHeavy:    100.0, // 100 RCU/WCU
	}

	usage.Quantity = capacityByProfile[profile]
}

// estimateSQSUsage estimates SQS queue usage
func (m *ProfileMapper) estimateSQSUsage(usage *model.ResourceUsage, resource model.Resource, profile model.UsageProfile) {
	// SQS messages based on profile
	messagesByProfile := map[model.UsageProfile]float64{
		model.ProfileMinimal:  10000,   // 10K messages/month
		model.ProfileLight:    100000,  // 100K messages/month
		model.ProfileModerate: 1000000, // 1M messages/month
		model.ProfileHeavy:    10000000, // 10M messages/month
	}

	usage.RequestsPerMonth = messagesByProfile[profile]
	usage.Quantity = 1
}

// extractServiceName extracts the service name from resource type
// e.g., "AWS::EC2::Instance" → "ec2"
func (m *ProfileMapper) extractServiceName(resourceType string) string {
	parts := strings.Split(resourceType, "::")
	if len(parts) >= 2 {
		return strings.ToLower(parts[1])
	}
	return "unknown"
}

// Helper to safely extract string property
func getStringProperty(props map[string]interface{}, key string, defaultValue string) string {
	if val, ok := props[key].(string); ok {
		return val
	}
	return defaultValue
}

// Helper to safely extract float property
func getFloatProperty(props map[string]interface{}, key string, defaultValue float64) float64 {
	if val, ok := props[key].(float64); ok {
		return val
	}
	if val, ok := props[key].(int); ok {
		return float64(val)
	}
	return defaultValue
}

// Helper function placeholder (not used but showing pattern)
var _ = getStringProperty
var _ = getFloatProperty
var _ = fmt.Sprintf