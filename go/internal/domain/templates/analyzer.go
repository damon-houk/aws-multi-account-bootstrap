package templates

import (
	"fmt"

	"github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/model"
	"github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/ports"
)

// Analyzer orchestrates template analysis using ports (hexagonal architecture)
// This is pure business logic with NO dependencies on AWS, CloudFormation, or pricing APIs
type Analyzer struct {
	parser    ports.TemplateParser
	pricer    ports.ResourcePricer
	estimator ports.UsageEstimator
}

// NewAnalyzer creates an analyzer with injected dependencies (ports)
func NewAnalyzer(
	parser ports.TemplateParser,
	pricer ports.ResourcePricer,
	estimator ports.UsageEstimator,
) *Analyzer {
	return &Analyzer{
		parser:    parser,
		pricer:    pricer,
		estimator: estimator,
	}
}

// AnalyzeTemplate is the main domain function
// Business logic: Parse → Estimate Usage → Price → Aggregate
func (a *Analyzer) AnalyzeTemplate(
	templateContent string,
	profile model.UsageProfile,
	region string,
) (*model.TemplateAnalysis, error) {
	analysis := &model.TemplateAnalysis{
		UsageProfile: profile,
		Region:       region,
		ByService:    make(map[string]float64),
		ByResource:   make(map[string]float64),
		Errors:       make([]string, 0),
	}

	// Step 1: Parse template to extract resources (through port)
	resources, err := a.parser.ParseTemplate(templateContent)
	if err != nil {
		return nil, fmt.Errorf("failed to parse template: %w", err)
	}
	analysis.Resources = resources

	// Step 2: Estimate usage for each resource (through port)
	usageEstimates := make([]model.ResourceUsage, 0, len(resources))
	for _, resource := range resources {
		usage := a.estimator.EstimateUsage(resource, profile)
		usageEstimates = append(usageEstimates, usage)
	}
	analysis.UsageEstimates = usageEstimates

	// Step 3: Get pricing for each usage estimate (through port)
	totalCost := 0.0
	for _, usage := range usageEstimates {
		cost, err := a.pricer.GetPrice(usage, region)
		if err != nil {
			// Non-fatal: log error and continue
			analysis.Errors = append(analysis.Errors,
				fmt.Sprintf("Failed to price %s: %v", usage.LogicalID, err))
			continue
		}

		// Aggregate costs
		totalCost += cost
		analysis.ByService[usage.ServiceName] += cost
		analysis.ByResource[usage.LogicalID] = cost
	}

	analysis.EstimatedCost = totalCost

	return analysis, nil
}

// AnalyzeBootstrapOnly estimates cost for bootstrap infrastructure only
// Business logic: Fixed set of resources (CloudWatch alarms, SNS topics)
func (a *Analyzer) AnalyzeBootstrapOnly(
	profile model.UsageProfile,
	region string,
	numAccounts int,
) (*model.TemplateAnalysis, error) {
	// Bootstrap resources per account:
	// - 2 CloudWatch alarms (billing + anomaly)
	// - 1 SNS topic (notifications)

	analysis := &model.TemplateAnalysis{
		UsageProfile: profile,
		Region:       region,
		ByService:    make(map[string]float64),
		ByResource:   make(map[string]float64),
		Resources:    make([]model.Resource, 0),
		Errors:       make([]string, 0),
	}

	// Create usage estimates for bootstrap resources
	usageEstimates := []model.ResourceUsage{
		{
			ResourceType:      "AWS::CloudWatch::Alarm",
			LogicalID:         "BillingAlarm",
			ServiceName:       "cloudwatch",
			Quantity:          float64(numAccounts * 2), // 2 alarms per account
			UtilizationFactor: 1.0,                      // Alarms always active
		},
		{
			ResourceType:      "AWS::SNS::Topic",
			LogicalID:         "NotificationTopic",
			ServiceName:       "sns",
			RequestsPerMonth:  100 * float64(numAccounts), // ~100 notifications/month per account
			UtilizationFactor: 1.0,                        // Profile not applied for bootstrap
		},
	}

	analysis.UsageEstimates = usageEstimates

	// Price each resource
	totalCost := 0.0
	for _, usage := range usageEstimates {
		cost, err := a.pricer.GetPrice(usage, region)
		if err != nil {
			analysis.Errors = append(analysis.Errors,
				fmt.Sprintf("Failed to price %s: %v", usage.LogicalID, err))
			continue
		}

		totalCost += cost
		analysis.ByService[usage.ServiceName] += cost
		analysis.ByResource[usage.LogicalID] = cost
	}

	analysis.EstimatedCost = totalCost

	return analysis, nil
}