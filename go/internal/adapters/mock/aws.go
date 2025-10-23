package mock

import (
	"context"
	"fmt"
	"sync"
	"time"

	"github.com/damon-houk/aws-multi-account-bootstrap/v2/internal/ports"
)

// AWSClient is a mock implementation of ports.AWSClient for testing.
//
// This adapter implements the AWSClient interface but doesn't actually
// make any AWS API calls. Instead, it:
//   - Records all operations in an internal log
//   - Simulates AWS account creation with fake IDs
//   - Returns success for all operations
//   - Provides deterministic, fast behavior
//
// Usage:
//
//	mockAWS := mock.NewAWSClient()
//	accountID, err := mockAWS.CreateAccount(ctx, ports.AWSCreateAccountRequest{
//	    Name:  "TPA-dev",
//	    Email: "user+tpa-dev@gmail.com",
//	    OrgUnitID: "ou-test-12345678",
//	})
//	// accountID will be "123456789012" (fake 12-digit AWS account ID)
//
// This enables:
//   - Fast tests (no network calls, <1ms)
//   - Deterministic behavior (same inputs = same outputs)
//   - Testing without AWS credentials
//   - Verifying business logic without AWS Organizations access
type AWSClient struct {
	mu             sync.Mutex
	accounts       map[string]*mockAWSAccount
	accountsByName map[string]string
	operations     []string
	nextAccountID  int64
}

type mockAWSAccount struct {
	ID        string
	Name      string
	Email     string
	OrgUnitID string
	CreatedAt time.Time
}

// NewAWSClient creates a new mock AWS client.
func NewAWSClient() *AWSClient {
	return &AWSClient{
		accounts:       make(map[string]*mockAWSAccount),
		accountsByName: make(map[string]string),
		operations:     make([]string, 0),
		nextAccountID:  100000000001, // Start with realistic 12-digit AWS account IDs
	}
}

// Name returns "Mock AWS" for logging/debugging.
func (m *AWSClient) Name() string {
	return "Mock AWS"
}

// logOperation records an operation for testing/debugging.
// This acquires the lock - use logOperationLocked when already holding the lock.
func (m *AWSClient) logOperation(op string) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.operations = append(m.operations, op)
}

// logOperationLocked records an operation without acquiring the lock.
// MUST only be called when m.mu is already held.
func (m *AWSClient) logOperationLocked(op string) {
	m.operations = append(m.operations, op)
}

// GetOperations returns all operations that have been performed.
// Useful for testing - verify that the right AWS operations happened.
func (m *AWSClient) GetOperations() []string {
	m.mu.Lock()
	defer m.mu.Unlock()
	ops := make([]string, len(m.operations))
	copy(ops, m.operations)
	return ops
}

// CreateAccount simulates creating an AWS account in AWS Organizations.
func (m *AWSClient) CreateAccount(ctx context.Context, req ports.AWSCreateAccountRequest) (string, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	// Check if AWS account already exists
	if existingID, exists := m.accountsByName[req.Name]; exists {
		m.logOperationLocked(fmt.Sprintf("CreateAccount(%s) - already exists: %s", req.Name, existingID))
		return existingID, nil
	}

	// Generate mock AWS account ID (12 digits, like real AWS)
	accountID := fmt.Sprintf("%012d", m.nextAccountID)
	m.nextAccountID++

	// Store account
	account := &mockAWSAccount{
		ID:        accountID,
		Name:      req.Name,
		Email:     req.Email,
		OrgUnitID: req.OrgUnitID,
		CreatedAt: time.Now(),
	}
	m.accounts[accountID] = account
	m.accountsByName[req.Name] = accountID

	m.logOperationLocked(fmt.Sprintf("CreateAccount(%s, %s, %s) -> %s", req.Name, req.Email, req.OrgUnitID, accountID))

	return accountID, nil
}

// WaitForAccountCreation simulates waiting for AWS account creation (instant for mock).
//
// Real AWS Organizations creates accounts asynchronously. Mock is instant.
func (m *AWSClient) WaitForAccountCreation(ctx context.Context, accountID string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if _, exists := m.accounts[accountID]; !exists {
		return fmt.Errorf("AWS account %s not found", accountID)
	}

	m.logOperationLocked(fmt.Sprintf("WaitForAccountCreation(%s) -> ready", accountID))
	return nil
}

// GetAccountByName retrieves an AWS account ID by name.
func (m *AWSClient) GetAccountByName(ctx context.Context, name string) (string, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	if accountID, exists := m.accountsByName[name]; exists {
		m.logOperationLocked(fmt.Sprintf("GetAccountByName(%s) -> %s", name, accountID))
		return accountID, nil
	}

	m.logOperationLocked(fmt.Sprintf("GetAccountByName(%s) -> not found", name))
	return "", nil
}

// CreateOIDCProviderForGitHub simulates creating AWS IAM OIDC provider for GitHub Actions.
func (m *AWSClient) CreateOIDCProviderForGitHub(ctx context.Context, accountID string) error {
	m.logOperation(fmt.Sprintf("CreateOIDCProviderForGitHub(%s)", accountID))
	return nil
}

// CreateGitHubActionsRole simulates creating an AWS IAM role for GitHub Actions.
func (m *AWSClient) CreateGitHubActionsRole(ctx context.Context, req ports.AWSCreateRoleRequest) (string, error) {
	roleARN := fmt.Sprintf("arn:aws:iam::%s:role/%s", req.AccountID, req.RoleName)
	m.logOperation(fmt.Sprintf("CreateGitHubActionsRole(%s, %s/%s) -> %s",
		req.AccountID, req.GitHubOrg, req.GitHubRepo, roleARN))
	return roleARN, nil
}

// BootstrapCDK simulates AWS CDK bootstrap.
func (m *AWSClient) BootstrapCDK(ctx context.Context, accountID, region, trustAccountID string) error {
	m.logOperation(fmt.Sprintf("BootstrapCDK(%s, %s, trust=%s)", accountID, region, trustAccountID))
	return nil
}

// CreateBudget simulates creating an AWS Budget.
func (m *AWSClient) CreateBudget(ctx context.Context, req ports.AWSCreateBudgetRequest) error {
	m.logOperation(fmt.Sprintf("CreateBudget(%s, %s, limit=$%.2f, alert=$%.2f)",
		req.AccountID, req.BudgetName, req.LimitAmount, req.AlertAmount))
	return nil
}

// CreateBillingAlarm simulates creating an AWS CloudWatch billing alarm.
func (m *AWSClient) CreateBillingAlarm(ctx context.Context, req ports.AWSCreateBillingAlarmRequest) error {
	m.logOperation(fmt.Sprintf("CreateBillingAlarm(%s, %s, threshold=$%.2f)",
		req.AccountID, req.AlarmName, req.Threshold))
	return nil
}

// CreateSNSTopic simulates creating an AWS SNS topic.
func (m *AWSClient) CreateSNSTopic(ctx context.Context, accountID, topicName string) (string, error) {
	topicARN := fmt.Sprintf("arn:aws:sns:us-east-1:%s:%s", accountID, topicName)
	m.logOperation(fmt.Sprintf("CreateSNSTopic(%s, %s) -> %s", accountID, topicName, topicARN))
	return topicARN, nil
}

// SubscribeEmailToSNSTopic simulates subscribing an email to an AWS SNS topic.
func (m *AWSClient) SubscribeEmailToSNSTopic(ctx context.Context, topicARN, email string) error {
	m.logOperation(fmt.Sprintf("SubscribeEmailToSNSTopic(%s, %s)", topicARN, email))
	return nil
}

// AssumeRole simulates AWS STS AssumeRole.
func (m *AWSClient) AssumeRole(ctx context.Context, roleARN, sessionName string) (*ports.AWSCredentials, error) {
	m.logOperation(fmt.Sprintf("AssumeRole(%s, %s)", roleARN, sessionName))
	return &ports.AWSCredentials{
		AccessKeyID:     "ASIAMOCKEXAMPLEKEY123",
		SecretAccessKey: "MockSecretAccessKey123456789012345678901234",
		SessionToken:    "MockSessionToken" + sessionName,
		Expiration:      time.Now().Add(time.Hour),
	}, nil
}

// GetCallerIdentity simulates AWS STS GetCallerIdentity.
func (m *AWSClient) GetCallerIdentity(ctx context.Context) (*ports.AWSCallerIdentity, error) {
	m.logOperation("GetCallerIdentity()")
	return &ports.AWSCallerIdentity{
		AccountID: "999999999999",
		UserID:    "AIDAMOCKUSERID",
		ARN:       "arn:aws:iam::999999999999:user/mock-user",
	}, nil
}
