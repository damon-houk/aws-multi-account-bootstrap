package tui

import (
	"fmt"

	"github.com/charmbracelet/bubbles/textinput"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/cli/config"
	"github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/cli/tui/styles"
)

// WizardStep represents the current step in the wizard
type WizardStep int

const (
	StepWelcome WizardStep = iota
	StepProject
	StepGitHub
	StepCostEstimate
	StepReview
	StepExecute
	StepComplete
)

// WizardModel is the main Bubbletea model for the TUI wizard
type WizardModel struct {
	currentStep WizardStep
	config      *config.Config
	width       int
	height      int
	err         error
	quitting    bool

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

	return WizardModel{
		currentStep:      StepWelcome,
		config:           cfg,
		projectCodeInput: projectCodeInput,
		emailInput:       emailInput,
		ouIDInput:        ouIDInput,
		githubOrgInput:   githubOrgInput,
		githubRepoInput:  githubRepoInput,
		focusedInput:     0,
		validationErrors: make(map[string]string),
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

		case "tab", "down", "ctrl+n":
			// Move to next input field
			if m.currentStep == StepProject || m.currentStep == StepGitHub {
				maxInputs := m.getMaxInputsForStep()
				m.focusedInput = (m.focusedInput + 1) % maxInputs
				(&m).focusInputsForCurrentStep()
				return m, nil
			}

		case "shift+tab", "up", "ctrl+p":
			// Move to previous input field
			if m.currentStep == StepProject || m.currentStep == StepGitHub {
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
	case StepProject:
		return m.viewProject()
	case StepGitHub:
		return m.viewGitHub()
	case StepCostEstimate:
		return m.viewCostEstimate()
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
		m.currentStep = StepProject
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
		// Validate and move to next step
		if m.validateGitHubStep() {
			m.updateConfigFromInputs()
			m.currentStep = StepCostEstimate
		}

	case StepCostEstimate:
		m.currentStep = StepReview

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