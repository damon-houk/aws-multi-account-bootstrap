package cloudformation

import (
	"encoding/json"
	"fmt"

	"gopkg.in/yaml.v3"

	"github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/model"
	"github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/ports"
)

// Parser implements ports.TemplateParser for AWS CloudFormation templates
type Parser struct{}

// NewParser creates a CloudFormation template parser
func NewParser() ports.TemplateParser {
	return &Parser{}
}

// ParseTemplate extracts resources from a CloudFormation template (JSON or YAML)
func (p *Parser) ParseTemplate(content string) ([]model.Resource, error) {
	var cfnTemplate Template

	// Try JSON first
	err := json.Unmarshal([]byte(content), &cfnTemplate)
	if err != nil {
		// Try YAML
		err = yaml.Unmarshal([]byte(content), &cfnTemplate)
		if err != nil {
			return nil, fmt.Errorf("invalid CloudFormation template format: %w", err)
		}
	}

	// Validate template has resources
	if cfnTemplate.Resources == nil || len(cfnTemplate.Resources) == 0 {
		return nil, fmt.Errorf("template contains no resources")
	}

	// Extract resources
	resources := make([]model.Resource, 0, len(cfnTemplate.Resources))
	for logicalID, resource := range cfnTemplate.Resources {
		resources = append(resources, model.Resource{
			Type:       resource.Type,
			LogicalID:  logicalID,
			Properties: resource.Properties,
		})
	}

	return resources, nil
}

// SupportedFormats returns the formats this parser supports
func (p *Parser) SupportedFormats() []string {
	return []string{"cloudformation-json", "cloudformation-yaml"}
}

// Template represents a CloudFormation template structure
type Template struct {
	AWSTemplateFormatVersion string                `json:"AWSTemplateFormatVersion,omitempty" yaml:"AWSTemplateFormatVersion,omitempty"`
	Description              string                `json:"Description,omitempty" yaml:"Description,omitempty"`
	Parameters               map[string]Parameter  `json:"Parameters,omitempty" yaml:"Parameters,omitempty"`
	Resources                map[string]Resource   `json:"Resources" yaml:"Resources"`
	Outputs                  map[string]Output     `json:"Outputs,omitempty" yaml:"Outputs,omitempty"`
}

// Resource represents a CloudFormation resource
type Resource struct {
	Type       string                 `json:"Type" yaml:"Type"`
	Properties map[string]interface{} `json:"Properties,omitempty" yaml:"Properties,omitempty"`
	DependsOn  interface{}            `json:"DependsOn,omitempty" yaml:"DependsOn,omitempty"`
	Condition  string                 `json:"Condition,omitempty" yaml:"Condition,omitempty"`
}

// Parameter represents a CloudFormation parameter
type Parameter struct {
	Type        string      `json:"Type" yaml:"Type"`
	Default     interface{} `json:"Default,omitempty" yaml:"Default,omitempty"`
	Description string      `json:"Description,omitempty" yaml:"Description,omitempty"`
}

// Output represents a CloudFormation output
type Output struct {
	Value       interface{} `json:"Value" yaml:"Value"`
	Description string      `json:"Description,omitempty" yaml:"Description,omitempty"`
	Export      *Export     `json:"Export,omitempty" yaml:"Export,omitempty"`
}

// Export represents a CloudFormation export
type Export struct {
	Name string `json:"Name" yaml:"Name"`
}
