package account

import (
	"fmt"
	"regexp"
	"strings"
)

// Business rules for account naming conventions.
//
// This file contains PURE business logic - no infrastructure dependencies.
// These functions define the naming standards for multi-account setup.
//
// Hexagonal Architecture:
//   - This is DOMAIN LOGIC (pure functions)
//   - No imports from adapters or ports
//   - Can be tested without any infrastructure

// Environment represents a deployment environment.
type Environment string

const (
	EnvironmentDev     Environment = "dev"
	EnvironmentStaging Environment = "staging"
	EnvironmentProd    Environment = "prod"
)

// AllEnvironments returns all supported environments in order.
func AllEnvironments() []Environment {
	return []Environment{EnvironmentDev, EnvironmentStaging, EnvironmentProd}
}

// GenerateAccountName generates a cloud account name following our naming convention.
//
// Convention: ${PROJECT_CODE}_${ENV_UPPER}
// Example: "TPA_DEV", "TPA_STAGING", "TPA_PROD"
//
// Parameters:
//   - projectCode: 3-character project identifier (e.g., "TPA")
//   - env: Environment name (dev, staging, prod)
//
// Returns:
//   - Account name as a string
func GenerateAccountName(projectCode string, env Environment) string {
	envUpper := strings.ToUpper(string(env))
	return fmt.Sprintf("%s_%s", projectCode, envUpper)
}

// GenerateAccountEmail generates an email address for an account using plus addressing.
//
// Convention: ${email_prefix}+${project_code_lower}-${env}@gmail.com
// Example: "user+tpa-dev@gmail.com"
//
// Parameters:
//   - emailPrefix: Email address (can include or exclude @gmail.com)
//   - projectCode: 3-character project identifier
//   - env: Environment name
//
// Returns:
//   - Email address as a string
func GenerateAccountEmail(emailPrefix string, projectCode string, env Environment) string {
	// Strip @gmail.com if present
	prefix := strings.TrimSuffix(emailPrefix, "@gmail.com")

	// Lowercase project code and environment
	projectLower := strings.ToLower(projectCode)
	envLower := strings.ToLower(string(env))

	return fmt.Sprintf("%s+%s-%s@gmail.com", prefix, projectLower, envLower)
}

// GetOrganizationAccessRoleName returns the standard role name for cross-account access.
//
// This is a business constant - always the same value.
func GetOrganizationAccessRoleName() string {
	return "OrganizationAccountAccessRole"
}

// Validation

var (
	// ProjectCode must be exactly 3 alphanumeric characters
	projectCodeRegex = regexp.MustCompile(`^[A-Z0-9]{3}$`)

	// Email basic validation
	emailRegex = regexp.MustCompile(`^[a-zA-Z0-9._%+-]+(@gmail\.com)?$`)

	// Organizational Unit ID format
	ouIDRegex = regexp.MustCompile(`^ou-[a-z0-9]+-[a-z0-9]+$`)
)

// ValidationError represents a validation failure with a descriptive message.
type ValidationError struct {
	Field   string
	Message string
}

func (e *ValidationError) Error() string {
	return fmt.Sprintf("%s: %s", e.Field, e.Message)
}

// ValidateProjectCode validates a project code according to business rules.
//
// Rules:
//   - Must be exactly 3 characters
//   - Must contain only uppercase letters or numbers
//
// Parameters:
//   - projectCode: The project code to validate
//
// Returns:
//   - Error if invalid, nil if valid
func ValidateProjectCode(projectCode string) error {
	if len(projectCode) != 3 {
		return &ValidationError{
			Field:   "projectCode",
			Message: "must be exactly 3 characters",
		}
	}

	if !projectCodeRegex.MatchString(projectCode) {
		return &ValidationError{
			Field:   "projectCode",
			Message: "must contain only uppercase letters or numbers",
		}
	}

	return nil
}

// ValidateEmailPrefix validates an email prefix according to business rules.
//
// Rules:
//   - Must be a valid email format
//   - Can optionally include @gmail.com suffix
//
// Parameters:
//   - email: The email prefix to validate
//
// Returns:
//   - Error if invalid, nil if valid
func ValidateEmailPrefix(email string) error {
	if !emailRegex.MatchString(email) {
		return &ValidationError{
			Field:   "emailPrefix",
			Message: "must be a valid email format",
		}
	}

	return nil
}

// ValidateOUID validates an organizational unit ID according to business rules.
//
// Rules:
//   - Must start with "ou-"
//   - Must match format: ou-xxxx-xxxxxxxx
//
// Parameters:
//   - ouID: The OU ID to validate
//
// Returns:
//   - Error if invalid, nil if valid
func ValidateOUID(ouID string) error {
	if !strings.HasPrefix(ouID, "ou-") {
		return &ValidationError{
			Field:   "ouID",
			Message: "must start with 'ou-'",
		}
	}

	if !ouIDRegex.MatchString(ouID) {
		return &ValidationError{
			Field:   "ouID",
			Message: "invalid format (expected: ou-xxxx-xxxxxxxx)",
		}
	}

	return nil
}

// ValidateEnvironment validates an environment name against supported values.
//
// Parameters:
//   - env: The environment to validate
//
// Returns:
//   - Error if invalid, nil if valid
func ValidateEnvironment(env Environment) error {
	for _, validEnv := range AllEnvironments() {
		if env == validEnv {
			return nil
		}
	}

	return &ValidationError{
		Field:   "environment",
		Message: fmt.Sprintf("must be one of: %v", AllEnvironments()),
	}
}

// Config represents the configuration for creating multi-account setup.
//
// This is a value object in Domain-Driven Design terms - it holds
// the business data needed for account creation.
type Config struct {
	ProjectCode  string        // 3-character project identifier
	EmailPrefix  string        // Email address prefix
	OUID         string        // Organizational unit ID
	Environments []Environment // Environments to create (default: dev, staging, prod)
}

// Validate validates all fields in the configuration.
//
// Returns:
//   - Error if any validation fails, nil if all valid
func (c *Config) Validate() error {
	if err := ValidateProjectCode(c.ProjectCode); err != nil {
		return err
	}

	if err := ValidateEmailPrefix(c.EmailPrefix); err != nil {
		return err
	}

	if err := ValidateOUID(c.OUID); err != nil {
		return err
	}

	// Validate environments (or use default)
	envs := c.Environments
	if len(envs) == 0 {
		envs = AllEnvironments()
	}

	for _, env := range envs {
		if err := ValidateEnvironment(env); err != nil {
			return err
		}
	}

	return nil
}

// AccountInfo represents information about a created account.
//
// This is returned by domain logic to the caller.
type AccountInfo struct {
	Name        string
	Email       string
	AccountID   string
	Environment Environment
}

// GenerateSummary generates a human-readable summary of accounts to be created.
//
// This is pure presentation logic - no side effects.
//
// Parameters:
//   - config: The configuration
//
// Returns:
//   - Summary string
func GenerateSummary(config Config) string {
	envs := config.Environments
	if len(envs) == 0 {
		envs = AllEnvironments()
	}

	var summary strings.Builder
	summary.WriteString("Multi-Account Setup Summary\n")
	summary.WriteString("===========================\n")
	summary.WriteString(fmt.Sprintf("Project Code: %s\n", config.ProjectCode))
	summary.WriteString(fmt.Sprintf("Email Prefix: %s\n", config.EmailPrefix))
	summary.WriteString(fmt.Sprintf("OU ID:        %s\n", config.OUID))
	summary.WriteString("\nAccounts to be created:\n")

	for _, env := range envs {
		name := GenerateAccountName(config.ProjectCode, env)
		email := GenerateAccountEmail(config.EmailPrefix, config.ProjectCode, env)
		summary.WriteString(fmt.Sprintf("  %-15s -> %s\n", name, email))
	}

	return summary.String()
}
