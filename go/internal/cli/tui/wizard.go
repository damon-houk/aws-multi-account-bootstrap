package tui

import (
	"fmt"
	"log"
	"os"

	"github.com/charmbracelet/bubbles/textinput"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/adapters/pricing"
	"github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/adapters/system"
	templatesadapter "github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/adapters/templates"
	"github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/adapters/usage"
	"github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/cli/config"
	"github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/cli/tui/styles"
	"github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/cost"
	"github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/domain/templates"
	"github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/model"
	"github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/ports"
)

// WizardStep represents the current step in the wizard
type WizardStep int

const (
	StepWelcome WizardStep = iota
	StepCategorySelection    // Select template category
	StepTemplateSelection    // Select template from category
	StepUsageProfile         // Select usage profile
	StepCostEstimate         // Show cost estimate (no credentials needed up to here)
	StepBootstrapDecision    // Ask if user wants to bootstrap
	StepPrerequisitesCheck   // Check AWS/GitHub access (only if bootstrapping)
	StepProject              // Project configuration
	StepGitHub               // GitHub configuration
	StepReview               // Review everything
	StepExecute              // Execute bootstrap
	StepComplete             // Show success
)

// WizardModel is the main Bubbletea model for the TUI wizard
type WizardModel struct {
	currentStep WizardStep
	config      *config.Config
	width       int
	height      int
	err         error
	quitting    bool

	// Ports (dependency injection - hexagonal architecture)
	templateLoader      ports.TemplateLoader
	prerequisiteChecker ports.PrerequisiteChecker
	analyzer            *templates.Analyzer

	// Category selection state
	categoryCursor     int
	categoryOptions    []string

	// Template selection state
	selectedTemplate   ports.TemplateInfo
	selectedTemplateContent string // Downloaded template content
	templateOptions    []ports.TemplateInfo
	allTemplates       []ports.TemplateInfo // Store all loaded templates
	templateCursor     int
	loadingTemplates   bool
	templateLoadError  error
	selectedCategory   string

	// Usage profile selection state
	usageProfile   model.UsageProfile
	profileCursor  int
	profileOptions []model.UsageProfile

	// Cost estimation state
	costAnalysis   *model.TemplateAnalysis
	estimatingCost bool

	// Prerequisites check state
	prerequisiteResults []ports.PrerequisiteResult
	checkingPrereqs     bool

	// Input fields for project step
	projectCodeInput textinput.Model
	emailInput       textinput.Model
	ouIDInput        textinput.Model

	// Input fields for GitHub step
	githubOrgInput  textinput.Model
	githubRepoInput textinput.Model

	// Current focused input
	focusedInput int

	// Validation errors
	validationErrors map[string]string

	// Execution state
	executing     bool
	executionStep string
	progress      float64
}

// NewWizard creates a new wizard model
func NewWizard(cfg *config.Config) WizardModel {
	// Initialize text inputs for project step
	projectCodeInput := textinput.New()
	projectCodeInput.Placeholder = "e.g., TPA"
	projectCodeInput.CharLimit = 3
	projectCodeInput.Width = 30
	if cfg.ProjectCode != "" {
		projectCodeInput.SetValue(cfg.ProjectCode)
	}

	emailInput := textinput.New()
	emailInput.Placeholder = "e.g., myemail"
	emailInput.CharLimit = 50
	emailInput.Width = 30
	if cfg.EmailPrefix != "" {
		emailInput.SetValue(cfg.EmailPrefix)
	}

	ouIDInput := textinput.New()
	ouIDInput.Placeholder = "ou-xxxx-xxxxxxxx"
	ouIDInput.CharLimit = 20
	ouIDInput.Width = 30
	if cfg.OUID != "" {
		ouIDInput.SetValue(cfg.OUID)
	}

	// Initialize text inputs for GitHub step
	githubOrgInput := textinput.New()
	githubOrgInput.Placeholder = "e.g., myorg"
	githubOrgInput.CharLimit = 50
	githubOrgInput.Width = 30
	if cfg.GitHub.Org != "" {
		githubOrgInput.SetValue(cfg.GitHub.Org)
	}

	githubRepoInput := textinput.New()
	githubRepoInput.Placeholder = "e.g., myrepo"
	githubRepoInput.CharLimit = 50
	githubRepoInput.Width = 30
	if cfg.GitHub.RepoName != "" {
		githubRepoInput.SetValue(cfg.GitHub.RepoName)
	}

	// Focus the first input
	projectCodeInput.Focus()

	// Initialize adapters (hexagonal architecture - dependency injection)

	// Template loader adapter - use GitHub loader for remote templates
	var templateLoader ports.TemplateLoader
	ghLoader, err := templatesadapter.NewGitHubTemplateLoader()
	if err != nil {
		fmt.Fprintf(os.Stderr, "WARNING: Failed to create GitHub template loader: %v\n", err)
		fmt.Fprintf(os.Stderr, "         Falling back to filesystem loader (built-in templates only)\n")
		templateLoader = templatesadapter.NewFilesystemTemplateLoader()
	} else {
		fmt.Fprintf(os.Stderr, "INFO: GitHub template loader initialized successfully\n")
		templateLoader = ghLoader
	}

	// Prerequisite checker adapter
	prerequisiteChecker := system.NewSystemPrerequisiteChecker()

	// Initialize cost analyzer with REAL AWS Pricing API
	// Create file-based cache for pricing data (7-day TTL)
	priceCache, err := cost.NewFilePriceCache()
	if err != nil {
		log.Printf("Warning: Failed to create price cache: %v (using without cache)", err)
		priceCache = nil // Continue without cache
	}

	// Create HTTP client for AWS Pricing API
	httpClient := cost.NewHTTPPricingClient(priceCache)

	// Create AWS pricing adapter with real pricing client
	realPricer := pricing.NewAWSPricingAdapter(httpClient)
	estimator := usage.NewProfileMapper()
	analyzer := templates.NewAnalyzer(nil, realPricer, estimator)

	// Initialize template options
	templateOptions := templateLoader.ListBuiltInTemplates()

	// Initialize usage profile options
	profileOptions := []model.UsageProfile{
		model.ProfileMinimal,
		model.ProfileLight,
		model.ProfileModerate,
		model.ProfileHeavy,
	}

	return WizardModel{
		currentStep:         StepWelcome,
		config:              cfg,
		templateLoader:      templateLoader,
		prerequisiteChecker: prerequisiteChecker,
		analyzer:            analyzer,
		projectCodeInput:    projectCodeInput,
		emailInput:          emailInput,
		ouIDInput:           ouIDInput,
		githubOrgInput:      githubOrgInput,
		githubRepoInput:     githubRepoInput,
		focusedInput:        0,
		validationErrors:    make(map[string]string),
		templateOptions:     templateOptions,
		templateCursor:      0,
		profileOptions:      profileOptions,
		profileCursor:       1, // Default to Light
		usageProfile:        model.ProfileLight,
	}
}

// costEstimateMsg contains the result of cost estimation
type costEstimateMsg struct {
	analysis *model.TemplateAnalysis
	err      error
}

// prerequisitesCheckMsg contains the result of prerequisites check
type prerequisitesCheckMsg struct {
	results []ports.PrerequisiteResult
}

// templatesLoadedMsg contains the result of loading remote templates
type templatesLoadedMsg struct {
	templates []ports.TemplateInfo
	err       error
}

// templateDownloadedMsg contains the result of downloading a template
type templateDownloadedMsg struct {
	content string
	err     error
}

// loadRemoteTemplates triggers loading templates from GitHub
func (m WizardModel) loadRemoteTemplates() tea.Cmd {
	return func() tea.Msg {
		templates, err := m.templateLoader.ListRemoteTemplates("all")
		if err != nil {
			// If remote loading fails, return built-in templates only
			return templatesLoadedMsg{
				templates: m.templateLoader.ListBuiltInTemplates(),
				err:       err,
			}
		}
		// Prepend built-in templates
		allTemplates := append(m.templateLoader.ListBuiltInTemplates(), templates...)
		return templatesLoadedMsg{templates: allTemplates, err: nil}
	}
}

// estimateCosts triggers cost estimation for the selected template
func (m WizardModel) estimateCosts() tea.Cmd {
	return func() (msg tea.Msg) {
		// Recover from panics to prevent crashes
		defer func() {
			if r := recover(); r != nil {
				panicErr := fmt.Errorf("panic during cost estimation: %v", r)
				log.Printf("PANIC: %v", r)
				fmt.Fprintf(os.Stderr, "PANIC in cost estimation: %v\n", r)
				// Return panic as error message
				msg = costEstimateMsg{analysis: nil, err: panicErr}
			}
		}()

		var analysis *model.TemplateAnalysis
		var err error

		log.Printf("INFO: Starting cost estimation, has template content: %v", m.selectedTemplateContent != "")
		fmt.Fprintf(os.Stderr, "DEBUG: Starting cost estimation...\n")

		// Check if we have template content (remote template)
		if m.selectedTemplateContent != "" {
			log.Printf("INFO: Analyzing remote template, content length: %d bytes", len(m.selectedTemplateContent))
			fmt.Fprintf(os.Stderr, "DEBUG: Analyzing remote template (%d bytes)...\n", len(m.selectedTemplateContent))

			// For now, skip remote template analysis - it's causing hangs
			// TODO: Fix template parser
			err = fmt.Errorf("remote template analysis not yet supported - using bootstrap estimate")

			// Fallback to bootstrap
			analysis, err = m.analyzer.AnalyzeBootstrapOnly(
				m.usageProfile,
				"us-east-1", // Default region
				3,           // 3 accounts
			)
		} else {
			log.Printf("INFO: Analyzing built-in bootstrap template")
			fmt.Fprintf(os.Stderr, "DEBUG: Analyzing built-in bootstrap template...\n")
			// Built-in bootstrap template
			analysis, err = m.analyzer.AnalyzeBootstrapOnly(
				m.usageProfile,
				"us-east-1", // Default region
				3,           // 3 accounts
			)
		}

		if err != nil {
			log.Printf("ERROR: Cost estimation error: %v", err)
			fmt.Fprintf(os.Stderr, "ERROR: Cost estimation failed: %v\n", err)
		} else {
			log.Printf("INFO: Cost estimation completed successfully")
			fmt.Fprintf(os.Stderr, "DEBUG: Cost estimation completed: $%.2f/month\n", analysis.EstimatedCost)
		}

		return costEstimateMsg{analysis: analysis, err: err}
	}
}

// checkPrerequisites triggers prerequisite checks
func (m WizardModel) checkPrerequisites() tea.Cmd {
	return func() tea.Msg {
		results := m.prerequisiteChecker.CheckAll()
		return prerequisitesCheckMsg{results: results}
	}
}

// Init initializes the wizard
func (m WizardModel) Init() tea.Cmd {
	return textinput.Blink
}

// Update handles messages and updates the model
func (m WizardModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmd tea.Cmd

	switch msg := msg.(type) {
	case costEstimateMsg:
		// Cost estimation completed
		m.estimatingCost = false
		if msg.err != nil {
			m.err = msg.err
			log.Printf("ERROR: Cost estimation failed: %v", msg.err)
			fmt.Fprintf(os.Stderr, "ERROR: Cost estimation failed: %v\n", msg.err)
		} else {
			m.costAnalysis = msg.analysis
			log.Printf("INFO: Cost estimation succeeded, estimated cost: $%.2f", msg.analysis.EstimatedCost)
		}
		return m, nil

	case prerequisitesCheckMsg:
		// Prerequisites check completed
		m.checkingPrereqs = false
		m.prerequisiteResults = msg.results
		return m, nil

	case templatesLoadedMsg:
		// Templates loading completed
		m.loadingTemplates = false
		m.templateLoadError = msg.err
		if msg.err != nil {
			// Log error but continue with what we have
			log.Printf("Warning: Failed to load remote templates: %v", msg.err)
		}
		m.allTemplates = msg.templates

		// Extract unique categories
		categoryMap := make(map[string]bool)
		for _, t := range msg.templates {
			if t.Category != "" {
				categoryMap[t.Category] = true
			}
		}

		// Build category list with Bootstrap first
		m.categoryOptions = []string{"bootstrap"}
		for cat := range categoryMap {
			if cat != "bootstrap" {
				m.categoryOptions = append(m.categoryOptions, cat)
			}
		}

		return m, nil

	case tea.KeyMsg:
		// Handle navigation keys BEFORE they reach the inputs
		switch msg.String() {
		case "ctrl+c", "q":
			if m.currentStep == StepWelcome || m.currentStep == StepComplete {
				m.quitting = true
				return m, tea.Quit
			}
			// In other steps, require explicit confirmation
			// For now, just quit
			m.quitting = true
			return m, tea.Quit

		case "enter":
			return m.handleEnter()

		case "esc":
			// Go back a step
			if m.currentStep > StepWelcome && m.currentStep < StepExecute {
				m.currentStep--
				(&m).focusInputsForCurrentStep()
			}
			return m, nil

		case "down", "j":
			// Move down in lists or to next input field
			switch m.currentStep {
			case StepCategorySelection:
				if m.categoryCursor < len(m.categoryOptions)-1 {
					m.categoryCursor++
				}
				return m, nil
			case StepTemplateSelection:
				if m.templateCursor < len(m.templateOptions)-1 {
					m.templateCursor++
				}
				return m, nil
			case StepUsageProfile:
				if m.profileCursor < len(m.profileOptions)-1 {
					m.profileCursor++
				}
				return m, nil
			case StepProject, StepGitHub:
				maxInputs := m.getMaxInputsForStep()
				m.focusedInput = (m.focusedInput + 1) % maxInputs
				(&m).focusInputsForCurrentStep()
				return m, nil
			}

		case "up", "k":
			// Move up in lists or to previous input field
			switch m.currentStep {
			case StepCategorySelection:
				if m.categoryCursor > 0 {
					m.categoryCursor--
				}
				return m, nil
			case StepTemplateSelection:
				if m.templateCursor > 0 {
					m.templateCursor--
				}
				return m, nil
			case StepUsageProfile:
				if m.profileCursor > 0 {
					m.profileCursor--
				}
				return m, nil
			case StepProject, StepGitHub:
				maxInputs := m.getMaxInputsForStep()
				m.focusedInput--
				if m.focusedInput < 0 {
					m.focusedInput = maxInputs - 1
				}
				(&m).focusInputsForCurrentStep()
				return m, nil
			}
		}

	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		return m, nil
	}

	// Update only the focused input with the message
	// This allows typing and cursor movement in the focused field
	switch m.currentStep {
	case StepProject:
		switch m.focusedInput {
		case 0:
			m.projectCodeInput, cmd = m.projectCodeInput.Update(msg)
		case 1:
			m.emailInput, cmd = m.emailInput.Update(msg)
		case 2:
			m.ouIDInput, cmd = m.ouIDInput.Update(msg)
		}
	case StepGitHub:
		switch m.focusedInput {
		case 0:
			m.githubOrgInput, cmd = m.githubOrgInput.Update(msg)
		case 1:
			m.githubRepoInput, cmd = m.githubRepoInput.Update(msg)
		}
	}

	return m, cmd
}

// View renders the current view
func (m WizardModel) View() string {
	if m.quitting {
		return ""
	}

	switch m.currentStep {
	case StepWelcome:
		return m.viewWelcome()
	case StepCategorySelection:
		return m.viewCategorySelection()
	case StepTemplateSelection:
		return m.viewTemplateSelection()
	case StepUsageProfile:
		return m.viewUsageProfile()
	case StepCostEstimate:
		return m.viewCostEstimate()
	case StepBootstrapDecision:
		return m.viewBootstrapDecision()
	case StepPrerequisitesCheck:
		return m.viewPrerequisitesCheck()
	case StepProject:
		return m.viewProject()
	case StepGitHub:
		return m.viewGitHub()
	case StepReview:
		return m.viewReview()
	case StepExecute:
		return m.viewExecute()
	case StepComplete:
		return m.viewComplete()
	default:
		return "Unknown step"
	}
}

// handleEnter handles the enter key based on current step
func (m WizardModel) handleEnter() (tea.Model, tea.Cmd) {
	switch m.currentStep {
	case StepWelcome:
		// Move to category selection and load remote templates
		m.currentStep = StepCategorySelection
		m.loadingTemplates = true
		return m, m.loadRemoteTemplates()

	case StepCategorySelection:
		// Select category and filter templates
		if m.categoryCursor < len(m.categoryOptions) {
			m.selectedCategory = m.categoryOptions[m.categoryCursor]

			// Filter templates by selected category
			m.templateOptions = []ports.TemplateInfo{}
			for _, t := range m.allTemplates {
				if t.Category == m.selectedCategory {
					m.templateOptions = append(m.templateOptions, t)
				}
			}

			m.templateCursor = 0
			m.currentStep = StepTemplateSelection
		}

	case StepTemplateSelection:
		// Select template and move to usage profile
		if m.templateCursor < len(m.templateOptions) {
			m.selectedTemplate = m.templateOptions[m.templateCursor]

			// Download template content if it's a remote template
			if m.selectedTemplate.DownloadURL != "" {
				content, err := m.templateLoader.DownloadTemplate(m.selectedTemplate.DownloadURL)
				if err != nil {
					m.err = fmt.Errorf("failed to download template: %w", err)
					log.Printf("Error downloading template: %v", err)
					m.selectedTemplateContent = ""
				} else {
					m.selectedTemplateContent = content
				}
			} else {
				// Built-in template (bootstrap) - no content needed
				m.selectedTemplateContent = ""
			}

			m.currentStep = StepUsageProfile
		}

	case StepUsageProfile:
		// Select usage profile and trigger cost estimation
		if m.profileCursor < len(m.profileOptions) {
			m.usageProfile = m.profileOptions[m.profileCursor]
			m.currentStep = StepCostEstimate
			m.estimatingCost = true
			// Trigger cost estimation
			return m, m.estimateCosts()
		}

	case StepCostEstimate:
		// Don't allow moving forward if still estimating
		if m.estimatingCost {
			return m, nil
		}
		// Move to bootstrap decision
		m.currentStep = StepBootstrapDecision

	case StepBootstrapDecision:
		// If user wants to bootstrap, check prerequisites
		// For now, assume yes and move to prerequisites
		m.currentStep = StepPrerequisitesCheck
		m.checkingPrereqs = true
		return m, m.checkPrerequisites()

	case StepPrerequisitesCheck:
		// Check if all prerequisites passed
		allPassed := true
		for _, result := range m.prerequisiteResults {
			if result.IsFail() {
				allPassed = false
				break
			}
		}
		if !allPassed {
			// Stay on this step, user needs to fix prerequisites
			return m, nil
		}
		// All passed, move to project configuration
		m.currentStep = StepProject
		m.focusedInput = 0
		(&m).focusInputsForCurrentStep()

	case StepProject:
		// Validate and move to next step
		if m.validateProjectStep() {
			m.updateConfigFromInputs()
			m.currentStep = StepGitHub
			m.focusedInput = 0
			(&m).focusInputsForCurrentStep()
		}

	case StepGitHub:
		// Validate and move to review
		if m.validateGitHubStep() {
			m.updateConfigFromInputs()
			m.currentStep = StepReview
		}

	case StepReview:
		// User confirmed, start execution
		m.currentStep = StepExecute
		m.executing = true
		// TODO: Trigger actual execution

	case StepExecute:
		// Execution complete, show success
		m.currentStep = StepComplete

	case StepComplete:
		m.quitting = true
		return m, tea.Quit
	}

	return m, nil
}

// handleTabForward moves focus to next input field
func (m WizardModel) handleTabForward() (tea.Model, tea.Cmd) {
	maxInputs := m.getMaxInputsForStep()
	if maxInputs > 0 {
		m.focusedInput = (m.focusedInput + 1) % maxInputs
		m.focusInputsForCurrentStep()
	}
	return m, nil
}

// handleTabBackward moves focus to previous input field
func (m WizardModel) handleTabBackward() (tea.Model, tea.Cmd) {
	maxInputs := m.getMaxInputsForStep()
	if maxInputs > 0 {
		m.focusedInput--
		if m.focusedInput < 0 {
			m.focusedInput = maxInputs - 1
		}
		m.focusInputsForCurrentStep()
	}
	return m, nil
}

// getMaxInputsForStep returns the number of inputs for the current step
func (m WizardModel) getMaxInputsForStep() int {
	switch m.currentStep {
	case StepProject:
		return 3
	case StepGitHub:
		return 2
	default:
		return 0
	}
}

// focusInputsForCurrentStep sets focus on the appropriate input
func (m *WizardModel) focusInputsForCurrentStep() {
	// Blur all inputs first
	m.projectCodeInput.Blur()
	m.emailInput.Blur()
	m.ouIDInput.Blur()
	m.githubOrgInput.Blur()
	m.githubRepoInput.Blur()

	// Focus the current input based on step and focusedInput
	switch m.currentStep {
	case StepProject:
		switch m.focusedInput {
		case 0:
			m.projectCodeInput.Focus()
		case 1:
			m.emailInput.Focus()
		case 2:
			m.ouIDInput.Focus()
		}
	case StepGitHub:
		switch m.focusedInput {
		case 0:
			m.githubOrgInput.Focus()
		case 1:
			m.githubRepoInput.Focus()
		}
	}
}

// validateProjectStep validates project configuration inputs
func (m *WizardModel) validateProjectStep() bool {
	m.validationErrors = make(map[string]string)
	valid := true

	if err := config.ValidateProjectCode(m.projectCodeInput.Value()); err != nil {
		m.validationErrors["project_code"] = err.Error()
		valid = false
	}

	if err := config.ValidateEmail(m.emailInput.Value()); err != nil {
		m.validationErrors["email"] = err.Error()
		valid = false
	}

	if err := config.ValidateOUID(m.ouIDInput.Value()); err != nil {
		m.validationErrors["ou_id"] = err.Error()
		valid = false
	}

	return valid
}

// validateGitHubStep validates GitHub configuration inputs
func (m *WizardModel) validateGitHubStep() bool {
	m.validationErrors = make(map[string]string)
	valid := true

	if m.githubOrgInput.Value() == "" {
		m.validationErrors["github_org"] = "GitHub organization is required"
		valid = false
	}

	if m.githubRepoInput.Value() == "" {
		m.validationErrors["github_repo"] = "GitHub repository name is required"
		valid = false
	}

	return valid
}

// updateConfigFromInputs updates the config from input values
func (m *WizardModel) updateConfigFromInputs() {
	m.config.ProjectCode = m.projectCodeInput.Value()
	// Extract prefix if user entered a full email
	m.config.EmailPrefix = config.ExtractEmailPrefix(m.emailInput.Value())
	m.config.OUID = m.ouIDInput.Value()
	m.config.GitHub.Org = m.githubOrgInput.Value()
	m.config.GitHub.RepoName = m.githubRepoInput.Value()
}

// GetConfig returns the final configuration
func (m WizardModel) GetConfig() *config.Config {
	return m.config
}

// viewWelcome renders the welcome screen
func (m WizardModel) viewWelcome() string {
	content := fmt.Sprintf(`
%s

%s

This wizard will help you create a production-ready AWS
multi-account setup with GitHub Actions CI/CD.

What will be created:
  %s 3 AWS accounts (Dev, Staging, Prod)
  %s GitHub repository with CI/CD workflows
  %s OIDC authentication (no stored credentials)
  %s Billing alerts and budgets
  %s AWS CDK bootstrap in all accounts

%s

Press Enter to continue, or Ctrl+C to exit.
`,
		styles.RenderTitle("AWS Multi-Account Bootstrap"),
		styles.RenderSubtitle("v2.0.0-alpha"),
		styles.CheckmarkStyle.Render("✓"),
		styles.CheckmarkStyle.Render("✓"),
		styles.CheckmarkStyle.Render("✓"),
		styles.CheckmarkStyle.Render("✓"),
		styles.CheckmarkStyle.Render("✓"),
		styles.RenderHint("Estimated time: 5-10 minutes"),
	)

	return styles.WelcomeBoxStyle.Render(content)
}

// Run starts the TUI wizard
func Run(cfg *config.Config) (*config.Config, error) {
	m := NewWizard(cfg)
	p := tea.NewProgram(m, tea.WithAltScreen())

	finalModel, err := p.Run()
	if err != nil {
		return nil, fmt.Errorf("error running TUI: %w", err)
	}

	// Extract the final model
	if wizardModel, ok := finalModel.(WizardModel); ok {
		return wizardModel.GetConfig(), nil
	}

	return nil, fmt.Errorf("unexpected model type")
}