package tui

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/lipgloss"
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

	if m.estimatingCost || m.costAnalysis == nil {
		sb.WriteString(styles.StatusStyle.Render("⠋ Estimating monthly costs..."))
		sb.WriteString("\n\n")
		return sb.String()
	}

	if m.err != nil {
		sb.WriteString(styles.RenderError(fmt.Sprintf("Error estimating costs: %v", m.err)))
		sb.WriteString("\n")
		sb.WriteString(styles.HintStyle.Render("Using default estimates"))
		sb.WriteString("\n\n")
	}

	// Display usage profile
	sb.WriteString(styles.LabelStyle.Render("Usage Profile: "))
	profileName := map[string]string{
		"minimal":  "Minimal (POC/Testing - 10% utilization)",
		"light":    "Light (Small team - 30% utilization)",
		"moderate": "Moderate (Startup - 60% utilization)",
		"heavy":    "Heavy (Enterprise - 100% utilization)",
	}
	sb.WriteString(styles.SuccessStyle.Render(profileName[string(m.usageProfile)]))
	sb.WriteString("\n\n")

	// Bootstrap Infrastructure Costs
	sb.WriteString(styles.LabelStyle.Render("Bootstrap Infrastructure (3 Accounts):"))
	sb.WriteString("\n\n")

	// Service breakdown
	sb.WriteString(styles.TableHeaderStyle.Render("┌─────────────────────────┬────────────┬───────────┐"))
	sb.WriteString("\n")
	sb.WriteString(styles.TableHeaderStyle.Render("│ Service                 │ Resources  │ Est. Cost │"))
	sb.WriteString("\n")
	sb.WriteString(styles.TableHeaderStyle.Render("├─────────────────────────┼────────────┼───────────┤"))
	sb.WriteString("\n")

	// Show each service
	for svcName, cost := range m.costAnalysis.ByService {
		resourceCount := 0
		for _, usage := range m.costAnalysis.UsageEstimates {
			if usage.ServiceName == svcName {
				if usage.Quantity > 1 {
					resourceCount += int(usage.Quantity)
				} else {
					resourceCount++
				}
			}
		}

		line := fmt.Sprintf("│ %-23s │ %-10d │ $%-8.2f │",
			strings.ToUpper(svcName),
			resourceCount,
			cost)
		sb.WriteString(styles.TableCellStyle.Render(line))
		sb.WriteString("\n")
	}

	sb.WriteString(styles.TableHeaderStyle.Render("├─────────────────────────┼────────────┼───────────┤"))
	sb.WriteString("\n")

	totalLine := fmt.Sprintf("│ %-23s │ %-10s │ $%-8.2f │",
		"TOTAL (per month)",
		"",
		m.costAnalysis.EstimatedCost)
	sb.WriteString(styles.SuccessStyle.Render(totalLine))
	sb.WriteString("\n")
	sb.WriteString(styles.TableHeaderStyle.Render("└─────────────────────────┴────────────┴───────────┘"))
	sb.WriteString("\n\n")

	// Resource details
	sb.WriteString(styles.HintStyle.Render("Included resources:"))
	sb.WriteString("\n")
	for _, usage := range m.costAnalysis.UsageEstimates {
		detail := ""
		switch usage.ResourceType {
		case "AWS::CloudWatch::Alarm":
			detail = fmt.Sprintf("  • %.0f CloudWatch alarms (billing + anomaly detection)", usage.Quantity)
		case "AWS::SNS::Topic":
			detail = fmt.Sprintf("  • SNS notifications (~%.0f/month)", usage.RequestsPerMonth)
		}
		if detail != "" {
			sb.WriteString(styles.HintStyle.Render(detail))
			sb.WriteString("\n")
		}
	}
	sb.WriteString("\n")

	sb.WriteString(styles.HintStyle.Render("Note: Does not include application costs (Lambda, ECS, etc.)"))
	sb.WriteString("\n")

	if len(m.costAnalysis.Errors) > 0 {
		sb.WriteString("\n")
		sb.WriteString(styles.RenderError("Warnings:"))
		sb.WriteString("\n")
		for _, err := range m.costAnalysis.Errors {
			sb.WriteString(styles.HintStyle.Render(fmt.Sprintf("  • %s", err)))
			sb.WriteString("\n")
		}
	}

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
	if m.costAnalysis != nil {
		sb.WriteString(fmt.Sprintf(" $%.2f/month\n", m.costAnalysis.EstimatedCost))
	} else {
		sb.WriteString(" $0.60-1.50/month\n") // Fallback estimate
	}
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

// viewCategorySelection renders the category selection step
func (m WizardModel) viewCategorySelection() string {
	var sb strings.Builder

	// Step header
	sb.WriteString(styles.RenderStep(1, 7, "Select Category"))
	sb.WriteString("\n\n")

	// Show loading spinner if templates are being loaded
	if m.loadingTemplates {
		sb.WriteString(styles.LabelStyle.Render("Loading templates from cloudonaut/widdix..."))
		sb.WriteString("\n\n")
		sb.WriteString("⠋ Fetching production-ready templates from GitHub...\n")
		return sb.String()
	}

	sb.WriteString(styles.LabelStyle.Render("Choose a template category:"))
	sb.WriteString("\n\n")

	// List category options
	for i, category := range m.categoryOptions {
		cursor := "  "
		if i == m.categoryCursor {
			cursor = styles.SuccessStyle.Render("→ ")
		}
		sb.WriteString(cursor)

		// Capitalize category name
		displayName := strings.Title(category)
		sb.WriteString(displayName)

		// Show template count for this category
		count := 0
		for _, t := range m.allTemplates {
			if t.Category == category {
				count++
			}
		}
		if count > 0 {
			sb.WriteString(styles.HintStyle.Render(fmt.Sprintf(" (%d templates)", count)))
		}

		sb.WriteString("\n\n")
	}

	// Show error if template loading failed
	if m.templateLoadError != nil {
		sb.WriteString(lipgloss.NewStyle().Foreground(lipgloss.Color("3")).Render("⚠ Failed to load remote templates: " + m.templateLoadError.Error()))
		sb.WriteString("\n")
		sb.WriteString(styles.HintStyle.Render("Showing built-in categories only. Check network connection or GitHub API rate limits."))
		sb.WriteString("\n\n")
	}

	// Navigation help
	sb.WriteString(styles.RenderNavHelp("[↑↓/jk] Navigate  [Enter] Select  [Esc] Back  [Ctrl+C] Quit"))

	return sb.String()
}

// viewTemplateSelection renders the template selection step
func (m WizardModel) viewTemplateSelection() string {
	var sb strings.Builder

	// Step header
	sb.WriteString(styles.RenderStep(2, 7, "Select Template"))
	sb.WriteString("\n\n")

	// Show loading spinner if templates are being loaded
	if m.loadingTemplates {
		sb.WriteString(styles.LabelStyle.Render("Loading templates from cloudonaut/widdix..."))
		sb.WriteString("\n\n")
		sb.WriteString("⠋ Fetching production-ready templates from GitHub...\n")
		return sb.String()
	}

	sb.WriteString(styles.LabelStyle.Render("Choose an infrastructure template:"))
	sb.WriteString("\n\n")

	// List template options with category and source
	for i, template := range m.templateOptions {
		cursor := "  "
		if i == m.templateCursor {
			cursor = styles.SuccessStyle.Render("→ ")
		}
		sb.WriteString(cursor)

		// Show template name
		templateName := template.Name
		if len(templateName) > 50 {
			templateName = templateName[:47] + "..."
		}
		sb.WriteString(templateName)

		// Show category and source if available
		if template.Category != "" || template.Source != "" {
			sb.WriteString(" ")
			sb.WriteString(styles.HintStyle.Render("["))
			if template.Category != "" {
				sb.WriteString(styles.HintStyle.Render(template.Category))
			}
			if template.Source != "" {
				if template.Category != "" {
					sb.WriteString(styles.HintStyle.Render(" • "))
				}
				sb.WriteString(styles.HintStyle.Render(template.Source))
			}
			sb.WriteString(styles.HintStyle.Render("]"))
		}

		sb.WriteString("\n")

		// Show description
		if template.Description != "" {
			sb.WriteString("  ")
			sb.WriteString(styles.HintStyle.Render(template.Description))
			sb.WriteString("\n")
		}

		sb.WriteString("\n")
	}

	// Show count
	sb.WriteString(styles.HintStyle.Render(fmt.Sprintf("Showing %d templates\n", len(m.templateOptions))))
	sb.WriteString("\n")

	// Show error if template loading failed
	if m.templateLoadError != nil {
		sb.WriteString(lipgloss.NewStyle().Foreground(lipgloss.Color("3")).Render("⚠ Failed to load remote templates: " + m.templateLoadError.Error()))
		sb.WriteString("\n")
		sb.WriteString(styles.HintStyle.Render("Showing built-in templates only. Check network connection or GitHub API rate limits."))
		sb.WriteString("\n\n")
	}

	// Navigation help
	sb.WriteString(styles.RenderNavHelp("[↑↓/jk] Navigate  [Enter] Select  [Esc] Back  [Ctrl+C] Quit"))

	return sb.String()
}

// viewUsageProfile renders the usage profile selection step
func (m WizardModel) viewUsageProfile() string {
	var sb strings.Builder

	// Step header
	sb.WriteString(styles.RenderStep(2, 6, "Select Usage Profile"))
	sb.WriteString("\n\n")

	sb.WriteString(styles.LabelStyle.Render("Expected usage level:"))
	sb.WriteString("\n\n")

	// Profile descriptions
	profileDesc := map[string]string{
		"minimal":  "POC/Testing (10% utilization)",
		"light":    "Small team (30% utilization)",
		"moderate": "Startup (60% utilization)",
		"heavy":    "Enterprise (100% utilization)",
	}

	// List profile options
	for i, profile := range m.profileOptions {
		cursor := "  "
		if i == m.profileCursor {
			cursor = styles.SuccessStyle.Render("→ ")
		}
		sb.WriteString(cursor)
		sb.WriteString(strings.Title(string(profile)))
		sb.WriteString(" - ")
		sb.WriteString(profileDesc[string(profile)])
		sb.WriteString("\n")
	}

	sb.WriteString("\n")
	sb.WriteString(styles.RenderHint("This affects cost estimation and resource sizing"))
	sb.WriteString("\n\n")

	// Navigation help
	sb.WriteString(styles.RenderNavHelp("[↑↓/jk] Navigate  [Enter] Select  [Esc] Back  [Ctrl+C] Quit"))

	return sb.String()
}

// viewBootstrapDecision renders the bootstrap decision step
func (m WizardModel) viewBootstrapDecision() string {
	var sb strings.Builder

	// Step header
	sb.WriteString(styles.RenderStep(4, 6, "Bootstrap Decision"))
	sb.WriteString("\n\n")

	// Show selected template and cost
	sb.WriteString(styles.LabelStyle.Render("Template: "))
	sb.WriteString(m.selectedTemplate.Name)
	sb.WriteString("\n")

	sb.WriteString(styles.LabelStyle.Render("Usage Profile: "))
	sb.WriteString(strings.Title(string(m.usageProfile)))
	sb.WriteString("\n")

	if m.costAnalysis != nil {
		sb.WriteString(styles.LabelStyle.Render("Estimated Cost: "))
		sb.WriteString(styles.SuccessStyle.Render(fmt.Sprintf("$%.2f/month", m.costAnalysis.EstimatedCost)))
		sb.WriteString("\n")
	} else if m.err != nil {
		// Show error if cost estimation failed
		sb.WriteString(lipgloss.NewStyle().Foreground(lipgloss.Color("1")).Render("✗ Cost estimation failed: " + m.err.Error()))
		sb.WriteString("\n")
		sb.WriteString(styles.HintStyle.Render("You can still proceed with bootstrap, but cost estimate is unavailable."))
		sb.WriteString("\n")
	} else {
		// No analysis and no error means still processing (shouldn't happen)
		sb.WriteString(styles.HintStyle.Render("Cost estimation pending..."))
		sb.WriteString("\n")
	}

	sb.WriteString("\n")
	sb.WriteString(styles.RenderHint("You can explore cost estimates without AWS/GitHub credentials."))
	sb.WriteString("\n")
	sb.WriteString(styles.RenderHint("Bootstrapping will create real infrastructure and requires credentials."))
	sb.WriteString("\n\n")

	sb.WriteString(styles.LabelStyle.Render("Would you like to bootstrap this setup now?"))
	sb.WriteString("\n\n")

	sb.WriteString(styles.RenderNavHelp("[Enter] Yes, bootstrap  [Esc] No, go back  [Ctrl+C] Quit"))

	return sb.String()
}

// viewPrerequisitesCheck renders the prerequisites check step
func (m WizardModel) viewPrerequisitesCheck() string {
	var sb strings.Builder

	// Step header
	sb.WriteString(styles.RenderStep(5, 6, "Prerequisites Check"))
	sb.WriteString("\n\n")

	if m.checkingPrereqs {
		sb.WriteString(styles.StatusStyle.Render("⠋ Checking system prerequisites..."))
		sb.WriteString("\n\n")
		return sb.String()
	}

	// Show results
	sb.WriteString(styles.LabelStyle.Render("System Prerequisites:"))
	sb.WriteString("\n\n")

	allPassed := true
	for _, result := range m.prerequisiteResults {
		var status string
		switch result.Status {
		case "pass":
			status = styles.SuccessStyle.Render("✓")
		case "fail":
			status = styles.ErrorStyle.Render("✗")
			allPassed = false
		case "warning":
			status = lipgloss.NewStyle().Foreground(lipgloss.Color("3")).Render("⚠")
		}

		sb.WriteString(status)
		sb.WriteString(" ")
		sb.WriteString(result.Name)
		sb.WriteString("\n")

		if result.Error != nil {
			sb.WriteString("  ")
			sb.WriteString(styles.HintStyle.Render(result.Error.Error()))
			sb.WriteString("\n")
		}

		if result.FixCommand != "" && result.IsFail() {
			sb.WriteString("  ")
			sb.WriteString(styles.HintStyle.Render("Fix: "+result.FixCommand))
			sb.WriteString("\n")
		}

		sb.WriteString("\n")
	}

	if allPassed {
		sb.WriteString(styles.SuccessStyle.Render("✓ All prerequisites passed!"))
		sb.WriteString("\n\n")
		sb.WriteString(styles.RenderNavHelp("[Enter] Continue  [Esc] Back  [Ctrl+C] Quit"))
	} else {
		sb.WriteString(styles.ErrorStyle.Render("✗ Some prerequisites failed"))
		sb.WriteString("\n")
		sb.WriteString(styles.HintStyle.Render("Please fix the issues above and press Enter to retry"))
		sb.WriteString("\n\n")
		sb.WriteString(styles.RenderNavHelp("[Enter] Retry  [Esc] Back  [Ctrl+C] Quit"))
	}

	return sb.String()
}
