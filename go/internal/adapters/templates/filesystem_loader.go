package templates

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/ports"
)

// FilesystemTemplateLoader loads templates from the filesystem
// Adapter: Implements TemplateLoader port for filesystem access
type FilesystemTemplateLoader struct {
	builtInTemplates []ports.TemplateInfo
}

// NewFilesystemTemplateLoader creates a new filesystem template loader
func NewFilesystemTemplateLoader() ports.TemplateLoader {
	return &FilesystemTemplateLoader{
		builtInTemplates: []ports.TemplateInfo{
			{
				Name:        "Bootstrap (Default)",
				Path:        "builtin://bootstrap",
				Type:        ports.TemplateTypeBootstrap,
				Description: "Minimal bootstrap infrastructure (CloudWatch alarms + SNS notifications)",
				IsBuiltIn:   true,
			},
		},
	}
}

// LoadTemplate loads a template from a path
func (l *FilesystemTemplateLoader) LoadTemplate(path string) (string, error) {
	// Handle built-in templates
	if strings.HasPrefix(path, "builtin://") {
		return l.loadBuiltInTemplate(path)
	}

	// Check if path exists
	info, err := os.Stat(path)
	if err != nil {
		return "", fmt.Errorf("template path does not exist: %w", err)
	}

	// Determine template type and load accordingly
	templateType, err := l.GetTemplateType(path)
	if err != nil {
		return "", err
	}

	switch templateType {
	case ports.TemplateTypeCloudFormation:
		return l.loadCloudFormationTemplate(path, info)
	case ports.TemplateTypeCDK:
		return l.loadCDKTemplate(path)
	default:
		return "", fmt.Errorf("unsupported template type: %s", templateType)
	}
}

// GetTemplateType determines the type of template at the given path
func (l *FilesystemTemplateLoader) GetTemplateType(path string) (ports.TemplateType, error) {
	// Handle built-in templates
	if strings.HasPrefix(path, "builtin://") {
		return ports.TemplateTypeBootstrap, nil
	}

	// Check if path exists
	info, err := os.Stat(path)
	if err != nil {
		return "", fmt.Errorf("path does not exist: %w", err)
	}

	// If it's a file, check extension
	if !info.IsDir() {
		ext := strings.ToLower(filepath.Ext(path))
		if ext == ".json" || ext == ".yaml" || ext == ".yml" {
			return ports.TemplateTypeCloudFormation, nil
		}
		return "", fmt.Errorf("unknown file type: %s", ext)
	}

	// If it's a directory, check for CDK files
	if l.isCDKDirectory(path) {
		return ports.TemplateTypeCDK, nil
	}

	// Check for CloudFormation files in directory
	if l.hasCloudFormationFiles(path) {
		return ports.TemplateTypeCloudFormation, nil
	}

	return "", fmt.Errorf("could not determine template type for: %s", path)
}

// ListBuiltInTemplates returns available built-in templates
func (l *FilesystemTemplateLoader) ListBuiltInTemplates() []ports.TemplateInfo {
	return l.builtInTemplates
}

// ListRemoteTemplates is not supported for filesystem loader
func (l *FilesystemTemplateLoader) ListRemoteTemplates(category string) ([]ports.TemplateInfo, error) {
	return nil, fmt.Errorf("remote templates not supported by filesystem loader")
}

// GetTemplateCategories is not supported for filesystem loader
func (l *FilesystemTemplateLoader) GetTemplateCategories() ([]string, error) {
	return nil, fmt.Errorf("template categories not supported by filesystem loader")
}

// DownloadTemplate is not supported for filesystem loader
func (l *FilesystemTemplateLoader) DownloadTemplate(downloadURL string) (string, error) {
	return "", fmt.Errorf("download not supported by filesystem loader")
}

// loadBuiltInTemplate loads a built-in template
func (l *FilesystemTemplateLoader) loadBuiltInTemplate(path string) (string, error) {
	if path == "builtin://bootstrap" {
		// Return empty string - AnalyzeBootstrapOnly doesn't need template content
		return "", nil
	}
	return "", fmt.Errorf("unknown built-in template: %s", path)
}

// loadCloudFormationTemplate loads a CloudFormation template from file
func (l *FilesystemTemplateLoader) loadCloudFormationTemplate(path string, info os.FileInfo) (string, error) {
	if info.IsDir() {
		// Look for template files in directory
		files, err := os.ReadDir(path)
		if err != nil {
			return "", fmt.Errorf("failed to read directory: %w", err)
		}

		// Find first CloudFormation template
		for _, file := range files {
			if file.IsDir() {
				continue
			}
			name := file.Name()
			if strings.HasSuffix(name, ".json") || strings.HasSuffix(name, ".yaml") || strings.HasSuffix(name, ".yml") {
				templatePath := filepath.Join(path, name)
				return l.readFile(templatePath)
			}
		}

		return "", fmt.Errorf("no CloudFormation templates found in directory")
	}

	// Load single file
	return l.readFile(path)
}

// loadCDKTemplate synthesizes a CDK app and returns the CloudFormation template
func (l *FilesystemTemplateLoader) loadCDKTemplate(path string) (string, error) {
	// This will be handled by CDKSynthesizer adapter
	// For now, return the path - the caller will use CDKSynthesizer
	return path, nil
}

// readFile reads a file and returns its contents
func (l *FilesystemTemplateLoader) readFile(path string) (string, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return "", fmt.Errorf("failed to read file: %w", err)
	}
	return string(data), nil
}

// isCDKDirectory checks if a directory is a CDK app
func (l *FilesystemTemplateLoader) isCDKDirectory(path string) bool {
	// Check for cdk.json
	cdkJSON := filepath.Join(path, "cdk.json")
	if _, err := os.Stat(cdkJSON); err == nil {
		return true
	}

	// Check for package.json with CDK dependencies
	packageJSON := filepath.Join(path, "package.json")
	if _, err := os.Stat(packageJSON); err == nil {
		return true // Simplified check - could parse and verify CDK deps
	}

	return false
}

// hasCloudFormationFiles checks if a directory contains CloudFormation files
func (l *FilesystemTemplateLoader) hasCloudFormationFiles(path string) bool {
	files, err := os.ReadDir(path)
	if err != nil {
		return false
	}

	for _, file := range files {
		if file.IsDir() {
			continue
		}
		name := file.Name()
		if strings.HasSuffix(name, ".json") || strings.HasSuffix(name, ".yaml") || strings.HasSuffix(name, ".yml") {
			return true
		}
	}

	return false
}