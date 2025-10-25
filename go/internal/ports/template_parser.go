package ports

import "github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/model"

// TemplateParser parses infrastructure-as-code templates
// Port (interface) - can be implemented by CloudFormation, CDK, Terraform, etc.
type TemplateParser interface {
	// ParseTemplate extracts resources from template content
	// Input: Raw template content (JSON, YAML, or other format)
	// Output: List of discovered resources
	// Error: If template is invalid or unsupported format
	ParseTemplate(content string) ([]model.Resource, error)

	// SupportedFormats returns the template formats this parser supports
	// e.g., ["cloudformation-json", "cloudformation-yaml"]
	SupportedFormats() []string
}