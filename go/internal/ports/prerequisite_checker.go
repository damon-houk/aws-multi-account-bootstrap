package ports

// PrerequisiteChecker checks system prerequisites for bootstrap
// Port: Defines interface for checking required tools and access
type PrerequisiteChecker interface {
	// CheckAll runs all prerequisite checks
	CheckAll() []PrerequisiteResult

	// CheckAWSAccess verifies AWS credentials are configured
	CheckAWSAccess() PrerequisiteResult

	// CheckGitHubAccess verifies GitHub CLI is authenticated
	CheckGitHubAccess() PrerequisiteResult

	// CheckCDKInstalled verifies AWS CDK CLI is installed
	CheckCDKInstalled() PrerequisiteResult
}

// PrerequisiteResult represents the result of a prerequisite check
type PrerequisiteResult struct {
	Name        string           // Check name (e.g., "AWS Access")
	Description string           // Human-readable description
	Status      PrerequisiteStatus // Pass, fail, or warning
	Error       error            // Error if check failed
	FixCommand  string           // Suggested command to fix (e.g., "gh auth login")
}

// PrerequisiteStatus represents the status of a check
type PrerequisiteStatus string

const (
	PrerequisitePass    PrerequisiteStatus = "pass"
	PrerequisiteFail    PrerequisiteStatus = "fail"
	PrerequisiteWarning PrerequisiteStatus = "warning"
)

// IsPass returns true if status is pass
func (r PrerequisiteResult) IsPass() bool {
	return r.Status == PrerequisitePass
}

// IsFail returns true if status is fail
func (r PrerequisiteResult) IsFail() bool {
	return r.Status == PrerequisiteFail
}

// IsWarning returns true if status is warning
func (r PrerequisiteResult) IsWarning() bool {
	return r.Status == PrerequisiteWarning
}