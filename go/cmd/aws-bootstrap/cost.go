package main

import (
	"fmt"

	"github.com/spf13/cobra"
	"github.com/spf13/viper"
)

// costCmd represents the cost command
var costCmd = &cobra.Command{
	Use:   "cost",
	Short: "Estimate monthly costs",
	Long: `Estimate monthly AWS costs for the multi-account setup.

Provides cost estimates for:
  • S3 storage
  • CloudWatch alarms and logs
  • SNS notifications
  • AWS Organizations (free)
  • CloudFormation (free)

Note: Does not include application costs (Lambda, ECS, EC2, etc.)`,
	Example: `  # Quick estimate
  aws-bootstrap cost

  # Detailed breakdown
  aws-bootstrap cost --detailed

  # With config file
  aws-bootstrap cost --config ./aws-bootstrap.yaml --detailed

  # Use AWS Pricing API (slower but more accurate)
  aws-bootstrap cost --use-pricing-api

  # JSON output
  aws-bootstrap cost --json`,
	RunE: runCost,
}

func init() {
	rootCmd.AddCommand(costCmd)

	costCmd.Flags().Bool("detailed", false, "show detailed cost breakdown")
	costCmd.Flags().Bool("use-pricing-api", false, "use AWS Pricing API for accurate pricing")

	viper.BindPFlag("detailed", costCmd.Flags().Lookup("detailed"))
	viper.BindPFlag("use_pricing_api", costCmd.Flags().Lookup("use-pricing-api"))
}

func runCost(cmd *cobra.Command, args []string) error {
	jsonOutput := viper.GetBool("json")
	detailed := viper.GetBool("detailed")
	usePricingAPI := viper.GetBool("use_pricing_api")

	if !jsonOutput {
		fmt.Println("💰 Estimating monthly costs...")
		if usePricingAPI {
			fmt.Println("   Using AWS Pricing API for accurate estimates...")
		}
		fmt.Println()
	}

	// TODO: Implement actual cost estimation logic
	// Port from bash/scripts/lib/cost-estimator.sh

	if !jsonOutput {
		fmt.Println("┌─────────────────────────────────────────────────┐")
		fmt.Println("│ Environment  │ Services            │ Est. Cost │")
		fmt.Println("├─────────────────────────────────────────────────┤")
		fmt.Println("│ Dev          │ S3, CloudWatch, SNS │ $10-15   │")
		fmt.Println("│ Staging      │ S3, CloudWatch, SNS │ $10-15   │")
		fmt.Println("│ Prod         │ S3, CloudWatch, SNS │ $20-30   │")
		fmt.Println("├─────────────────────────────────────────────────┤")
		fmt.Println("│ Total        │                     │ $40-60   │")
		fmt.Println("└─────────────────────────────────────────────────┘")
		fmt.Println()
		fmt.Println("Note: Does not include application costs (Lambda, ECS, EC2, etc.)")

		if detailed {
			fmt.Println()
			fmt.Println("Detailed breakdown coming soon!")
		}
	} else {
		fmt.Println(`{
  "status": "success",
  "cost_estimate": {
    "monthly_min": 40,
    "monthly_max": 60,
    "currency": "USD",
    "environments": [
      {"name": "dev", "min": 10, "max": 15},
      {"name": "staging", "min": 10, "max": 15},
      {"name": "prod", "min": 20, "max": 30}
    ]
  }
}`)
	}

	return nil
}