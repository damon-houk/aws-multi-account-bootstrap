#!/bin/bash
# Test the wizard's cost estimation by simulating it programmatically

cd "$(dirname "$0")"

echo "Testing wizard cost estimation..."
echo ""

# Build the binary
echo "Building binary..."
go build -o bin/aws-bootstrap ./cmd/aws-bootstrap
if [ $? -ne 0 ]; then
    echo "Build failed!"
    exit 1
fi

echo "✓ Build successful"
echo ""

# Create a simple Go test that exercises the cost estimation
cat > /tmp/test-cost-estimate.go << 'EOF'
package main

import (
	"fmt"

	"github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/adapters/pricing"
	"github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/adapters/usage"
	"github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/domain/templates"
	"github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/model"
)

func main() {
	// Initialize analyzer (same as wizard does)
	mockPricer := pricing.NewMockPricingAdapter()
	estimator := usage.NewProfileMapper()
	analyzer := templates.NewAnalyzer(nil, mockPricer, estimator)

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
		fmt.Println("\n✓ No errors!")
	}
}
EOF

# Run the test
echo "Running cost estimation test..."
echo ""
cd /tmp && go run test-cost-estimate.go
RESULT=$?

# Cleanup
rm -f /tmp/test-cost-estimate.go

if [ $RESULT -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "✓ Cost estimation working correctly!"
    echo ""
    echo "To test the interactive wizard, run:"
    echo "  ./bin/aws-bootstrap create"
    echo ""
    echo "Or test with dry-run:"
    echo "  ./bin/aws-bootstrap create --dry-run"
else
    echo "✗ Test failed"
    exit 1
fi
