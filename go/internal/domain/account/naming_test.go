package account

import (
	"strings"
	"testing"
)

// Test domain logic WITHOUT any infrastructure dependencies.
// These tests run instantly - no AWS, no GitHub, no mocks needed!

func TestGenerateAccountName(t *testing.T) {
	tests := []struct {
		name        string
		projectCode string
		env         Environment
		want        string
	}{
		{
			name:        "dev environment",
			projectCode: "TPA",
			env:         EnvironmentDev,
			want:        "TPA_DEV",
		},
		{
			name:        "staging environment",
			projectCode: "TPA",
			env:         EnvironmentStaging,
			want:        "TPA_STAGING",
		},
		{
			name:        "prod environment",
			projectCode: "TPA",
			env:         EnvironmentProd,
			want:        "TPA_PROD",
		},
		{
			name:        "lowercase project code gets uppercased in env",
			projectCode: "ABC",
			env:         EnvironmentDev,
			want:        "ABC_DEV",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := GenerateAccountName(tt.projectCode, tt.env)
			if got != tt.want {
				t.Errorf("GenerateAccountName() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestGenerateAccountEmail(t *testing.T) {
	tests := []struct {
		name        string
		emailPrefix string
		projectCode string
		env         Environment
		want        string
	}{
		{
			name:        "standard email without @gmail.com",
			emailPrefix: "user",
			projectCode: "TPA",
			env:         EnvironmentDev,
			want:        "user+tpa-dev@gmail.com",
		},
		{
			name:        "email with @gmail.com gets stripped",
			emailPrefix: "user@gmail.com",
			projectCode: "TPA",
			env:         EnvironmentDev,
			want:        "user+tpa-dev@gmail.com",
		},
		{
			name:        "uppercase project code gets lowercased",
			emailPrefix: "user",
			projectCode: "ABC",
			env:         EnvironmentStaging,
			want:        "user+abc-staging@gmail.com",
		},
		{
			name:        "dot notation email",
			emailPrefix: "first.last",
			projectCode: "XYZ",
			env:         EnvironmentProd,
			want:        "first.last+xyz-prod@gmail.com",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := GenerateAccountEmail(tt.emailPrefix, tt.projectCode, tt.env)
			if got != tt.want {
				t.Errorf("GenerateAccountEmail() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestValidateProjectCode(t *testing.T) {
	tests := []struct {
		name        string
		projectCode string
		wantErr     bool
		errContains string
	}{
		{
			name:        "valid 3-letter uppercase",
			projectCode: "TPA",
			wantErr:     false,
		},
		{
			name:        "valid 3-char alphanumeric",
			projectCode: "XY1",
			wantErr:     false,
		},
		{
			name:        "too short",
			projectCode: "AB",
			wantErr:     true,
			errContains: "exactly 3 characters",
		},
		{
			name:        "too long",
			projectCode: "ABCD",
			wantErr:     true,
			errContains: "exactly 3 characters",
		},
		{
			name:        "lowercase letters",
			projectCode: "abc",
			wantErr:     true,
			errContains: "uppercase",
		},
		{
			name:        "special characters",
			projectCode: "AB-",
			wantErr:     true,
			errContains: "uppercase",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := ValidateProjectCode(tt.projectCode)
			if (err != nil) != tt.wantErr {
				t.Errorf("ValidateProjectCode() error = %v, wantErr %v", err, tt.wantErr)
				return
			}
			if tt.wantErr && !strings.Contains(err.Error(), tt.errContains) {
				t.Errorf("ValidateProjectCode() error = %v, should contain %v", err, tt.errContains)
			}
		})
	}
}

func TestValidateEmailPrefix(t *testing.T) {
	tests := []struct {
		name    string
		email   string
		wantErr bool
	}{
		{
			name:    "simple email prefix",
			email:   "user",
			wantErr: false,
		},
		{
			name:    "email with @gmail.com",
			email:   "user@gmail.com",
			wantErr: false,
		},
		{
			name:    "email with dots",
			email:   "first.last",
			wantErr: false,
		},
		{
			name:    "email with numbers",
			email:   "user123",
			wantErr: false,
		},
		{
			name:    "email with plus and dash",
			email:   "user+test-123",
			wantErr: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := ValidateEmailPrefix(tt.email)
			if (err != nil) != tt.wantErr {
				t.Errorf("ValidateEmailPrefix() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}

func TestValidateOUID(t *testing.T) {
	tests := []struct {
		name        string
		ouID        string
		wantErr     bool
		errContains string
	}{
		{
			name:    "valid OU ID",
			ouID:    "ou-813y-8teevv2l",
			wantErr: false,
		},
		{
			name:    "valid OU ID with different format",
			ouID:    "ou-abcd-12345678",
			wantErr: false,
		},
		{
			name:        "missing ou- prefix",
			ouID:        "813y-8teevv2l",
			wantErr:     true,
			errContains: "must start with 'ou-'",
		},
		{
			name:        "invalid format",
			ouID:        "ou-invalid",
			wantErr:     true,
			errContains: "invalid format",
		},
		{
			name:        "uppercase in OU ID",
			ouID:        "ou-ABCD-12345678",
			wantErr:     true,
			errContains: "invalid format",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := ValidateOUID(tt.ouID)
			if (err != nil) != tt.wantErr {
				t.Errorf("ValidateOUID() error = %v, wantErr %v", err, tt.wantErr)
				return
			}
			if tt.wantErr && !strings.Contains(err.Error(), tt.errContains) {
				t.Errorf("ValidateOUID() error = %v, should contain %v", err, tt.errContains)
			}
		})
	}
}

func TestConfigValidate(t *testing.T) {
	tests := []struct {
		name    string
		config  Config
		wantErr bool
	}{
		{
			name: "valid config",
			config: Config{
				ProjectCode: "TPA",
				EmailPrefix: "user",
				OUID:        "ou-813y-8teevv2l",
			},
			wantErr: false,
		},
		{
			name: "invalid project code",
			config: Config{
				ProjectCode: "AB",
				EmailPrefix: "user",
				OUID:        "ou-813y-8teevv2l",
			},
			wantErr: true,
		},
		{
			name: "invalid OU ID",
			config: Config{
				ProjectCode: "TPA",
				EmailPrefix: "user",
				OUID:        "invalid",
			},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.config.Validate()
			if (err != nil) != tt.wantErr {
				t.Errorf("Config.Validate() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}

func TestGenerateSummary(t *testing.T) {
	config := Config{
		ProjectCode: "TPA",
		EmailPrefix: "user",
		OUID:        "ou-813y-8teevv2l",
	}

	summary := GenerateSummary(config)

	// Check that summary contains expected elements
	expectedStrings := []string{
		"TPA",
		"user",
		"ou-813y-8teevv2l",
		"TPA_DEV",
		"TPA_STAGING",
		"TPA_PROD",
		"user+tpa-dev@gmail.com",
		"user+tpa-staging@gmail.com",
		"user+tpa-prod@gmail.com",
	}

	for _, expected := range expectedStrings {
		if !strings.Contains(summary, expected) {
			t.Errorf("GenerateSummary() missing expected string: %s", expected)
		}
	}
}

func TestAllEnvironments(t *testing.T) {
	envs := AllEnvironments()

	if len(envs) != 3 {
		t.Errorf("AllEnvironments() returned %d environments, want 3", len(envs))
	}

	expected := []Environment{EnvironmentDev, EnvironmentStaging, EnvironmentProd}
	for i, env := range envs {
		if env != expected[i] {
			t.Errorf("AllEnvironments()[%d] = %v, want %v", i, env, expected[i])
		}
	}
}

func TestGetOrganizationAccessRoleName(t *testing.T) {
	roleName := GetOrganizationAccessRoleName()
	expected := "OrganizationAccountAccessRole"

	if roleName != expected {
		t.Errorf("GetOrganizationAccessRoleName() = %v, want %v", roleName, expected)
	}
}

// Benchmark tests to ensure performance is good
func BenchmarkGenerateAccountName(b *testing.B) {
	for i := 0; i < b.N; i++ {
		GenerateAccountName("TPA", EnvironmentDev)
	}
}

func BenchmarkGenerateAccountEmail(b *testing.B) {
	for i := 0; i < b.N; i++ {
		GenerateAccountEmail("user", "TPA", EnvironmentDev)
	}
}

func BenchmarkValidateProjectCode(b *testing.B) {
	for i := 0; i < b.N; i++ {
		ValidateProjectCode("TPA")
	}
}
