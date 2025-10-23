package styles

import "github.com/charmbracelet/lipgloss"

var (
	// Colors
	ColorPrimary   = lipgloss.Color("#00D9FF") // Cyan
	ColorSecondary = lipgloss.Color("#7C3AED") // Purple
	ColorSuccess   = lipgloss.Color("#10B981") // Green
	ColorWarning   = lipgloss.Color("#F59E0B") // Orange
	ColorError     = lipgloss.Color("#EF4444") // Red
	ColorMuted     = lipgloss.Color("#6B7280") // Gray
	ColorBorder    = lipgloss.Color("#374151") // Dark gray

	// Box styles
	BoxBorder = lipgloss.NewStyle().
			BorderStyle(lipgloss.RoundedBorder()).
			BorderForeground(ColorBorder).
			Padding(1, 2)

	// Header styles
	TitleStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(ColorPrimary).
			Align(lipgloss.Center).
			Padding(1, 0)

	SubtitleStyle = lipgloss.NewStyle().
			Foreground(ColorMuted).
			Align(lipgloss.Center).
			Padding(0, 0, 1, 0)

	// Step indicator
	StepStyle = lipgloss.NewStyle().
			Foreground(ColorSecondary).
			Bold(true).
			Padding(0, 0, 1, 0)

	// Input field styles
	LabelStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#FBBF24")). // Yellow
			Bold(true)

	InputStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#FFFFFF")).
			Background(lipgloss.Color("#1F2937")).
			Padding(0, 1)

	FocusedInputStyle = lipgloss.NewStyle().
				Foreground(lipgloss.Color("#FFFFFF")).
				Background(lipgloss.Color("#374151")).
				BorderStyle(lipgloss.RoundedBorder()).
				BorderForeground(ColorPrimary).
				Padding(0, 1)

	HintStyle = lipgloss.NewStyle().
			Foreground(ColorMuted).
			Italic(true).
			Padding(0, 0, 0, 2)

	// Validation styles
	ErrorStyle = lipgloss.NewStyle().
			Foreground(ColorError).
			Bold(true).
			Padding(0, 0, 0, 2)

	SuccessStyle = lipgloss.NewStyle().
			Foreground(ColorSuccess).
			Bold(true).
			Padding(0, 0, 0, 2)

	// List item styles
	ListItemStyle = lipgloss.NewStyle().
			Padding(0, 0, 0, 2)

	CheckmarkStyle = lipgloss.NewStyle().
			Foreground(ColorSuccess).
			Bold(true)

	// Table styles
	TableHeaderStyle = lipgloss.NewStyle().
				Foreground(ColorPrimary).
				Bold(true).
				BorderStyle(lipgloss.NormalBorder()).
				BorderForeground(ColorBorder).
				BorderBottom(true).
				Padding(0, 1)

	TableCellStyle = lipgloss.NewStyle().
			Padding(0, 1)

	// Navigation help
	NavHelpStyle = lipgloss.NewStyle().
			Foreground(ColorMuted).
			Padding(1, 0, 0, 0)

	// Progress bar
	ProgressBarStyle = lipgloss.NewStyle().
				Foreground(ColorPrimary).
				Bold(true)

	ProgressEmptyStyle = lipgloss.NewStyle().
				Foreground(ColorMuted)

	// Status messages
	StatusStyle = lipgloss.NewStyle().
			Foreground(ColorMuted).
			Italic(true)

	SpinnerStyle = lipgloss.NewStyle().
			Foreground(ColorPrimary)

	// Welcome/complete screens
	WelcomeBoxStyle = lipgloss.NewStyle().
			BorderStyle(lipgloss.DoubleBorder()).
			BorderForeground(ColorPrimary).
			Padding(2, 4).
			Align(lipgloss.Center)

	SuccessBoxStyle = lipgloss.NewStyle().
			BorderStyle(lipgloss.DoubleBorder()).
			BorderForeground(ColorSuccess).
			Padding(2, 4).
			Align(lipgloss.Center)

	// Confirmation prompt
	WarningBoxStyle = lipgloss.NewStyle().
			BorderStyle(lipgloss.RoundedBorder()).
			BorderForeground(ColorWarning).
			Padding(1, 2).
			Background(lipgloss.Color("#422006"))
)

// RenderBox renders content in a styled box
func RenderBox(content string, style lipgloss.Style) string {
	return style.Render(content)
}

// RenderTitle renders a centered title
func RenderTitle(title string) string {
	return TitleStyle.Render(title)
}

// RenderSubtitle renders a centered subtitle
func RenderSubtitle(subtitle string) string {
	return SubtitleStyle.Render(subtitle)
}

// RenderStep renders a step indicator (e.g., "[1/5] Project Configuration")
func RenderStep(current, total int, title string) string {
	return StepStyle.Render(lipgloss.JoinHorizontal(
		lipgloss.Left,
		lipgloss.NewStyle().Foreground(ColorMuted).Render("["),
		lipgloss.NewStyle().Foreground(ColorPrimary).Bold(true).Render(lipgloss.JoinHorizontal(lipgloss.Left, string(rune('0'+current)), "/", string(rune('0'+total)))),
		lipgloss.NewStyle().Foreground(ColorMuted).Render("] "),
		title,
	))
}

// RenderError renders an error message with icon
func RenderError(msg string) string {
	return ErrorStyle.Render("✗ " + msg)
}

// RenderSuccess renders a success message with icon
func RenderSuccess(msg string) string {
	return SuccessStyle.Render("✓ " + msg)
}

// RenderHint renders a hint/help text
func RenderHint(hint string) string {
	return HintStyle.Render("  " + hint)
}

// RenderNavHelp renders navigation help text
func RenderNavHelp(help string) string {
	return NavHelpStyle.Render(help)
}