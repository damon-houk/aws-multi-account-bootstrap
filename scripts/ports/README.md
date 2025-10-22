# Ports (Interfaces)

This directory contains **port** definitions for the Hexagonal Architecture implementation.

## What is a Port?

A **port** is an interface that defines a contract for external interactions. Ports specify:
- Function signatures (name, parameters, return values)
- Expected behavior (documented in comments)
- No implementation details

Think of ports as "promises" that adapters must fulfill.

## Available Ports

### `cloud-provider-port.sh`
Defines operations for cloud providers (AWS, Azure, GCP, etc.):
- Account management (create, wait, get)
- IAM & authentication (OIDC, roles)
- Infrastructure bootstrapping (CDK)
- Cost management (budgets, alarms)
- Notifications (SNS/equivalent)

**Adapters**:
- `adapters/aws/` - AWS implementations
- `adapters/mock/mock-cloud-adapter.sh` - Testing mock

### `vcs-provider-port.sh`
Defines operations for version control systems (GitHub, GitLab, etc.):
- Repository management (create, delete, exists)
- Branch protection
- Secrets & variables
- Environments
- Workflows & CI/CD
- OIDC setup
- Git operations
- Releases & tags

**Adapters**:
- `adapters/github/` - GitHub implementations
- `adapters/mock/mock-vcs-adapter.sh` - Testing mock
- `adapters/gitlab/` - (Future) GitLab implementations

## How to Use Ports

### In Your Scripts

```bash
#!/bin/bash

# 1. Source the port (interface definition)
source scripts/ports/cloud-provider-port.sh

# 2. Source an adapter (implementation)
#    - Production: Use real adapter
#    - Testing: Use mock adapter
if [ "$MODE" = "test" ]; then
    source scripts/adapters/mock/mock-cloud-adapter.sh
else
    source scripts/adapters/aws/aws-organizations-adapter.sh
fi

# 3. Call port functions
account_id=$(cloud_provider_create_account "MyAccount" "email@example.com" "ou-123")
echo "Created account: $account_id"
```

### Creating a New Adapter

To implement a port, create a new adapter file:

```bash
#!/bin/bash

# Source the port to get function signatures
source scripts/ports/cloud-provider-port.sh

# Implement each function
cloud_provider_create_account() {
    local account_name=$1
    local email=$2
    local org_unit_id=$3

    # Your implementation here
    # For AWS: aws organizations create-account ...
    # For Azure: az account create ...
    # For Mock: echo "MOCK-ACCOUNT-123"
}

# Implement all other port functions...

# Override the provider name
cloud_provider_name() {
    echo "YourProviderName"
}
```

## Design Principles

### 1. Interface Segregation
Each port focuses on one concern:
- `cloud-provider-port.sh` - Cloud operations
- `vcs-provider-port.sh` - Version control operations

Don't mix concerns in a single port.

### 2. Adapter Independence
Ports should not assume implementation details:
- ❌ Don't reference AWS-specific concepts (unless it's the AWS adapter)
- ✅ Use generic terms (account, role, budget)
- ✅ Document cloud-specific examples in comments

### 3. Error Handling
All port functions should:
- Return 0 on success, non-zero on failure
- Write errors to stderr
- Output results to stdout

Example:
```bash
cloud_provider_create_account() {
    if [ -z "$1" ]; then
        echo "ERROR: account_name required" >&2
        return 1
    fi

    # Implementation...
    echo "$account_id"  # stdout
    return 0
}
```

### 4. Documentation
Every port function must have:
- Description of what it does
- Parameter documentation (`$1 - name: Description`)
- Return value documentation
- Example usage

## Validation

Each port provides a validation function:

```bash
source scripts/ports/cloud-provider-port.sh
source scripts/adapters/aws/aws-organizations-adapter.sh

if cloud_provider_validate_port; then
    echo "All functions implemented correctly"
else
    echo "Missing implementations"
fi
```

## Testing

Ports enable easy testing through mock adapters:

```bash
# tests/test-account-creation.sh
source scripts/ports/cloud-provider-port.sh
source scripts/adapters/mock/mock-cloud-adapter.sh

# Test domain logic without AWS
account_id=$(cloud_provider_create_account "Test" "test@example.com" "ou-test")

if [[ $account_id == MOCK-* ]]; then
    echo "✓ Test passed"
else
    echo "✗ Test failed"
fi
```

## Benefits

1. **Testability**: Swap real adapters with mocks for fast, isolated tests
2. **Flexibility**: Add new cloud providers without changing business logic
3. **Clarity**: Interface clearly documents what each adapter must provide
4. **Type Safety** (in bash): Function signatures document expected parameters

## Migration from Old Code

Old code (tightly coupled):
```bash
# Direct AWS call in business logic
aws organizations create-account \
    --account-name "MyAccount" \
    --email "email@example.com"
```

New code (using ports):
```bash
# Business logic calls port
account_id=$(cloud_provider_create_account "MyAccount" "email@example.com" "ou-123")

# Adapter implements port (in separate file)
cloud_provider_create_account() {
    aws organizations create-account \
        --account-name "$1" \
        --email "$2" \
        # ...
}
```

## See Also

- `docs/ARCHITECTURE_REFACTORING.md` - Full refactoring plan
- `scripts/adapters/` - Port implementations
- `scripts/domain/` - Business logic using ports