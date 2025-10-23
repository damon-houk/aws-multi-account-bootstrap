package config

import (
	"fmt"
	"net/mail"
	"regexp"
	"strings"
)

// Config represents the complete configuration for AWS multi-account bootstrap
type Config struct {
	// Project configuration
	ProjectCode string `mapstructure:"project_code" json:"project_code"`
	EmailPrefix string `mapstructure:"email_prefix" json:"email_prefix"`
	OUID        string `mapstructure:"ou_id" json:"ou_id"`

	// GitHub configuration
	GitHub GitHubConfig `mapstructure:"github" json:"github"`

	// AWS configuration
	AWS AWSConfig `mapstructure:"aws" json:"aws"`

	// Behavior flags
	DryRun         bool `mapstructure:"dry_run" json:"dry_run"`
	Interactive    bool `mapstructure:"interactive" json:"interactive"`
	NonInteractive bool `mapstructure:"non_interactive" json:"non_interactive"`
	JSONOutput     bool `mapstructure:"json" json:"json"`
}

// GitHubConfig contains GitHub-specific configuration
type GitHubConfig struct {
	Org      string `mapstructure:"org" json:"org"`
	RepoName string `mapstructure:"repo_name" json:"repo_name"`
	Token    string `mapstructure:"token" json:"token,omitempty"` // omit from JSON for security
}

// AWSConfig contains AWS-specific configuration
type AWSConfig struct {
	Profile string `mapstructure:"profile" json:"profile"`
	Region  string `mapstructure:"region" json:"region"`
}

// AccountEmails returns the generated email addresses for all accounts
func (c *Config) AccountEmails() []string {
	projectCode := strings.ToLower(c.ProjectCode)
	return []string{
		fmt.Sprintf("%s+%s-dev@gmail.com", c.EmailPrefix, projectCode),
		fmt.Sprintf("%s+%s-staging@gmail.com", c.EmailPrefix, projectCode),
		fmt.Sprintf("%s+%s-prod@gmail.com", c.EmailPrefix, projectCode),
	}
}

// AccountNames returns the generated account names
func (c *Config) AccountNames() []string {
	projectCode := strings.ToUpper(c.ProjectCode)
	return []string{
		fmt.Sprintf("%s_DEV", projectCode),
		fmt.Sprintf("%s_STAGING", projectCode),
		fmt.Sprintf("%s_PROD", projectCode),
	}
}

// Validate validates the configuration
func (c *Config) Validate() error {
	// Validate project code (3 letters, alphanumeric)
	if err := ValidateProjectCode(c.ProjectCode); err != nil {
		return err
	}

	// Validate email prefix
	if err := ValidateEmail(c.EmailPrefix); err != nil {
		return err
	}

	// Validate OU ID
	if err := ValidateOUID(c.OUID); err != nil {
		return err
	}

	// Validate GitHub org
	if c.GitHub.Org == "" {
		return fmt.Errorf("GitHub organization is required")
	}

	// Validate GitHub repo name
	if c.GitHub.RepoName == "" {
		return fmt.Errorf("GitHub repository name is required")
	}

	return nil
}

// ValidateProjectCode validates that the project code is 3 letters, alphanumeric
func ValidateProjectCode(code string) error {
	if len(code) != 3 {
		return fmt.Errorf("project code must be exactly 3 characters (got %d)", len(code))
	}

	matched, err := regexp.MatchString("^[A-Za-z0-9]{3}$", code)
	if err != nil {
		return fmt.Errorf("error validating project code: %w", err)
	}

	if !matched {
		return fmt.Errorf("project code must be alphanumeric (A-Z, a-z, 0-9)")
	}

	return nil
}

// ValidateEmail validates the email prefix or full email
// Accepts either:
// - Just a prefix: "junk" -> uses as-is
// - Full email: "junk@gmail.com" -> extracts "junk" as prefix
func ValidateEmail(emailInput string) error {
	if emailInput == "" {
		return fmt.Errorf("email is required")
	}

	// If it contains @, treat it as a full email and validate it
	if strings.Contains(emailInput, "@") {
		// Use Go's standard library to validate the email
		_, err := mail.ParseAddress(emailInput)
		if err != nil {
			return fmt.Errorf("invalid email address: %w", err)
		}
		// Email is valid - we'll extract the prefix when needed
		return nil
	}

	// It's just a prefix - validate it contains only valid characters
	// Valid characters in email local part: alphanumeric, dot, underscore, percent, plus, dash
	matched, err := regexp.MatchString("^[a-zA-Z0-9._%+-]+$", emailInput)
	if err != nil {
		return fmt.Errorf("error validating email prefix: %w", err)
	}

	if !matched {
		return fmt.Errorf("email prefix contains invalid characters (use only letters, numbers, dots, underscores, percent, plus, dash)")
	}

	return nil
}

// ExtractEmailPrefix extracts the prefix from an email or returns the input if it's already a prefix
func ExtractEmailPrefix(emailInput string) string {
	if strings.Contains(emailInput, "@") {
		// Extract everything before the @
		parts := strings.Split(emailInput, "@")
		return parts[0]
	}
	return emailInput
}

// ValidateOUID validates the AWS Organization Unit ID format
func ValidateOUID(ouid string) error {
	if ouid == "" {
		return fmt.Errorf("AWS Organization Unit ID is required")
	}

	// Format: ou-xxxx-xxxxxxxx
	matched, err := regexp.MatchString("^ou-[a-z0-9]{4}-[a-z0-9]{8}$", ouid)
	if err != nil {
		return fmt.Errorf("error validating OU ID: %w", err)
	}

	if !matched {
		return fmt.Errorf("OU ID must be in format: ou-xxxx-xxxxxxxx")
	}

	return nil
}