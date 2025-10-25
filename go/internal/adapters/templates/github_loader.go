package templates

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/ports"
)

const (
	// cloudonaut/widdix - production-ready CloudFormation templates
	CloudonautRepo = "widdix/aws-cf-templates"
	CloudonautAPI  = "https://api.github.com/repos/widdix/aws-cf-templates/contents"

	// Cache configuration
	cacheDir = ".aws-bootstrap/template-cache"
	cacheTTL = 24 * time.Hour
)

// GitHubTemplateLoader loads templates from GitHub repositories
// Adapter: Implements TemplateLoader port for remote GitHub templates
type GitHubTemplateLoader struct {
	httpClient *http.Client
	cacheDir   string
}

// NewGitHubTemplateLoader creates a new GitHub template loader
func NewGitHubTemplateLoader() (*GitHubTemplateLoader, error) {
	// Setup cache directory
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return nil, fmt.Errorf("failed to get home directory: %w", err)
	}

	cachePath := filepath.Join(homeDir, cacheDir, "metadata")
	if err := os.MkdirAll(cachePath, 0755); err != nil {
		return nil, fmt.Errorf("failed to create cache directory: %w", err)
	}

	return &GitHubTemplateLoader{
		httpClient: &http.Client{Timeout: 10 * time.Second},
		cacheDir:   cachePath,
	}, nil
}

// GitHubContent represents a GitHub API content response
type GitHubContent struct {
	Name        string `json:"name"`
	Path        string `json:"path"`
	Type        string `json:"type"` // "file" or "dir"
	HTMLURL     string `json:"html_url"`
	DownloadURL string `json:"download_url"`
}

// LoadTemplate loads a template from a path (not supported for remote)
func (l *GitHubTemplateLoader) LoadTemplate(path string) (string, error) {
	return "", fmt.Errorf("LoadTemplate not supported for GitHub loader, use DownloadTemplate")
}

// GetTemplateType returns the type of template
func (l *GitHubTemplateLoader) GetTemplateType(path string) (ports.TemplateType, error) {
	return ports.TemplateTypeCloudFormation, nil
}

// ListBuiltInTemplates returns built-in templates
func (l *GitHubTemplateLoader) ListBuiltInTemplates() []ports.TemplateInfo {
	return []ports.TemplateInfo{
		{
			Name:        "Bootstrap (Default)",
			Path:        "builtin://bootstrap",
			Type:        ports.TemplateTypeBootstrap,
			Description: "Minimal bootstrap infrastructure (CloudWatch alarms + SNS notifications)",
			IsBuiltIn:   true,
			Category:    "bootstrap",
			Source:      "builtin",
		},
	}
}

// ListRemoteTemplates fetches templates from cloudonaut/widdix
func (l *GitHubTemplateLoader) ListRemoteTemplates(category string) ([]ports.TemplateInfo, error) {
	// Check cache first
	cacheFile := filepath.Join(l.cacheDir, "cloudonaut-templates.json")
	if templates, ok := l.loadFromCache(cacheFile); ok {
		return l.filterByCategory(templates, category), nil
	}

	// Fetch from GitHub API
	templates, err := l.fetchCloudonautTemplates()
	if err != nil {
		return nil, err
	}

	// Save to cache
	if err := l.saveToCache(cacheFile, templates); err != nil {
		// Log error but continue - cache is not critical
		fmt.Fprintf(os.Stderr, "Warning: Failed to save to cache: %v\n", err)
	}

	return l.filterByCategory(templates, category), nil
}

// GetTemplateCategories returns all available categories
func (l *GitHubTemplateLoader) GetTemplateCategories() ([]string, error) {
	templates, err := l.ListRemoteTemplates("all")
	if err != nil {
		return nil, err
	}

	// Extract unique categories
	categoryMap := make(map[string]bool)
	for _, t := range templates {
		if t.Category != "" {
			categoryMap[t.Category] = true
		}
	}

	categories := make([]string, 0, len(categoryMap))
	for cat := range categoryMap {
		categories = append(categories, cat)
	}

	return categories, nil
}

// DownloadTemplate downloads a remote template by URL
func (l *GitHubTemplateLoader) DownloadTemplate(downloadURL string) (string, error) {
	req, err := http.NewRequest("GET", downloadURL, nil)
	if err != nil {
		return "", fmt.Errorf("failed to create request: %w", err)
	}

	resp, err := l.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("failed to download template: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("failed to download template: HTTP %d", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("failed to read template: %w", err)
	}

	return string(body), nil
}

// fetchCloudonautTemplates fetches all templates from cloudonaut/widdix
func (l *GitHubTemplateLoader) fetchCloudonautTemplates() ([]ports.TemplateInfo, error) {
	// First, get all directories (each represents a category)
	req, err := http.NewRequest("GET", CloudonautAPI, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	resp, err := l.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch directories: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("GitHub API returned HTTP %d", resp.StatusCode)
	}

	var contents []GitHubContent
	if err := json.NewDecoder(resp.Body).Decode(&contents); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	// Fetch templates from each directory
	var allTemplates []ports.TemplateInfo
	for _, item := range contents {
		if item.Type != "dir" {
			continue
		}

		// Fetch templates from this directory
		dirTemplates, err := l.fetchTemplatesFromDirectory(item.Name)
		if err != nil {
			// Log error but continue with other directories
			fmt.Fprintf(os.Stderr, "Warning: Failed to fetch templates from %s: %v\n", item.Name, err)
			continue
		}

		allTemplates = append(allTemplates, dirTemplates...)
	}

	return allTemplates, nil
}

// fetchTemplatesFromDirectory fetches templates from a specific directory
func (l *GitHubTemplateLoader) fetchTemplatesFromDirectory(dir string) ([]ports.TemplateInfo, error) {
	url := fmt.Sprintf("%s/%s", CloudonautAPI, dir)

	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil, err
	}

	resp, err := l.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("HTTP %d", resp.StatusCode)
	}

	var contents []GitHubContent
	if err := json.NewDecoder(resp.Body).Decode(&contents); err != nil {
		return nil, err
	}

	var templates []ports.TemplateInfo
	for _, item := range contents {
		if item.Type != "file" {
			continue
		}

		// Only include YAML/JSON CloudFormation templates
		if !strings.HasSuffix(item.Name, ".yaml") &&
			!strings.HasSuffix(item.Name, ".yml") &&
			!strings.HasSuffix(item.Name, ".json") {
			continue
		}

		templates = append(templates, ports.TemplateInfo{
			Name:        item.Name,
			Path:        item.Path,
			Type:        ports.TemplateTypeCloudFormation,
			Description: fmt.Sprintf("Production-ready %s template: %s", dir, item.Name),
			IsBuiltIn:   false,
			Category:    dir,
			Source:      "cloudonaut",
			Author:      "cloudonaut/widdix",
			URL:         item.HTMLURL,
			DownloadURL: item.DownloadURL,
			Repository:  CloudonautRepo,
		})
	}

	return templates, nil
}

// loadFromCache loads templates from cache if valid
func (l *GitHubTemplateLoader) loadFromCache(cacheFile string) ([]ports.TemplateInfo, bool) {
	// Check if cache exists
	info, err := os.Stat(cacheFile)
	if err != nil {
		return nil, false
	}

	// Check if cache is still valid
	if time.Since(info.ModTime()) > cacheTTL {
		return nil, false
	}

	// Read cache
	data, err := os.ReadFile(cacheFile)
	if err != nil {
		return nil, false
	}

	var templates []ports.TemplateInfo
	if err := json.Unmarshal(data, &templates); err != nil {
		return nil, false
	}

	return templates, true
}

// saveToCache saves templates to cache
func (l *GitHubTemplateLoader) saveToCache(cacheFile string, templates []ports.TemplateInfo) error {
	data, err := json.MarshalIndent(templates, "", "  ")
	if err != nil {
		return err
	}

	return os.WriteFile(cacheFile, data, 0644)
}

// filterByCategory filters templates by category
func (l *GitHubTemplateLoader) filterByCategory(templates []ports.TemplateInfo, category string) []ports.TemplateInfo {
	if category == "" || category == "all" {
		return templates
	}

	var filtered []ports.TemplateInfo
	for _, t := range templates {
		if t.Category == category {
			filtered = append(filtered, t)
		}
	}

	return filtered
}