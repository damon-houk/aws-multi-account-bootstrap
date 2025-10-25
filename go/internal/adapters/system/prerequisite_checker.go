package system

import (
	"fmt"
	"os/exec"

	"github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/ports"
)

// SystemPrerequisiteChecker checks system prerequisites
// Adapter: Implements PrerequisiteChecker port for system checks
type SystemPrerequisiteChecker struct{}

// NewSystemPrerequisiteChecker creates a new system prerequisite checker
func NewSystemPrerequisiteChecker() ports.PrerequisiteChecker {
	return &SystemPrerequisiteChecker{}
}

// CheckAll runs all prerequisite checks
func (c *SystemPrerequisiteChecker) CheckAll() []ports.PrerequisiteResult {
	return []ports.PrerequisiteResult{
		c.CheckCDKInstalled(),
		c.CheckAWSAccess(),
		c.CheckGitHubAccess(),
	}
}

// CheckAWSAccess verifies AWS credentials are configured
func (c *SystemPrerequisiteChecker) CheckAWSAccess() ports.PrerequisiteResult {
	result := ports.PrerequisiteResult{
		Name:        "AWS Access",
		Description: "AWS credentials configured and valid",
		FixCommand:  "aws configure",
	}

	// Check if AWS CLI is installed
	if _, err := exec.LookPath("aws"); err != nil {
		result.Status = ports.PrerequisiteFail
		result.Error = fmt.Errorf("AWS CLI not installed")
		result.FixCommand = "Install AWS CLI: https://aws.amazon.com/cli/"
		return result
	}

	// Try to get caller identity (verifies credentials work)
	cmd := exec.Command("aws", "sts", "get-caller-identity")
	if err := cmd.Run(); err != nil {
		result.Status = ports.PrerequisiteFail
		result.Error = fmt.Errorf("AWS credentials not configured or invalid")
		result.FixCommand = "aws configure"
		return result
	}

	result.Status = ports.PrerequisitePass
	return result
}

// CheckGitHubAccess verifies GitHub CLI is authenticated
func (c *SystemPrerequisiteChecker) CheckGitHubAccess() ports.PrerequisiteResult {
	result := ports.PrerequisiteResult{
		Name:        "GitHub Access",
		Description: "GitHub CLI authenticated",
		FixCommand:  "gh auth login",
	}

	// Check if GitHub CLI is installed
	if _, err := exec.LookPath("gh"); err != nil {
		result.Status = ports.PrerequisiteFail
		result.Error = fmt.Errorf("GitHub CLI not installed")
		result.FixCommand = "Install GitHub CLI: https://cli.github.com/"
		return result
	}

	// Check if authenticated
	cmd := exec.Command("gh", "auth", "status")
	if err := cmd.Run(); err != nil {
		result.Status = ports.PrerequisiteFail
		result.Error = fmt.Errorf("GitHub CLI not authenticated")
		result.FixCommand = "gh auth login"
		return result
	}

	result.Status = ports.PrerequisitePass
	return result
}

// CheckCDKInstalled verifies AWS CDK CLI is installed
func (c *SystemPrerequisiteChecker) CheckCDKInstalled() ports.PrerequisiteResult {
	result := ports.PrerequisiteResult{
		Name:        "AWS CDK",
		Description: "AWS CDK CLI installed",
		FixCommand:  "npm install -g aws-cdk",
	}

	// Check if CDK is installed
	if _, err := exec.LookPath("cdk"); err != nil {
		result.Status = ports.PrerequisiteWarning // Warning, not fail - only needed for CDK templates
		result.Error = fmt.Errorf("CDK CLI not installed")
		result.FixCommand = "npm install -g aws-cdk"
		return result
	}

	result.Status = ports.PrerequisitePass
	return result
}