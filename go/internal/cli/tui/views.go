package tui

import (
	"fmt"
	"strings"

	"github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/cli/tui/styles"
)

// viewProject renders the project configuration step
func (m WizardModel) viewProject() string {
	var sb strings.Builder

	// Step header
	sb.WriteString(styles.RenderStep(2, 6, "Project Configuration"))
	sb.WriteString("\n\n")

	// Project Code input
	sb.WriteString(styles.LabelStyle.Render("Project Code (3 letters):"))
	sb.WriteString("\n")
	sb.WriteString(m.projectCodeInput.View())
	sb.WriteString("\n")
	if err, ok := m.validationErrors["project_code"]; ok {
		sb.WriteString(styles.RenderError(err))
		sb.WriteString("\n")
	} else {
		sb.WriteString(styles.RenderHint("Must be 3 characters, alphanumeric (e.g., TPA)"))
		sb.WriteString("\n")
	}
	sb.WriteString("\n")

	// Email prefix input
	sb.WriteString(styles.LabelStyle.Render("Email Prefix:"))
	sb.WriteString("\n")
	sb.WriteString(m.emailInput.View())
	sb.WriteString("\n")
	if err, ok := m.validationErrors["email"]; ok {
		sb.WriteString(styles.RenderError(err))
		sb.WriteString("\n")
	} else {
		// Show preview of generated emails
		if m.emailInput.Value() != "" && m.projectCodeInput.Value() != "" {
			projectCode := strings.ToLower(m.projectCodeInput.Value())
			// Extract prefix if full email was entered
			email := strings.Split(m.emailInput.Value(), "@")[0]
			sb.WriteString(styles.RenderHint(fmt.Sprintf("Will create: %s+%s-dev@gmail.com", email, projectCode)))
			sb.WriteString("\n")
			sb.WriteString(styles.RenderHint(fmt.Sprintf("             %s+%s-staging@gmail.com", email, projectCode)))
			sb.WriteString("\n")
			sb.WriteString(styles.RenderHint(fmt.Sprintf("             %s+%s-prod@gmail.com", email, projectCode)))
			sb.WriteString("\n")
		} else {
			sb.WriteString(styles.RenderHint("Enter email prefix or full email (e.g., myemail or user@gmail.com)"))
			sb.WriteString("\n")
		}
	}
	sb.WriteString("\n")

	// OU ID input
	sb.WriteString(styles.LabelStyle.Render("AWS Organization Unit ID:"))
	sb.WriteString("\n")
	sb.WriteString(m.ouIDInput.View())
	sb.WriteString("\n")
	if err, ok := m.validationErrors["ou_id"]; ok {
		sb.WriteString(styles.RenderError(err))
		sb.WriteString("\n")
	} else {
		sb.WriteString(styles.RenderHint("Format: ou-xxxx-xxxxxxxx"))
		sb.WriteString("\n")
	}

	// Navigation help
	sb.WriteString("\n")
	sb.WriteString(styles.RenderNavHelp("[Tab/↓] Next field  [Shift+Tab/↑] Previous  [Enter] Continue  [Esc] Back  [Ctrl+C] Quit"))

	return sb.String()
}

// viewGitHub renders the GitHub configuration step
func (m WizardModel) viewGitHub() string {
	var sb strings.Builder

	// Step header
	sb.WriteString(styles.RenderStep(3, 6, "GitHub Configuration"))
	sb.WriteString("\n\n")

	// GitHub org input
	sb.WriteString(styles.LabelStyle.Render("GitHub Organization:"))
	sb.WriteString("\n")
	sb.WriteString(m.githubOrgInput.View())
	sb.WriteString("\n")
	if err, ok := m.validationErrors["github_org"]; ok {
		sb.WriteString(styles.RenderError(err))
		sb.WriteString("\n")
	} else {
		sb.WriteString(styles.RenderHint("Your GitHub organization or username"))
		sb.WriteString("\n")
	}
	sb.WriteString("\n")

	// GitHub repo input
	sb.WriteString(styles.LabelStyle.Render("Repository Name:"))
	sb.WriteString("\n")
	sb.WriteString(m.githubRepoInput.View())
	sb.WriteString("\n")
	if err, ok := m.validationErrors["github_repo"]; ok {
		sb.WriteString(styles.RenderError(err))
		sb.WriteString("\n")
	} else {
		if m.githubOrgInput.Value() != "" && m.githubRepoInput.Value() != "" {
			sb.WriteString(styles.RenderHint(fmt.Sprintf("Repository URL: https://github.com/%s/%s", m.githubOrgInput.Value(), m.githubRepoInput.Value())))
			sb.WriteString("\n")
		} else {
			sb.WriteString(styles.RenderHint("Name of the repository to create"))
			sb.WriteString("\n")
		}
	}
	sb.WriteString("\n")

	// Info box
	sb.WriteString(styles.SuccessStyle.Render("✓ Repository will be created with:"))
	sb.WriteString("\n")
	sb.WriteString(styles.ListItemStyle.Render("• GitHub Actions workflows"))
	sb.WriteString("\n")
	sb.WriteString(styles.ListItemStyle.Render("• OIDC authentication (no stored credentials)"))
	sb.WriteString("\n")
	sb.WriteString(styles.ListItemStyle.Render("• Branch protection rules"))
	sb.WriteString("\n")
	sb.WriteString(styles.ListItemStyle.Render("• Environment secrets"))
	sb.WriteString("\n")

	// Navigation help
	sb.WriteString("\n")
	sb.WriteString(styles.RenderNavHelp("[Tab/↓] Next field  [Shift+Tab/↑] Previous  [Enter] Continue  [Esc] Back  [Ctrl+C] Quit"))

	return sb.String()
}

// viewCostEstimate renders the cost estimation step
func (m WizardModel) viewCostEstimate() string {
	var sb strings.Builder

	// Step header
	sb.WriteString(styles.RenderStep(4, 6, "Cost Estimation"))
	sb.WriteString("\n\n")

	sb.WriteString(styles.StatusStyle.Render("Estimating monthly costs..."))
	sb.WriteString("\n\n")

	// Cost table (simplified for now)
	sb.WriteString(styles.TableHeaderStyle.Render("┌─────────────┬──────────────────────────┬───────────┐"))
	sb.WriteString("\n")
	sb.WriteString(styles.TableHeaderStyle.Render("│ Environment │ Services                 │ Est. Cost │"))
	sb.WriteString("\n")
	sb.WriteString(styles.TableHeaderStyle.Render("├─────────────┼──────────────────────────┼───────────┤"))
	sb.WriteString("\n")
	sb.WriteString(styles.TableCellStyle.Render("│ Dev         │ S3, CloudWatch, SNS      │ $10-15    │"))
	sb.WriteString("\n")
	sb.WriteString(styles.TableCellStyle.Render("│ Staging     │ S3, CloudWatch, SNS      │ $10-15    │"))
	sb.WriteString("\n")
	sb.WriteString(styles.TableCellStyle.Render("│ Prod        │ S3, CloudWatch, SNS      │ $20-30    │"))
	sb.WriteString("\n")
	sb.WriteString(styles.TableHeaderStyle.Render("├─────────────┼──────────────────────────┼───────────┤"))
	sb.WriteString("\n")
	sb.WriteString(styles.SuccessStyle.Render("│ Total       │                          │ $40-60    │"))
	sb.WriteString("\n")
	sb.WriteString(styles.TableHeaderStyle.Render("└─────────────┴──────────────────────────┴───────────┘"))
	sb.WriteString("\n\n")

	sb.WriteString(styles.HintStyle.Render("Note: Does not include application costs (Lambda, ECS, etc.)"))
	sb.WriteString("\n")

	// Navigation help
	sb.WriteString("\n")
	sb.WriteString(styles.RenderNavHelp("[Enter] Continue  [Esc] Back  [Ctrl+C] Quit"))

	return sb.String()
}

// viewReview renders the review and confirmation step
func (m WizardModel) viewReview() string {
	var sb strings.Builder

	// Step header
	sb.WriteString(styles.RenderStep(5, 6, "Review Configuration"))
	sb.WriteString("\n\n")

	// Project section
	sb.WriteString(styles.LabelStyle.Render("Project:"))
	sb.WriteString("\n")
	sb.WriteString(fmt.Sprintf("  Code: %s\n", styles.SuccessStyle.Render(m.config.ProjectCode)))
	sb.WriteString("  Emails:\n")
	for _, email := range m.config.AccountEmails() {
		sb.WriteString(fmt.Sprintf("    • %s\n", email))
	}
	sb.WriteString("\n")

	// AWS section
	sb.WriteString(styles.LabelStyle.Render("AWS:"))
	sb.WriteString("\n")
	sb.WriteString(fmt.Sprintf("  Organization Unit: %s\n", m.config.OUID))
	sb.WriteString("  Accounts to create: 3 (Dev, Staging, Prod)\n")
	sb.WriteString("  Billing alerts: $15 (warning), $25 (budget)\n")
	sb.WriteString("\n")

	// GitHub section
	sb.WriteString(styles.LabelStyle.Render("GitHub:"))
	sb.WriteString("\n")
	sb.WriteString(fmt.Sprintf("  Organization: %s\n", m.config.GitHub.Org))
	sb.WriteString(fmt.Sprintf("  Repository: %s\n", m.config.GitHub.RepoName))
	sb.WriteString("  CI/CD: GitHub Actions with OIDC\n")
	sb.WriteString("\n")

	// Cost
	sb.WriteString(styles.LabelStyle.Render("Estimated cost:"))
	sb.WriteString(" $40-60/month\n")
	sb.WriteString("\n")

	// Warning box
	warningText := "⚠️  This will create real AWS resources and incur costs."
	sb.WriteString(styles.WarningBoxStyle.Render(warningText))
	sb.WriteString("\n\n")

	sb.WriteString(styles.LabelStyle.Render("Confirm and create? [y/N]:"))
	sb.WriteString("\n")

	// Navigation help
	sb.WriteString("\n")
	sb.WriteString(styles.RenderNavHelp("[Enter] Confirm  [Esc] Back  [Ctrl+C] Cancel"))

	return sb.String()
}

// viewExecute renders the execution progress step
func (m WizardModel) viewExecute() string {
	var sb strings.Builder

	// Step header
	sb.WriteString(styles.RenderStep(6, 6, "Creating Infrastructure"))
	sb.WriteString("\n\n")

	sb.WriteString(styles.SuccessStyle.Render("✓") + " Validated configuration\n")
	sb.WriteString(styles.SpinnerStyle.Render("⠋") + " Creating AWS accounts...\n")
	sb.WriteString("  " + styles.SuccessStyle.Render("✓") + " Dev account created (123456789012)\n")
	sb.WriteString("  " + styles.SuccessStyle.Render("✓") + " Staging account created (123456789013)\n")
	sb.WriteString("  " + styles.SpinnerStyle.Render("⠋") + " Prod account creating...\n")
	sb.WriteString("\n")
	sb.WriteString(styles.StatusStyle.Render("⠋ Setting up GitHub repository..."))
	sb.WriteString("\n\n")

	// Progress bar (simplified)
	progress := 40 // 40%
	total := 50
	filled := (progress * total) / 100
	empty := total - filled

	progressBar := styles.ProgressBarStyle.Render(strings.Repeat("█", filled)) +
		styles.ProgressEmptyStyle.Render(strings.Repeat("░", empty))

	sb.WriteString(fmt.Sprintf("[Progress: %s] %d%%\n", progressBar, progress))
	sb.WriteString("\n")
	sb.WriteString(styles.StatusStyle.Render("Estimated time remaining: 3 minutes"))
	sb.WriteString("\n\n")

	sb.WriteString(styles.RenderNavHelp("[Ctrl+C] will abort"))

	return sb.String()
}

// viewComplete renders the completion success screen
func (m WizardModel) viewComplete() string {
	var sb strings.Builder

	sb.WriteString(styles.SuccessBoxStyle.Render(styles.RenderTitle("Setup Complete! ✓")))
	sb.WriteString("\n\n")

	// AWS Accounts
	sb.WriteString(styles.LabelStyle.Render("AWS Accounts Created:"))
	sb.WriteString("\n")
	accounts := []struct {
		name string
		id   string
		email string
	}{
		{"Dev", "123456789012", m.config.AccountEmails()[0]},
		{"Staging", "123456789013", m.config.AccountEmails()[1]},
		{"Prod", "123456789014", m.config.AccountEmails()[2]},
	}

	for _, acc := range accounts {
		sb.WriteString(fmt.Sprintf("  • %s: %s (%s)\n", acc.name, acc.id, acc.email))
	}
	sb.WriteString("\n")

	// GitHub Repository
	sb.WriteString(styles.LabelStyle.Render("GitHub Repository:"))
	sb.WriteString("\n")
	repoURL := fmt.Sprintf("https://github.com/%s/%s", m.config.GitHub.Org, m.config.GitHub.RepoName)
	sb.WriteString(fmt.Sprintf("  • URL: %s\n", repoURL))
	sb.WriteString("  • CI/CD: Configured with OIDC\n")
	sb.WriteString("  • Workflows: Deployed\n")
	sb.WriteString("\n")

	// Next steps
	sb.WriteString(styles.LabelStyle.Render("Next Steps:"))
	sb.WriteString("\n")
	sb.WriteString("  1. Check your email for AWS account invitations\n")
	sb.WriteString(fmt.Sprintf("  2. Clone the repository: git clone %s\n", repoURL))
	sb.WriteString("  3. Push your CDK code to trigger deployments\n")
	sb.WriteString("  4. Monitor costs in AWS Billing Console\n")
	sb.WriteString("\n")

	sb.WriteString(styles.HintStyle.Render("Press any key to exit."))

	return sb.String()
}