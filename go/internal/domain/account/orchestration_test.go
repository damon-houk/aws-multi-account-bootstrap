package account

import (
	"context"
	"testing"

	"github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/adapters/mock"
)

// This test demonstrates Hexagonal Architecture for TESTING (not multi-cloud):
//
// 1. Domain logic (CreateAllAccounts) contains AWS account creation business rules
// 2. Port interface (AWSClient) defines the AWS operations contract
// 3. Mock adapter implements the contract for testing WITHOUT AWS credentials
// 4. Test runs INSTANTLY (no AWS API calls, no network)
//
// We're honest: This is for AWS, not generic cloud.
// But hexagonal architecture still provides huge value for testing!

func TestCreateAllAccounts(t *testing.T) {
	// Create mock AWS client (implements ports.AWSClient interface)
	mockAWS := mock.NewAWSClient()

	// Business configuration
	config := Config{
		ProjectCode: "TPA",
		EmailPrefix: "user",
		OUID:        "ou-813y-8teevv2l",
	}

	// Call domain logic
	// Domain logic doesn't know it's using a mock!
	// It only knows about the AWSClient interface.
	ctx := context.Background()
	accounts, err := CreateAllAccounts(ctx, mockAWS, config)

	// Verify results
	if err != nil {
		t.Fatalf("CreateAllAccounts() failed: %v", err)
	}

	// Should create 3 AWS accounts (dev, staging, prod)
	if len(accounts) != 3 {
		t.Errorf("Expected 3 accounts, got %d", len(accounts))
	}

	// Verify each AWS account has correct naming
	expectedAccounts := map[Environment]struct {
		name  string
		email string
	}{
		EnvironmentDev: {
			name:  "TPA_DEV",
			email: "user+tpa-dev@gmail.com",
		},
		EnvironmentStaging: {
			name:  "TPA_STAGING",
			email: "user+tpa-staging@gmail.com",
		},
		EnvironmentProd: {
			name:  "TPA_PROD",
			email: "user+tpa-prod@gmail.com",
		},
	}

	for _, account := range accounts {
		expected, exists := expectedAccounts[account.Environment]
		if !exists {
			t.Errorf("Unexpected environment: %s", account.Environment)
			continue
		}

		if account.Name != expected.name {
			t.Errorf("Account name for %s: got %s, want %s",
				account.Environment, account.Name, expected.name)
		}

		if account.Email != expected.email {
			t.Errorf("Account email for %s: got %s, want %s",
				account.Environment, account.Email, expected.email)
		}

		if account.AccountID == "" {
			t.Errorf("Account ID for %s is empty", account.Environment)
		}

		// Mock generates AWS-style 12-digit account IDs
		if len(account.AccountID) != 12 {
			t.Errorf("Account ID for %s should be 12 digits (AWS format): %s",
				account.Environment, account.AccountID)
		}
	}

	// BENEFIT OF HEXAGONAL: Verify AWS operations through mock
	// This proves the domain logic called the right AWS operations
	ops := mockAWS.GetOperations()

	if len(ops) == 0 {
		t.Error("No AWS operations were recorded by mock")
	}

	// Print operations for visibility
	t.Logf("Mock AWS client recorded %d operations:", len(ops))
	for _, op := range ops {
		t.Logf("  - %s", op)
	}
}

func TestCreateAllAccountsWithExistingAWSAccount(t *testing.T) {
	// Setup: Pre-create one AWS account in the mock
	mockAWS := mock.NewAWSClient()
	ctx := context.Background()

	// Pre-create dev AWS account
	devAccountID, err := mockAWS.CreateAccount(ctx, struct {
		Name      string
		Email     string
		OrgUnitID string
		RoleName  string
	}{
		Name:      "TPA_DEV",
		Email:     "user+tpa-dev@gmail.com",
		OrgUnitID: "ou-813y-8teevv2l",
		RoleName:  "OrganizationAccountAccessRole",
	})
	if err != nil {
		t.Fatalf("Failed to pre-create AWS account: %v", err)
	}

	// Now try to create all accounts (should reuse existing dev account)
	config := Config{
		ProjectCode: "TPA",
		EmailPrefix: "user",
		OUID:        "ou-813y-8teevv2l",
	}

	accounts, err := CreateAllAccounts(ctx, mockAWS, config)
	if err != nil {
		t.Fatalf("CreateAllAccounts() failed: %v", err)
	}

	// Should still return 3 accounts (reusing existing dev account)
	if len(accounts) != 3 {
		t.Errorf("Expected 3 accounts, got %d", len(accounts))
	}

	// Find dev account and verify it reused the existing ID
	for _, account := range accounts {
		if account.Environment == EnvironmentDev {
			if account.AccountID != devAccountID {
				t.Errorf("Dev account should reuse existing ID %s, got %s",
					devAccountID, account.AccountID)
			}
		}
	}
}

func TestCreateSingleAccount(t *testing.T) {
	mockAWS := mock.NewAWSClient()

	config := Config{
		ProjectCode: "TPA",
		EmailPrefix: "user",
		OUID:        "ou-813y-8teevv2l",
	}

	ctx := context.Background()
	account, err := CreateSingleAccount(ctx, mockAWS, config, EnvironmentDev)

	if err != nil {
		t.Fatalf("CreateSingleAccount() failed: %v", err)
	}

	// Verify AWS account details
	if account.Name != "TPA_DEV" {
		t.Errorf("Account name: got %s, want TPA_DEV", account.Name)
	}

	if account.Email != "user+tpa-dev@gmail.com" {
		t.Errorf("Account email: got %s, want user+tpa-dev@gmail.com", account.Email)
	}

	if account.Environment != EnvironmentDev {
		t.Errorf("Account environment: got %s, want %s", account.Environment, EnvironmentDev)
	}

	if account.AccountID == "" {
		t.Error("AWS Account ID is empty")
	}

	// Should be 12-digit AWS account ID
	if len(account.AccountID) != 12 {
		t.Errorf("AWS Account ID should be 12 digits: %s", account.AccountID)
	}
}

func TestCreateAllAccountsInvalidConfig(t *testing.T) {
	mockAWS := mock.NewAWSClient()

	// Invalid config (project code too short)
	config := Config{
		ProjectCode: "AB", // Invalid: must be 3 characters
		EmailPrefix: "user",
		OUID:        "ou-813y-8teevv2l",
	}

	ctx := context.Background()
	_, err := CreateAllAccounts(ctx, mockAWS, config)

	// Should fail validation
	if err == nil {
		t.Error("CreateAllAccounts() should have failed with invalid config")
	}

	// Error should mention validation
	if err != nil && !contains(err.Error(), "invalid configuration") {
		t.Errorf("Error should mention 'invalid configuration', got: %v", err)
	}
}

func TestCreateSingleAccountInvalidEnvironment(t *testing.T) {
	mockAWS := mock.NewAWSClient()

	config := Config{
		ProjectCode: "TPA",
		EmailPrefix: "user",
		OUID:        "ou-813y-8teevv2l",
	}

	ctx := context.Background()
	_, err := CreateSingleAccount(ctx, mockAWS, config, Environment("invalid"))

	// Should fail validation
	if err == nil {
		t.Error("CreateSingleAccount() should have failed with invalid environment")
	}
}

// Helper function
func contains(s, substr string) bool {
	return len(s) >= len(substr) && (s == substr || len(s) > len(substr) && (s[:len(substr)] == substr || s[len(s)-len(substr):] == substr || containsSubstring(s, substr)))
}

func containsSubstring(s, substr string) bool {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}

// Benchmark to ensure performance is good
func BenchmarkCreateAllAccounts(b *testing.B) {
	mockAWS := mock.NewAWSClient()
	config := Config{
		ProjectCode: "TPA",
		EmailPrefix: "user",
		OUID:        "ou-813y-8teevv2l",
	}
	ctx := context.Background()

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_, _ = CreateAllAccounts(ctx, mockAWS, config)
	}
}
