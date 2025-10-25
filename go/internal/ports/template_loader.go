package ports

// TemplateLoader loads templates from various sources
// Port: Defines interface for loading infrastructure templates
type TemplateLoader interface {
	// LoadTemplate loads a template from a path (file or directory)
	// Returns the template content as a string
	LoadTemplate(path string) (string, error)

	// GetTemplateType returns the type of template (cloudformation, cdk, etc.)
	GetTemplateType(path string) (TemplateType, error)

	// ListBuiltInTemplates returns available built-in templates
	ListBuiltInTemplates() []TemplateInfo

	// ListRemoteTemplates fetches and returns available remote templates
	// with optional category filter
	ListRemoteTemplates(category string) ([]TemplateInfo, error)

	// GetTemplateCategories returns all available categories
	GetTemplateCategories() ([]string, error)

	// DownloadTemplate downloads a remote template by URL
	DownloadTemplate(downloadURL string) (string, error)
}

// TemplateType represents the type of infrastructure template
type TemplateType string

const (
	TemplateTypeCloudFormation TemplateType = "cloudformation"
	TemplateTypeCDK            TemplateType = "cdk"
	TemplateTypeBootstrap      TemplateType = "bootstrap"
)

// TemplateInfo contains metadata about a template
type TemplateInfo struct {
	Name        string       // User-friendly name
	Path        string       // Path to template (file or directory)
	Type        TemplateType // Template type
	Description string       // Human-readable description
	IsBuiltIn   bool         // Whether this is a built-in template
	Category    string       // Template category (network, database, security, etc.)
	Source      string       // Template source (cloudonaut, aws-samples, etc.)
	Author      string       // Template author
	URL         string       // GitHub URL (for browsing)
	DownloadURL string       // Direct download URL
	Repository  string       // Repository name
}