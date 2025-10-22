package main

import (
	"fmt"

	"github.com/spf13/cobra"
	"github.com/spf13/viper"
)

// validateCmd represents the validate command
var validateCmd = &cobra.Command{
	Use:   "validate",
	Short: "Validate configuration",
	Long: `Validate configuration file and required values without creating resources.

Checks:
  • Config file syntax (YAML/JSON)
  • Required fields present
  • Value format validation (project code, email, OU ID)
  • AWS credentials
  • GitHub token`,
	Example: `  # Validate default config file
  aws-bootstrap validate

  # Validate specific config file
  aws-bootstrap validate --config ./prod-config.yaml

  # JSON output
  aws-bootstrap validate --config ./config.yaml --json`,
	RunE: runValidate,
}

func init() {
	rootCmd.AddCommand(validateCmd)
}

func runValidate(cmd *cobra.Command, args []string) error {
	jsonOutput := viper.GetBool("json")

	if !jsonOutput {
		fmt.Println("🔍 Validating configuration...")
		fmt.Println()
	}

	// TODO: Implement actual validation logic
	// - Check config file exists and is valid YAML/JSON
	// - Validate project code format (3 chars, alphanumeric, uppercase)
	// - Validate email format
	// - Validate OU ID format
	// - Check AWS credentials
	// - Check GitHub token

	if !jsonOutput {
		fmt.Println("✅ Configuration validation coming soon!")
	} else {
		fmt.Println(`{
  "status": "success",
  "message": "Validation placeholder - implementation coming"
}`)
	}

	return nil
}
