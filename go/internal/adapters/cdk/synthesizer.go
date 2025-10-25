package cdk

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/model"
	"github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/ports"
)

// Synthesizer implements ports.TemplateParser for AWS CDK applications
// It runs `cdk synth` to generate CloudFormation and then delegates to CFN parser
type Synthesizer struct{
	cfnParser ports.TemplateParser
}

// NewSynthesizer creates a CDK synthesizer
// Requires a CloudFormation parser to parse the synthesized output
func NewSynthesizer(cfnParser ports.TemplateParser) ports.TemplateParser {
	return &Synthesizer{
		cfnParser: cfnParser,
	}
}

// ParseTemplate synthesizes CDK app and extracts resources
// Input: Path to CDK app directory (not template content directly)
// The "content" parameter is treated as a directory path
func (s *Synthesizer) ParseTemplate(cdkAppPath string) ([]model.Resource, error) {
	// Validate CDK app path exists
	if _, err := os.Stat(cdkAppPath); os.IsNotExist(err) {
		return nil, fmt.Errorf("CDK app directory does not exist: %s", cdkAppPath)
	}

	// Check for cdk.json
	cdkJsonPath := filepath.Join(cdkAppPath, "cdk.json")
	if _, err := os.Stat(cdkJsonPath); os.IsNotExist(err) {
		return nil, fmt.Errorf("not a valid CDK app (cdk.json not found): %s", cdkAppPath)
	}

	// Run cdk synth
	cfnTemplate, err := s.runCDKSynth(cdkAppPath)
	if err != nil {
		return nil, fmt.Errorf("cdk synth failed: %w", err)
	}

	// Parse the generated CloudFormation template
	return s.cfnParser.ParseTemplate(cfnTemplate)
}

// SupportedFormats returns the formats this parser supports
func (s *Synthesizer) SupportedFormats() []string {
	return []string{"cdk"}
}

// runCDKSynth executes `cdk synth` and returns the generated CloudFormation template
func (s *Synthesizer) runCDKSynth(cdkAppPath string) (string, error) {
	// Check if cdk CLI is available
	if _, err := exec.LookPath("cdk"); err != nil {
		return "", fmt.Errorf("cdk CLI not found in PATH: %w", err)
	}

	// Prepare command: cdk synth --json
	cmd := exec.Command("cdk", "synth", "--json")
	cmd.Dir = cdkAppPath

	// Capture output
	output, err := cmd.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("cdk synth command failed: %w\nOutput: %s", err, string(output))
	}

	// cdk synth output format:
	// Sometimes includes metadata before the template JSON
	// Extract the JSON template from the output
	templateJSON := s.extractTemplateFromOutput(string(output))
	if templateJSON == "" {
		return "", fmt.Errorf("failed to extract CloudFormation template from cdk synth output")
	}

	return templateJSON, nil
}

// extractTemplateFromOutput extracts the CloudFormation template from cdk synth output
// cdk synth may include additional output, so we need to find the JSON template
func (s *Synthesizer) extractTemplateFromOutput(output string) string {
	// If output starts with '{', it's likely pure JSON
	trimmed := strings.TrimSpace(output)
	if strings.HasPrefix(trimmed, "{") {
		return trimmed
	}

	// Otherwise, try to find the JSON object
	// Look for the first '{' and extract from there
	startIdx := strings.Index(output, "{")
	if startIdx == -1 {
		return ""
	}

	// Find matching closing brace (simple approach - count braces)
	depth := 0
	for i := startIdx; i < len(output); i++ {
		if output[i] == '{' {
			depth++
		} else if output[i] == '}' {
			depth--
			if depth == 0 {
				return output[startIdx : i+1]
			}
		}
	}

	return ""
}
