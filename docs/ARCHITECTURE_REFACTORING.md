# Architecture Refactoring: Hexagonal Architecture Implementation

**Status**: In Progress
**Date**: 2025-10-21
**Version**: v0.6.x → v0.7.0

## Executive Summary

This document outlines the refactoring of the AWS Multi-Account Bootstrap project from an ad-hoc script architecture to **Hexagonal Architecture** (Ports & Adapters pattern). This refactoring will improve testability, maintainability, and enable future multi-cloud/multi-VCS support without requiring YAGNI violations.

## Motivation

### Current Problems
1. **Testing Requires AWS Credentials**: Tests must create actual AWS resources or skip validation
2. **Tight Coupling**: AWS CLI calls scattered throughout business logic
3. **Difficult to Add Providers**: Adding GitLab requires touching business logic
4. **Hard to Validate**: Can't test account creation logic without AWS Organizations access
5. **Tech Debt**: Backup files, demo files, and experimental code in production paths

### Benefits of Hexagonal Architecture
1. **Fast Testing**: Mock adapters run tests in <5s without AWS
2. **Multi-Provider Ready**: Add GitLab/Azure by implementing new adapters
3. **Clear Boundaries**: Business logic separated from infrastructure concerns
4. **Better Testability**: Test domain logic independently of AWS/GitHub
5. **Easier Maintenance**: Changes to AWS API don't affect business rules

## Codebase Analysis

### Current Structure
```
scripts/
├── setup-complete-project.sh      ← Orchestrator (mixed concerns)
├── create-project-accounts.sh     ← AWS Organizations (tightly coupled)
├── bootstrap-cdk.sh               ← AWS CDK (tightly coupled)
├── setup-github-cicd.sh           ← AWS IAM + GitHub (tightly coupled)
├── setup-github-repo.sh           ← GitHub API (tightly coupled)
├── setup-billing-alerts.sh        ← AWS Budgets/CloudWatch (tightly coupled)
└── lib/
    ├── config-manager.sh          ← Configuration (clean, keep as-is)
    ├── prerequisite-checker.sh    ← Prerequisites (clean, keep as-is)
    ├── ui-helpers.sh              ← UI presentation (clean, keep as-is)
    ├── cost-estimator.sh          ← Cost logic (domain logic candidate)
    └── [STALE FILES - see below]
```

### Identified Tech Debt
1. **`scripts/lib/prerequisite-checker-v1-backup.sh`** - Backup file (DELETE)
2. **`scripts/lib/ui-helpers-demo.sh`** - Demo file (DELETE)
3. **`scripts/browse-templates-v2.sh`** - Experimental feature (EVALUATE)
4. **Cost estimator duplication**:
   - `cost-estimator.sh` (main)
   - `cost-estimator-aws-cli.sh` (AWS CLI version)
   - `cost-estimator-public.sh` (public API version)
   - Need to consolidate or clarify purpose

### Dependencies
- **AWS CLI calls**: 5 scripts
- **GitHub CLI calls**: 4 scripts
- **Configuration system**: Already clean (mode detection, precedence)
- **Test suite**: 24 passing tests (validation-focused, no AWS calls)

## Target Architecture

### Hexagonal Architecture Structure

```
scripts/
├── setup-complete-project.sh              ← Orchestrator (wire adapters, call domain)
│
├── domain/                                ← CORE BUSINESS LOGIC (no AWS/GitHub)
│   ├── multi-account-setup.sh            ← Account creation orchestration
│   ├── cicd-configuration.sh             ← CI/CD setup orchestration
│   ├── cost-management.sh                ← Budget and alert rules
│   └── project-initialization.sh         ← Project structure creation
│
├── ports/                                 ← INTERFACES (contracts only)
│   ├── cloud-provider-port.sh            ← Cloud operations interface
│   ├── vcs-provider-port.sh              ← VCS operations interface
│   ├── notification-provider-port.sh     ← Email/SNS interface
│   └── cost-estimator-port.sh            ← Cost calculation interface
│
├── adapters/                              ← IMPLEMENTATIONS
│   ├── aws/
│   │   ├── aws-organizations-adapter.sh  ← Account creation
│   │   ├── aws-iam-adapter.sh            ← OIDC/roles
│   │   ├── aws-cdk-adapter.sh            ← CDK bootstrap
│   │   ├── aws-budgets-adapter.sh        ← Billing alerts
│   │   └── aws-pricing-adapter.sh        ← Cost estimation
│   ├── github/
│   │   ├── github-repo-adapter.sh        ← Repo creation
│   │   └── github-oidc-adapter.sh        ← OIDC configuration
│   └── mock/
│       ├── mock-cloud-adapter.sh         ← Fake cloud provider (testing)
│       ├── mock-vcs-adapter.sh           ← Fake VCS (testing)
│       └── mock-notification-adapter.sh  ← Fake notifications (testing)
│
└── lib/                                   ← SHARED UTILITIES (keep as-is)
    ├── config-manager.sh
    ├── prerequisite-checker.sh
    ├── ui-helpers.sh
    └── template-discovery.sh
```

### Dependency Flow

```
┌─────────────────────────────────────────────────────────────┐
│                     Orchestrator                            │
│             (setup-complete-project.sh)                     │
│                                                             │
│  • Loads configuration                                      │
│  • Wires adapters to ports                                  │
│  • Calls domain logic                                       │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   │ calls domain functions
                   ▼
┌─────────────────────────────────────────────────────────────┐
│                    Domain Layer                             │
│           (Pure Business Logic - No AWS/GitHub)             │
│                                                             │
│  • multi-account-setup.sh: "Create 3 accounts with naming"  │
│  • cicd-configuration.sh: "Setup deploy from develop→dev"   │
│  • cost-management.sh: "Enforce budget limits per env"      │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   │ calls through ports
                   ▼
┌─────────────────────────────────────────────────────────────┐
│                    Ports (Interfaces)                       │
│                                                             │
│  cloud_provider_create_account()                            │
│  cloud_provider_setup_oidc()                                │
│  vcs_provider_create_repo()                                 │
│  notification_send_alert()                                  │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   │ implemented by adapters
                   ▼
┌─────────────────────────────────────────────────────────────┐
│              Adapters (Implementations)                     │
│                                                             │
│  AWS Adapter:    aws organizations create-account           │
│  GitHub Adapter: gh repo create                             │
│  Mock Adapter:   echo "MOCK-ACCOUNT-123"                    │
└─────────────────────────────────────────────────────────────┘
```

## Refactoring Plan

### Phase 1: Create Ports (Interface Definitions)

**Objective**: Define contracts without changing existing code

**Tasks**:
1. Create `scripts/ports/` directory
2. Define cloud provider port:
   - `cloud_provider_create_account()`
   - `cloud_provider_setup_oidc()`
   - `cloud_provider_bootstrap_cdk()`
   - `cloud_provider_create_budget()`
   - `cloud_provider_create_alarm()`
3. Define VCS provider port:
   - `vcs_provider_create_repo()`
   - `vcs_provider_setup_oidc()`
   - `vcs_provider_add_secrets()`
   - `vcs_provider_setup_branch_protection()`
4. Define notification provider port:
   - `notification_create_topic()`
   - `notification_send_alert()`

**Success Criteria**: Port files exist with documented function signatures

**Files Created**:
- `scripts/ports/cloud-provider-port.sh`
- `scripts/ports/vcs-provider-port.sh`
- `scripts/ports/notification-provider-port.sh`

### Phase 2: Implement Mock Adapters

**Objective**: Enable testing without AWS/GitHub

**Tasks**:
1. Create `scripts/adapters/mock/` directory
2. Implement mock cloud provider:
   - Return fake account IDs
   - Simulate success/failure scenarios
   - Log operations to temp file for verification
3. Implement mock VCS provider:
   - Simulate repo creation
   - Log workflows created
4. Implement mock notification provider:
   - Log notification calls

**Success Criteria**: Tests run using mock adapters in <5 seconds

**Files Created**:
- `scripts/adapters/mock/mock-cloud-adapter.sh`
- `scripts/adapters/mock/mock-vcs-adapter.sh`
- `scripts/adapters/mock/mock-notification-adapter.sh`

### Phase 3: Implement AWS Adapters

**Objective**: Move existing AWS logic to adapters

**Tasks**:
1. Create `scripts/adapters/aws/` directory
2. Extract AWS Organizations logic from `create-project-accounts.sh`
3. Extract IAM/OIDC logic from `setup-github-cicd.sh`
4. Extract CDK logic from `bootstrap-cdk.sh`
5. Extract Budgets/CloudWatch logic from `setup-billing-alerts.sh`
6. Maintain 100% existing behavior

**Success Criteria**: All AWS operations work identically through adapters

**Files Created**:
- `scripts/adapters/aws/aws-organizations-adapter.sh`
- `scripts/adapters/aws/aws-iam-adapter.sh`
- `scripts/adapters/aws/aws-cdk-adapter.sh`
- `scripts/adapters/aws/aws-budgets-adapter.sh`

### Phase 4: Implement GitHub Adapters

**Objective**: Move existing GitHub logic to adapters

**Tasks**:
1. Create `scripts/adapters/github/` directory
2. Extract repo creation from `setup-github-repo.sh`
3. Extract branch protection from `setup-branch-protection.sh`
4. Extract OIDC configuration
5. Maintain 100% existing behavior

**Success Criteria**: All GitHub operations work identically through adapters

**Files Created**:
- `scripts/adapters/github/github-repo-adapter.sh`
- `scripts/adapters/github/github-oidc-adapter.sh`

### Phase 5: Extract Domain Logic

**Objective**: Separate business rules from infrastructure

**Tasks**:
1. Create `scripts/domain/` directory
2. Extract account naming rules (e.g., `${PROJECT_CODE}-${env}`)
3. Extract budget rules (dev: $15, staging: $25, prod: $100)
4. Extract CI/CD orchestration (which environments, deployment triggers)
5. Extract project structure generation
6. Ensure **zero** AWS/GitHub CLI calls in domain layer

**Success Criteria**: Domain logic has no infrastructure dependencies

**Files Created**:
- `scripts/domain/multi-account-setup.sh`
- `scripts/domain/cicd-configuration.sh`
- `scripts/domain/cost-management.sh`
- `scripts/domain/project-initialization.sh`

### Phase 6: Update Orchestrator

**Objective**: Wire adapters and call domain logic

**Tasks**:
1. Update `setup-complete-project.sh` to:
   - Load adapter configuration
   - Source appropriate adapters based on mode (test vs production)
   - Call domain functions instead of inline logic
2. Add adapter selection logic:
   ```bash
   if [ "$MODE" = "test" ]; then
       export CLOUD_ADAPTER="adapters/mock/mock-cloud-adapter.sh"
       export VCS_ADAPTER="adapters/mock/mock-vcs-adapter.sh"
   else
       export CLOUD_ADAPTER="adapters/aws/aws-organizations-adapter.sh"
       export VCS_ADAPTER="adapters/github/github-repo-adapter.sh"
   fi
   ```

**Success Criteria**: Orchestrator is thin, delegates to domain

### Phase 7: Update Tests

**Objective**: Tests use mock adapters

**Tasks**:
1. Update test scripts to:
   - Set `MODE=test` to trigger mock adapters
   - Verify domain logic through mock operation logs
   - Test validation without AWS credentials
2. Add new integration tests:
   - Test adapter contracts (ports)
   - Test domain logic in isolation
   - Test end-to-end with mocks

**Success Criteria**: All 24 tests pass with mock adapters, no AWS calls

### Phase 8: Remove Tech Debt

**Objective**: Clean up stale code

**Tasks**:
1. Delete `scripts/lib/prerequisite-checker-v1-backup.sh`
2. Delete `scripts/lib/ui-helpers-demo.sh`
3. Evaluate `scripts/browse-templates-v2.sh` (move to feature branch if incomplete)
4. Consolidate cost estimator files or document their distinct purposes
5. Remove old TODOs and commented-out code
6. Update shellcheck ignores if needed

**Success Criteria**: No backup/demo files in main branch

### Phase 9: Update Documentation

**Objective**: Document new architecture

**Tasks**:
1. Update `CLAUDE.md` with new architecture
2. Update `README.md` with testing instructions
3. Create `docs/ARCHITECTURE.md` with diagrams
4. Update `docs/CONTRIBUTING.md` with adapter guidelines
5. Add inline documentation to ports

**Success Criteria**: New contributors can understand architecture

### Phase 10: Validation

**Objective**: Ensure nothing broke

**Tasks**:
1. Run full test suite (should be faster now)
2. Manual test: Create project with real AWS/GitHub
3. Verify dry-run mode still works
4. Check CI mode works
5. Validate cost estimation still accurate

**Success Criteria**: All tests pass, manual validation successful

## Migration Strategy

### Backward Compatibility

During refactoring:
- Keep old scripts working until domain/adapters complete
- Use feature flags to enable new architecture
- Maintain existing CLI arguments and environment variables
- No breaking changes to user-facing behavior

### Rollout Plan

1. **v0.7.0-alpha.1**: Ports + Mock adapters (testing only)
2. **v0.7.0-alpha.2**: AWS adapters (parallel with old code)
3. **v0.7.0-alpha.3**: GitHub adapters (parallel with old code)
4. **v0.7.0-beta.1**: Domain logic + orchestrator update
5. **v0.7.0-rc.1**: Remove old code, tech debt cleanup
6. **v0.7.0**: Final release with documentation

### Rollback Plan

If refactoring fails:
- Revert to v0.6.x tag
- All existing scripts remain functional
- No data loss (accounts/repos created are real)

## Testing Strategy

### Unit Tests (New)

Test domain logic in isolation:
```bash
# Test account naming rules
test_account_naming() {
    local result=$(generate_account_name "TPA" "dev")
    assert_equals "TPA-dev" "$result"
}

# Test budget rules
test_budget_limits() {
    local result=$(get_budget_limit "dev")
    assert_equals "15" "$result"
}
```

### Integration Tests (Enhanced)

Test adapters implement ports correctly:
```bash
# Test mock adapter contract
test_mock_cloud_adapter() {
    source adapters/mock/mock-cloud-adapter.sh
    local account_id=$(cloud_provider_create_account "test" "test@example.com" "ou-test")
    assert_matches "^MOCK-" "$account_id"
}
```

### End-to-End Tests (Existing)

Maintain current test suite, but run with mocks:
```bash
MODE=test ./tests/test-config-simple.sh
```

### Manual Tests

Before release:
1. Create real project with AWS/GitHub
2. Verify all resources created correctly
3. Test cost estimation accuracy
4. Validate dry-run mode
5. Check CI mode in GitHub Actions

## Success Metrics

1. **Test Speed**: <5 seconds (currently requires manual AWS setup)
2. **Test Coverage**: 100% of domain logic (currently ~50% due to AWS coupling)
3. **Code Maintainability**: Clear separation of concerns
4. **Future-Proof**: Can add GitLab in 1-2 days (currently would take weeks)
5. **No Regressions**: All existing features work identically

## Timeline

- **Week 1**: Phases 1-2 (Ports + Mock adapters) - Low risk
- **Week 2**: Phases 3-4 (AWS + GitHub adapters) - Medium risk
- **Week 3**: Phases 5-6 (Domain + Orchestrator) - High risk
- **Week 4**: Phases 7-10 (Tests + Docs + Validation) - Low risk

**Total**: ~4 weeks for production-ready v0.7.0

## Risks & Mitigation

### Risk 1: Breaking Existing Functionality
**Mitigation**:
- Parallel implementation (old + new)
- Feature flags
- Extensive manual testing before removing old code

### Risk 2: Bash Limitations
**Mitigation**:
- Use nameref for complex data structures
- Document bash 4+ requirement
- Provide clear error messages for bash 3 users

### Risk 3: Over-Engineering
**Mitigation**:
- Follow YAGNI for GitLab (don't implement until needed)
- Keep it simple (bash functions, not OOP simulation)
- Focus on testability first, extensibility second

### Risk 4: Test Complexity
**Mitigation**:
- Start with simple mock adapters
- Validate early (Phase 2)
- Don't mock everything (config-manager stays as-is)

## Questions & Decisions

### Q: Should we refactor cost estimator files?
**Decision**: TBD - Need to understand why 3 versions exist. Document distinct purposes or consolidate.

### Q: What to do with browse-templates-v2.sh?
**Decision**: Evaluate if feature is complete. If experimental, move to feature branch. If production, integrate properly.

### Q: Should config-manager.sh use ports?
**Decision**: NO - Configuration loading is a utility, not an adapter concern. Keep as-is.

### Q: Should we create a GitLab adapter now?
**Decision**: NO - Follow YAGNI. Create ports/interfaces now, implement when GitLab support is requested.

## References

- Original architecture discussion: Medium article on Hexagonal/Clean/Onion architectures
- Project context: `CLAUDE.md`
- Test suite: `tests/test-config-simple.sh`
- Current version: v0.6.0 (per CLAUDE.md)

---

**Next Steps**: Begin Phase 1 (Create Ports)

**Approved By**: TBD
**Status**: Draft - In Review