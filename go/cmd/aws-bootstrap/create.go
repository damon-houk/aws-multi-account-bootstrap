package main

import (
	"fmt"

	"github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/cli/config"
	"github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/cli/tui"
	"github.com/spf13/cobra"
	"github.com/spf13/viper"
)

// createCmd represents the create command
var createCmd = &cobra.Command{
	Use:   "create",
	Short: "Create multi-account AWS infrastructure",
	Long: `Create a complete multi-account AWS setup with GitHub CI/CD.

This command will:
  • Create 3 AWS accounts (Dev, Staging, Prod)
  • Set up GitHub Actions with OIDC authentication
  • Configure billing alerts and budgets
  • Bootstrap AWS CDK in all accounts
  • Create GitHub workflows for CI/CD

By default, runs in interactive mode with a step-by-step wizard.
Use --non-interactive for CI/CD automation.`,
	Example: `  # Interactive mode (default)
  aws-bootstrap create

  # With config file
  aws-bootstrap create --config ./my-config.yaml

  # Dry run to preview
  aws-bootstrap create --dry-run

  # Non-interactive for CI/CD
  aws-bootstrap create \
    --non-interactive \
    --project-code TPA \
    --email myemail \
    --ou-id ou-xxxx \
    --github-org myorg \
    --repo-name myrepo \
    --json`,
	RunE: runCreate,
}

func init() {
	rootCmd.AddCommand(createCmd)

	// Configuration flags
	createCmd.Flags().String("project-code", "", "3-letter project code (e.g., TPA)")
	createCmd.Flags().String("email", "", "email prefix for account emails")
	createCmd.Flags().String("ou-id", "", "AWS Organization Unit ID")
	createCmd.Flags().String("github-org", "", "GitHub organization")
	createCmd.Flags().String("repo-name", "", "GitHub repository name")

	// Behavior flags
	createCmd.Flags().Bool("dry-run", false, "preview without creating resources")
	createCmd.Flags().Bool("interactive", true, "interactive mode with TUI wizard")
	createCmd.Flags().Bool("non-interactive", false, "non-interactive mode for CI/CD")

	// AWS options
	createCmd.Flags().String("aws-profile", "", "AWS profile to use")
	createCmd.Flags().String("aws-region", "us-east-1", "AWS region")

	// GitHub options
	createCmd.Flags().String("github-token", "", "GitHub token (or use GITHUB_TOKEN env var)")

	// Bind flags to viper
	viper.BindPFlag("project_code", createCmd.Flags().Lookup("project-code"))
	viper.BindPFlag("email", createCmd.Flags().Lookup("email"))
	viper.BindPFlag("ou_id", createCmd.Flags().Lookup("ou-id"))
	viper.BindPFlag("github.org", createCmd.Flags().Lookup("github-org"))
	viper.BindPFlag("github.repo_name", createCmd.Flags().Lookup("repo-name"))
	viper.BindPFlag("dry_run", createCmd.Flags().Lookup("dry-run"))
	viper.BindPFlag("interactive", createCmd.Flags().Lookup("interactive"))
	viper.BindPFlag("non_interactive", createCmd.Flags().Lookup("non-interactive"))
	viper.BindPFlag("aws.profile", createCmd.Flags().Lookup("aws-profile"))
	viper.BindPFlag("aws.region", createCmd.Flags().Lookup("aws-region"))
	viper.BindPFlag("github.token", createCmd.Flags().Lookup("github-token"))
}

func runCreate(cmd *cobra.Command, args []string) error {
	// Build initial configuration from viper
	cfg := &config.Config{
		ProjectCode: viper.GetString("project_code"),
		EmailPrefix: viper.GetString("email"),
		OUID:        viper.GetString("ou_id"),
		GitHub: config.GitHubConfig{
			Org:      viper.GetString("github.org"),
			RepoName: viper.GetString("github.repo_name"),
			Token:    viper.GetString("github.token"),
		},
		AWS: config.AWSConfig{
			Profile: viper.GetString("aws.profile"),
			Region:  viper.GetString("aws.region"),
		},
		DryRun:         viper.GetBool("dry_run"),
		Interactive:    viper.GetBool("interactive") && !viper.GetBool("non_interactive"),
		NonInteractive: viper.GetBool("non_interactive"),
		JSONOutput:     viper.GetBool("json"),
	}

	if cfg.DryRun {
		fmt.Println("🔍 DRY RUN MODE - No resources will be created")
		fmt.Println()
	}

	// Interactive mode - launch TUI wizard
	if cfg.Interactive {
		finalCfg, err := tui.Run(cfg)
		if err != nil {
			return fmt.Errorf("TUI wizard failed: %w", err)
		}
		cfg = finalCfg
	} else {
		// Non-interactive mode
		if !cfg.JSONOutput {
			fmt.Println("╔═══════════════════════════════════════════════════════════╗")
			fmt.Println("║                                                           ║")
			fmt.Println("║   AWS Multi-Account Bootstrap with GitHub CI/CD          ║")
			fmt.Println("║                                                           ║")
			fmt.Println("╚═══════════════════════════════════════════════════════════╝")
			fmt.Println()
		}

		// Validate required configuration
		if err := cfg.Validate(); err != nil {
			return fmt.Errorf("configuration validation failed: %w", err)
		}

		if !cfg.JSONOutput {
			fmt.Printf("Project Code: %s\n", cfg.ProjectCode)
			fmt.Printf("Email: %s\n", cfg.EmailPrefix)
			fmt.Printf("OU ID: %s\n", cfg.OUID)
			fmt.Printf("GitHub Org: %s\n", cfg.GitHub.Org)
			fmt.Printf("Repo Name: %s\n", cfg.GitHub.RepoName)
			fmt.Println()
		}
	}

	// TODO: Wire up domain logic and adapters
	// TODO: Call account creation, GitHub setup, etc.

	if cfg.JSONOutput {
		fmt.Println(`{
  "status": "success",
  "message": "Setup complete (TUI wizard working, execution coming soon)"
}`)
	} else {
		fmt.Println("✨ Setup complete! (TUI wizard working, execution coming soon)")
	}

	return nil
}
