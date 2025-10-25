package templates

import (
	"testing"

	"github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/adapters/cloudformation"
	"github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/adapters/pricing"
	"github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/adapters/usage"
	"github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/model"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// Test AnalyzeTemplate with a simple EC2 instance template
func TestAnalyzer_AnalyzeTemplate_EC2Instance(t *testing.T) {
	// Arrange: Create analyzer with mock adapters
	parser := cloudformation.NewParser()
	pricer := pricing.NewMockPricingAdapter()
	estimator := usage.NewProfileMapper()
	analyzer := NewAnalyzer(parser, pricer, estimator)

	template := `{
		"Resources": {
			"WebServer": {
				"Type": "AWS::EC2::Instance",
				"Properties": {
					"InstanceType": "t3.medium"
				}
			}
		}
	}`

	// Act: Analyze with light profile
	analysis, err := analyzer.AnalyzeTemplate(template, model.ProfileLight, "us-east-1")

	// Assert
	require.NoError(t, err)
	assert.Len(t, analysis.Resources, 1)
	assert.Equal(t, "WebServer", analysis.Resources[0].LogicalID)
	assert.Equal(t, "AWS::EC2::Instance", analysis.Resources[0].Type)

	assert.Len(t, analysis.UsageEstimates, 1)
	assert.Equal(t, "t3.medium", analysis.UsageEstimates[0].InstanceType)
	assert.Equal(t, 1.0, analysis.UsageEstimates[0].UtilizationFactor) // Always 1.0, profile baked into metrics
	assert.Equal(t, 219.0, analysis.UsageEstimates[0].MonthlyHours) // 730 * 0.30

	assert.Greater(t, analysis.EstimatedCost, 0.0)
	assert.Contains(t, analysis.ByService, "ec2")
	assert.Contains(t, analysis.ByResource, "WebServer")
	assert.Empty(t, analysis.Errors)
}

// Test AnalyzeTemplate with multiple resource types
func TestAnalyzer_AnalyzeTemplate_MultipleResources(t *testing.T) {
	// Arrange
	parser := cloudformation.NewParser()
	pricer := pricing.NewMockPricingAdapter()
	estimator := usage.NewProfileMapper()
	analyzer := NewAnalyzer(parser, pricer, estimator)

	template := `{
		"Resources": {
			"WebServer": {
				"Type": "AWS::EC2::Instance",
				"Properties": {"InstanceType": "t3.small"}
			},
			"Database": {
				"Type": "AWS::RDS::DBInstance",
				"Properties": {"DBInstanceClass": "db.t3.micro"}
			},
			"Storage": {
				"Type": "AWS::S3::Bucket"
			},
			"Function": {
				"Type": "AWS::Lambda::Function"
			},
			"Alarm": {
				"Type": "AWS::CloudWatch::Alarm"
			}
		}
	}`

	// Act
	analysis, err := analyzer.AnalyzeTemplate(template, model.ProfileModerate, "us-west-2")

	// Assert
	require.NoError(t, err)
	assert.Len(t, analysis.Resources, 5)
	assert.Len(t, analysis.UsageEstimates, 5)

	// Verify all services are represented
	assert.Contains(t, analysis.ByService, "ec2")
	assert.Contains(t, analysis.ByService, "rds")
	assert.Contains(t, analysis.ByService, "s3")
	assert.Contains(t, analysis.ByService, "lambda")
	assert.Contains(t, analysis.ByService, "cloudwatch")

	// Verify total cost is sum of all services
	totalFromServices := 0.0
	for _, cost := range analysis.ByService {
		totalFromServices += cost
	}
	assert.InDelta(t, analysis.EstimatedCost, totalFromServices, 0.01)

	assert.Empty(t, analysis.Errors)
}

// Test usage profile multipliers are applied correctly
func TestAnalyzer_UsageProfileMultipliers(t *testing.T) {
	// Arrange
	parser := cloudformation.NewParser()
	pricer := pricing.NewMockPricingAdapter()
	estimator := usage.NewProfileMapper()
	analyzer := NewAnalyzer(parser, pricer, estimator)

	template := `{
		"Resources": {
			"Instance": {
				"Type": "AWS::EC2::Instance",
				"Properties": {"InstanceType": "t3.medium"}
			}
		}
	}`

	testCases := []struct {
		profile          model.UsageProfile
		expectedMultiplier float64
		expectedHours    float64
	}{
		{model.ProfileMinimal, 0.10, 73.0},   // 730 * 0.10
		{model.ProfileLight, 0.30, 219.0},    // 730 * 0.30
		{model.ProfileModerate, 0.60, 438.0}, // 730 * 0.60
		{model.ProfileHeavy, 1.00, 730.0},    // 730 * 1.00
	}

	for _, tc := range testCases {
		t.Run(string(tc.profile), func(t *testing.T) {
			// Act
			analysis, err := analyzer.AnalyzeTemplate(template, tc.profile, "us-east-1")

			// Assert
			require.NoError(t, err)
			assert.Equal(t, 1.0, analysis.UsageEstimates[0].UtilizationFactor) // Always 1.0
			assert.Equal(t, tc.expectedHours, analysis.UsageEstimates[0].MonthlyHours)
		})
	}
}

// Test cost increases with higher profiles
func TestAnalyzer_CostScalesWithProfile(t *testing.T) {
	// Arrange
	parser := cloudformation.NewParser()
	pricer := pricing.NewMockPricingAdapter()
	estimator := usage.NewProfileMapper()
	analyzer := NewAnalyzer(parser, pricer, estimator)

	template := `{
		"Resources": {
			"Instance": {
				"Type": "AWS::EC2::Instance",
				"Properties": {"InstanceType": "t3.medium"}
			}
		}
	}`

	// Act: Get costs for each profile
	minimalAnalysis, _ := analyzer.AnalyzeTemplate(template, model.ProfileMinimal, "us-east-1")
	lightAnalysis, _ := analyzer.AnalyzeTemplate(template, model.ProfileLight, "us-east-1")
	moderateAnalysis, _ := analyzer.AnalyzeTemplate(template, model.ProfileModerate, "us-east-1")
	heavyAnalysis, _ := analyzer.AnalyzeTemplate(template, model.ProfileHeavy, "us-east-1")

	// Assert: Cost should increase with profile
	assert.Greater(t, lightAnalysis.EstimatedCost, minimalAnalysis.EstimatedCost)
	assert.Greater(t, moderateAnalysis.EstimatedCost, lightAnalysis.EstimatedCost)
	assert.Greater(t, heavyAnalysis.EstimatedCost, moderateAnalysis.EstimatedCost)

	// Rough ratio check (accounting for rounding)
	// Heavy should be ~10x minimal (1.00 / 0.10)
	ratio := heavyAnalysis.EstimatedCost / minimalAnalysis.EstimatedCost
	assert.InDelta(t, 10.0, ratio, 0.5)
}

// Test AnalyzeBootstrapOnly calculates fixed bootstrap costs
func TestAnalyzer_AnalyzeBootstrapOnly(t *testing.T) {
	// Arrange
	parser := cloudformation.NewParser()
	pricer := pricing.NewMockPricingAdapter()
	estimator := usage.NewProfileMapper()
	analyzer := NewAnalyzer(parser, pricer, estimator)

	// Act: Analyze bootstrap for 3 accounts
	analysis, err := analyzer.AnalyzeBootstrapOnly(model.ProfileLight, "us-east-1", 3)

	// Assert
	require.NoError(t, err)
	assert.Len(t, analysis.UsageEstimates, 2) // CloudWatch alarms + SNS topic

	// Find CloudWatch alarm estimate
	var alarmUsage *model.ResourceUsage
	var snsUsage *model.ResourceUsage
	for i := range analysis.UsageEstimates {
		if analysis.UsageEstimates[i].ResourceType == "AWS::CloudWatch::Alarm" {
			alarmUsage = &analysis.UsageEstimates[i]
		}
		if analysis.UsageEstimates[i].ResourceType == "AWS::SNS::Topic" {
			snsUsage = &analysis.UsageEstimates[i]
		}
	}

	require.NotNil(t, alarmUsage)
	require.NotNil(t, snsUsage)

	// 2 alarms per account × 3 accounts = 6 alarms
	assert.Equal(t, 6.0, alarmUsage.Quantity)
	assert.Equal(t, 1.0, alarmUsage.UtilizationFactor) // Always 1.0

	// 100 notifications per account × 3 accounts = 300 notifications
	assert.Equal(t, 300.0, snsUsage.RequestsPerMonth)
	assert.Equal(t, 1.0, snsUsage.UtilizationFactor) // Always 1.0

	assert.Greater(t, analysis.EstimatedCost, 0.0)
	assert.Contains(t, analysis.ByService, "cloudwatch")
	assert.Contains(t, analysis.ByService, "sns")
	assert.Empty(t, analysis.Errors)
}

// Test bootstrap cost scales with number of accounts
func TestAnalyzer_BootstrapScalesWithAccounts(t *testing.T) {
	// Arrange
	parser := cloudformation.NewParser()
	pricer := pricing.NewMockPricingAdapter()
	estimator := usage.NewProfileMapper()
	analyzer := NewAnalyzer(parser, pricer, estimator)

	// Act
	oneAccount, _ := analyzer.AnalyzeBootstrapOnly(model.ProfileLight, "us-east-1", 1)
	threeAccounts, _ := analyzer.AnalyzeBootstrapOnly(model.ProfileLight, "us-east-1", 3)
	tenAccounts, _ := analyzer.AnalyzeBootstrapOnly(model.ProfileLight, "us-east-1", 10)

	// Assert: Cost should scale linearly with accounts
	assert.Greater(t, threeAccounts.EstimatedCost, oneAccount.EstimatedCost)
	assert.Greater(t, tenAccounts.EstimatedCost, threeAccounts.EstimatedCost)

	// Rough ratio check
	ratio := threeAccounts.EstimatedCost / oneAccount.EstimatedCost
	assert.InDelta(t, 3.0, ratio, 0.5) // Should be ~3x
}

// Test invalid template returns error
func TestAnalyzer_InvalidTemplate(t *testing.T) {
	// Arrange
	parser := cloudformation.NewParser()
	pricer := pricing.NewMockPricingAdapter()
	estimator := usage.NewProfileMapper()
	analyzer := NewAnalyzer(parser, pricer, estimator)

	invalidTemplate := `{this is not valid json`

	// Act
	analysis, err := analyzer.AnalyzeTemplate(invalidTemplate, model.ProfileLight, "us-east-1")

	// Assert
	assert.Error(t, err)
	assert.Nil(t, analysis)
	assert.Contains(t, err.Error(), "failed to parse template")
}

// Test empty template returns error
func TestAnalyzer_EmptyTemplate(t *testing.T) {
	// Arrange
	parser := cloudformation.NewParser()
	pricer := pricing.NewMockPricingAdapter()
	estimator := usage.NewProfileMapper()
	analyzer := NewAnalyzer(parser, pricer, estimator)

	emptyTemplate := `{"Resources": {}}`

	// Act
	analysis, err := analyzer.AnalyzeTemplate(emptyTemplate, model.ProfileLight, "us-east-1")

	// Assert
	assert.Error(t, err)
	assert.Nil(t, analysis)
	assert.Contains(t, err.Error(), "template contains no resources")
}

// Test YAML template support
func TestAnalyzer_YAMLTemplate(t *testing.T) {
	// Arrange
	parser := cloudformation.NewParser()
	pricer := pricing.NewMockPricingAdapter()
	estimator := usage.NewProfileMapper()
	analyzer := NewAnalyzer(parser, pricer, estimator)

	yamlTemplate := `
Resources:
  WebServer:
    Type: AWS::EC2::Instance
    Properties:
      InstanceType: t3.small
  Database:
    Type: AWS::RDS::DBInstance
    Properties:
      DBInstanceClass: db.t3.micro
`

	// Act
	analysis, err := analyzer.AnalyzeTemplate(yamlTemplate, model.ProfileModerate, "us-west-2")

	// Assert
	require.NoError(t, err)
	assert.Len(t, analysis.Resources, 2)
	assert.Contains(t, analysis.ByService, "ec2")
	assert.Contains(t, analysis.ByService, "rds")
}

// Test cost aggregation correctness
func TestAnalyzer_CostAggregation(t *testing.T) {
	// Arrange
	parser := cloudformation.NewParser()
	pricer := pricing.NewMockPricingAdapter()
	estimator := usage.NewProfileMapper()
	analyzer := NewAnalyzer(parser, pricer, estimator)

	template := `{
		"Resources": {
			"Instance1": {
				"Type": "AWS::EC2::Instance",
				"Properties": {"InstanceType": "t3.small"}
			},
			"Instance2": {
				"Type": "AWS::EC2::Instance",
				"Properties": {"InstanceType": "t3.medium"}
			}
		}
	}`

	// Act
	analysis, err := analyzer.AnalyzeTemplate(template, model.ProfileHeavy, "us-east-1")

	// Assert
	require.NoError(t, err)

	// Verify resource-level costs sum to total
	resourceTotal := 0.0
	for _, cost := range analysis.ByResource {
		resourceTotal += cost
	}
	assert.InDelta(t, analysis.EstimatedCost, resourceTotal, 0.01)

	// Verify service-level costs sum to total
	serviceTotal := 0.0
	for _, cost := range analysis.ByService {
		serviceTotal += cost
	}
	assert.InDelta(t, analysis.EstimatedCost, serviceTotal, 0.01)

	// Both instances are EC2, so only one service entry
	assert.Len(t, analysis.ByService, 1)
	assert.Contains(t, analysis.ByService, "ec2")

	// But two resource entries
	assert.Len(t, analysis.ByResource, 2)
	assert.Contains(t, analysis.ByResource, "Instance1")
	assert.Contains(t, analysis.ByResource, "Instance2")
}

// Test S3 storage estimation varies by profile
func TestAnalyzer_S3StorageByProfile(t *testing.T) {
	// Arrange
	parser := cloudformation.NewParser()
	pricer := pricing.NewMockPricingAdapter()
	estimator := usage.NewProfileMapper()
	analyzer := NewAnalyzer(parser, pricer, estimator)

	template := `{
		"Resources": {
			"Bucket": {"Type": "AWS::S3::Bucket"}
		}
	}`

	// Act
	minimalAnalysis, _ := analyzer.AnalyzeTemplate(template, model.ProfileMinimal, "us-east-1")
	lightAnalysis, _ := analyzer.AnalyzeTemplate(template, model.ProfileLight, "us-east-1")
	moderateAnalysis, _ := analyzer.AnalyzeTemplate(template, model.ProfileModerate, "us-east-1")
	heavyAnalysis, _ := analyzer.AnalyzeTemplate(template, model.ProfileHeavy, "us-east-1")

	// Assert: Storage should increase with profile
	// Minimal: 1 GB, Light: 10 GB, Moderate: 100 GB, Heavy: 1000 GB
	assert.Equal(t, 1.0, minimalAnalysis.UsageEstimates[0].StorageGB)
	assert.Equal(t, 10.0, lightAnalysis.UsageEstimates[0].StorageGB)
	assert.Equal(t, 100.0, moderateAnalysis.UsageEstimates[0].StorageGB)
	assert.Equal(t, 1000.0, heavyAnalysis.UsageEstimates[0].StorageGB)

	// Cost should scale proportionally
	assert.Greater(t, heavyAnalysis.EstimatedCost, moderateAnalysis.EstimatedCost)
}

// Test Lambda invocations vary by profile
func TestAnalyzer_LambdaInvocationsByProfile(t *testing.T) {
	// Arrange
	parser := cloudformation.NewParser()
	pricer := pricing.NewMockPricingAdapter()
	estimator := usage.NewProfileMapper()
	analyzer := NewAnalyzer(parser, pricer, estimator)

	template := `{
		"Resources": {
			"Function": {"Type": "AWS::Lambda::Function"}
		}
	}`

	// Act
	minimalAnalysis, _ := analyzer.AnalyzeTemplate(template, model.ProfileMinimal, "us-east-1")
	heavyAnalysis, _ := analyzer.AnalyzeTemplate(template, model.ProfileHeavy, "us-east-1")

	// Assert: Invocations should vary by profile
	// Minimal: 10K, Heavy: 10M (1000x difference)
	assert.Equal(t, 10000.0, minimalAnalysis.UsageEstimates[0].RequestsPerMonth)
	assert.Equal(t, 10000000.0, heavyAnalysis.UsageEstimates[0].RequestsPerMonth)

	assert.Greater(t, heavyAnalysis.EstimatedCost, minimalAnalysis.EstimatedCost)
}

// Test RDS runs 24/7 regardless of profile
func TestAnalyzer_RDSAlwaysOn(t *testing.T) {
	// Arrange
	parser := cloudformation.NewParser()
	pricer := pricing.NewMockPricingAdapter()
	estimator := usage.NewProfileMapper()
	analyzer := NewAnalyzer(parser, pricer, estimator)

	template := `{
		"Resources": {
			"Database": {
				"Type": "AWS::RDS::DBInstance",
				"Properties": {"DBInstanceClass": "db.t3.small"}
			}
		}
	}`

	// Act
	minimalAnalysis, _ := analyzer.AnalyzeTemplate(template, model.ProfileMinimal, "us-east-1")
	heavyAnalysis, _ := analyzer.AnalyzeTemplate(template, model.ProfileHeavy, "us-east-1")

	// Assert: RDS always runs 730 hours/month (24/7) regardless of profile
	assert.Equal(t, 730.0, minimalAnalysis.UsageEstimates[0].MonthlyHours)
	assert.Equal(t, 730.0, heavyAnalysis.UsageEstimates[0].MonthlyHours)

	// Costs should be equal since RDS ignores profile for uptime
	assert.InDelta(t, minimalAnalysis.EstimatedCost, heavyAnalysis.EstimatedCost, 0.01)
}

// Test default instance types when not specified
func TestAnalyzer_DefaultInstanceTypes(t *testing.T) {
	// Arrange
	parser := cloudformation.NewParser()
	pricer := pricing.NewMockPricingAdapter()
	estimator := usage.NewProfileMapper()
	analyzer := NewAnalyzer(parser, pricer, estimator)

	template := `{
		"Resources": {
			"EC2NoType": {
				"Type": "AWS::EC2::Instance"
			},
			"RDSNoType": {
				"Type": "AWS::RDS::DBInstance"
			}
		}
	}`

	// Act
	analysis, err := analyzer.AnalyzeTemplate(template, model.ProfileLight, "us-east-1")

	// Assert
	require.NoError(t, err)

	// Find EC2 and RDS estimates
	var ec2Usage, rdsUsage *model.ResourceUsage
	for i := range analysis.UsageEstimates {
		if analysis.UsageEstimates[i].ResourceType == "AWS::EC2::Instance" {
			ec2Usage = &analysis.UsageEstimates[i]
		}
		if analysis.UsageEstimates[i].ResourceType == "AWS::RDS::DBInstance" {
			rdsUsage = &analysis.UsageEstimates[i]
		}
	}

	require.NotNil(t, ec2Usage)
	require.NotNil(t, rdsUsage)

	// Defaults from profile_mapper.go
	assert.Equal(t, "t3.medium", ec2Usage.InstanceType)
	assert.Equal(t, "db.t3.small", rdsUsage.InstanceType)
}