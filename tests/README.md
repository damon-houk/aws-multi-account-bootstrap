# Tests

This directory contains tests for the AWS Multi-Account Bootstrap tool.

## Test Structure

```
tests/
├── unit/           # Unit tests for individual functions/scripts
├── integration/    # Integration tests for complete workflows
└── fixtures/       # Test fixtures and mock data
```

## Running Tests

```bash
# Run all tests
npm test

# Run tests in watch mode
npm run test:watch

# Run tests with coverage
npm run test:coverage
```

## Writing Tests

### Unit Tests

Test individual script functions in isolation. Mock external dependencies (AWS CLI, GitHub CLI).

Example:
```javascript
describe('create-project-accounts', () => {
  it('should validate PROJECT_CODE is 3 characters', () => {
    // Test implementation
  });
});
```

### Integration Tests

Test complete workflows with real or mock AWS/GitHub APIs.

**Note:** Integration tests may incur AWS costs. Use with caution.

```bash
# Run integration tests (requires AWS credentials)
npm run test:integration
```

## Test Environment Variables

Create a `.env.test` file (not committed) with:

```
AWS_PROFILE=test-profile
GITHUB_TOKEN=ghp_xxx
TEST_OU_ID=ou-xxxx-xxxxxxxx
TEST_EMAIL_PREFIX=test
TEST_PROJECT_CODE=TST
```

## CI/CD Testing

GitHub Actions runs tests automatically on:
- Pull requests
- Pushes to main/develop branches

See `.github/workflows/ci.yml` for configuration.