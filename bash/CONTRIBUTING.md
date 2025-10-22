# Contributing to AWS Multi-Account Bootstrap

Thank you for your interest in contributing! This document provides guidelines and instructions for contributing to this project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Process](#development-process)
- [Commit Messages](#commit-messages)
- [Pull Request Process](#pull-request-process)
- [Testing](#testing)
- [Documentation](#documentation)

## Code of Conduct

This project follows the [Contributor Covenant Code of Conduct](https://www.contributor-covenant.org/). By participating, you are expected to uphold this code.

## Getting Started

### Prerequisites

- AWS account with Organizations enabled
- AWS CLI configured
- AWS CDK installed (`npm install -g aws-cdk`)
- GitHub CLI (`gh`) installed
- Node.js 20+
- jq, git

### Setup Development Environment

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/damon-houk/aws-multi-account-bootstrap.git
   cd aws-multi-account-bootstrap
   ```

3. Install dependencies:
   ```bash
   npm install
   ```

4. Create a feature branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```

## Development Process

### Branch Strategy

- `main` - Production-ready code, protected
- `develop` - Integration branch, protected
- `feature/*` - Feature branches (PR to develop)
- `fix/*` - Bug fix branches (PR to develop)
- `docs/*` - Documentation changes (PR to develop)

### Making Changes

1. **Write code** following existing patterns
2. **Test locally** - Run scripts with test AWS accounts
3. **Update docs** - Update relevant documentation
4. **Lint** - Run `npm run lint` (if configured)
5. **Test** - Run `npm test`

### Script Development

When modifying bash scripts:

- Use `set -e` for error handling
- Add colored output using existing color codes
- Validate inputs before AWS API calls
- Add helpful error messages
- Test with actual AWS resources (create test OU)

### Testing Scripts

```bash
# Test account creation (use test OU)
./scripts/create-project-accounts.sh TST test.email ou-test-id

# Test CDK bootstrap
./scripts/bootstrap-cdk.sh TST

# Test GitHub setup (use test repo)
./scripts/setup-github-repo.sh TST test-org test-repo
```

## Commit Messages

We use [Conventional Commits](https://www.conventionalcommits.org/) for automated versioning.

### Format

```
<type>(<scope>): <subject>

[optional body]

[optional footer]

AI: Claude Code (if AI-assisted)
```

### Types

- `feat`: New feature (minor version bump)
- `fix`: Bug fix (patch version bump)
- `docs`: Documentation only
- `style`: Code style changes
- `refactor`: Code refactoring
- `perf`: Performance improvements
- `test`: Adding tests
- `build`: Build system changes
- `ci`: CI/CD changes
- `chore`: Maintenance tasks

### Breaking Changes

For breaking changes, add `!` after type or `BREAKING CHANGE:` in footer:

```bash
git commit -m "feat!: Change account naming convention

BREAKING CHANGE: Account names now use underscore instead of hyphen"
```

### Examples

```bash
git commit -m "feat: Add support for custom OU names"
git commit -m "fix: Correct IAM role trust policy"
git commit -m "docs: Update README with new prerequisites"
git commit -m "chore: Update dependencies to latest versions"
```

## Pull Request Process

1. **Update your branch** with latest develop:
   ```bash
   git fetch origin
   git rebase origin/develop
   ```

2. **Push your changes**:
   ```bash
   git push origin feature/your-feature-name
   ```

3. **Create Pull Request** on GitHub:
   - Use a clear, descriptive title
   - Follow the PR template
   - Link related issues
   - Add screenshots for UI changes
   - Request reviews from maintainers

4. **Address feedback**:
   - Make requested changes
   - Push updates (CI will re-run)
   - Resolve conversations

5. **Merge**:
   - Maintainer will merge after approval
   - Delete your feature branch after merge

### PR Requirements

- ✅ All CI checks must pass
- ✅ Code follows existing patterns
- ✅ Documentation updated
- ✅ Commit messages follow conventions
- ✅ No merge conflicts
- ✅ At least one approval (for external contributors)

## Testing

### Unit Tests

```bash
npm test
```

### Integration Tests

**Warning:** Integration tests create real AWS resources and incur costs.

```bash
# Set up test environment
export TEST_OU_ID=ou-xxxx-test
export TEST_EMAIL_PREFIX=test.email

# Run integration tests (via GitHub Actions or manually)
make integration-test PROJECT_CODE=TST
```

### Manual Testing

1. Create a test OU in your AWS Organization
2. Run scripts with test parameters
3. Verify resources created correctly
4. Clean up test resources

## Documentation

### Update Documentation

When making changes:

- Update README.md for user-facing changes
- Update CLAUDE.md for AI context changes
- Update docs/ for detailed documentation
- Add ADRs to docs/DECISIONS.md for architectural decisions
- Update CHANGELOG.md (handled by semantic-release)

### Documentation Structure

```
.
├── README.md                  # Main project documentation
├── CLAUDE.md                  # AI assistant context
├── CONTRIBUTING.md           # This file
├── docs/
│   ├── QUICK_START.md        # Quick start guide
│   ├── SETUP_OVERVIEW.md     # Detailed setup guide
│   ├── BILLING_MANAGEMENT.md # Cost management
│   ├── GITHUB_WORKFLOWS.md   # CI/CD workflows
│   ├── DECISIONS.md          # Architecture decisions
│   └── ROADMAP.md            # Future plans
└── templates/                # Code templates
```

## Questions or Issues?

- 🐛 **Bug reports**: Open an issue with the bug template
- 💡 **Feature requests**: Open an issue with the feature template
- ❓ **Questions**: Open a discussion or issue
- 💬 **Chat**: Contact maintainers

## License

By contributing, you agree that your contributions will be licensed under the Apache 2.0 License.

---

Thank you for contributing! 🚀
