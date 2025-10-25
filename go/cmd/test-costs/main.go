package main

import (
	"fmt"
	"log"

	"github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/adapters/pricing"
	"github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/adapters/usage"
	"github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/cost"
	"github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/domain/templates"
	"github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/model"
)

func main() {
	// Initialize analyzer with REAL AWS Pricing API (same as wizard does)
	fmt.Println("Initializing cost estimator with real AWS Pricing API...")
	fmt.Println()

	// Create file-based cache for pricing data (7-day TTL)
	priceCache, err := cost.NewFilePriceCache()
	if err != nil {
		log.Printf("Warning: Failed to create price cache: %v (using without cache)\n", err)
		priceCache = nil // Continue without cache
	}

	// Create HTTP client for AWS Pricing API
	httpClient := cost.NewHTTPPricingClient(priceCache)

	// Create AWS pricing adapter with real pricing client
	realPricer := pricing.NewAWSPricingAdapter(httpClient)
	estimator := usage.NewProfileMapper()
	analyzer := templates.NewAnalyzer(nil, realPricer, estimator)

	// Test all usage profiles
	profiles := []model.UsageProfile{
		model.ProfileMinimal,
		model.ProfileLight,
		model.ProfileModerate,
		model.ProfileHeavy,
	}

	fmt.Println("Bootstrap Cost Estimation (3 Accounts)")
	fmt.Println("========================================")
	fmt.Println()

	for _, profile := range profiles {
		analysis, err := analyzer.AnalyzeBootstrapOnly(profile, "us-east-1", 3)
		if err != nil {
			fmt.Printf("Error for %s: %v\n", profile, err)
			continue
		}

		profileName := map[model.UsageProfile]string{
			model.ProfileMinimal:  "Minimal  (POC/Testing)",
			model.ProfileLight:    "Light    (Small team)",
			model.ProfileModerate: "Moderate (Startup)",
			model.ProfileHeavy:    "Heavy    (Enterprise)",
		}

		fmt.Printf("%s: $%.2f/month\n", profileName[profile], analysis.EstimatedCost)

		// Show breakdown
		for svcName, cost := range analysis.ByService {
			fmt.Printf("  - %s: $%.2f\n", svcName, cost)
		}
		fmt.Println()
	}

	// Show resource details for Light profile
	fmt.Println("Resources Included (Light Profile):")
	fmt.Println("------------------------------------")

	analysis, _ := analyzer.AnalyzeBootstrapOnly(model.ProfileLight, "us-east-1", 3)
	for _, usage := range analysis.UsageEstimates {
		switch usage.ResourceType {
		case "AWS::CloudWatch::Alarm":
			fmt.Printf("✓ %.0f CloudWatch alarms (2 per account)\n", usage.Quantity)
		case "AWS::SNS::Topic":
			fmt.Printf("✓ SNS notifications (~%.0f per month)\n", usage.RequestsPerMonth)
		}
	}

	if len(analysis.Errors) > 0 {
		fmt.Println("\nWarnings:")
		for _, err := range analysis.Errors {
			fmt.Printf("  ⚠ %s\n", err)
		}
	} else {
		fmt.Println("\n✓ No errors - Cost estimation working correctly!")
	}
}
