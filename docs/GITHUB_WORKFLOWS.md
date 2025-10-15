# GitHub Workflows Documentation

This document describes the GitHub Actions workflows configured for the AWS Multi-Account Bootstrap tool repository.

## Overview

This repository uses three main workflows to ensure code quality and automate releases:

1. **CI Workflow** - Continuous Integration (linting, validation, testing)
2. **Integration Tests** - Setup/teardown tests in real AWS environment
3. **Release Workflow** - Automated semantic versioning and releases

---

## CI Workflow

**File:** `.github/workflows/ci.yml`
**Triggers:** Pull requests and pushes to `main` or `develop` branches

### Jobs

#### 1. Lint Bash Scripts
- Uses ShellCheck to validate bash scripts in `scripts/` directory
- Catches common shell scripting errors
- Severity: warning level and above

#### 2. Validate Makefile
- Runs dry-run of Makefile to check syntax
- Ensures Make targets are properly defined

#### 3. Check Documentation
- Validates markdown links in documentation
- Uses configuration from `.github/markdown-link-check-config.json`
- Ensures documentation links are not broken

#### 4. Unit Tests
- Sets up Node.js 20
- Installs dependencies
- Runs `npm test` (when tests are configured)
- Currently gracefully skips if no tests exist

#### 5. Validate Project Structure
- Checks for required files:
  - README.md
  - LICENSE
  - Makefile
  - All scripts in `scripts/` directory
- Verifies script files are executable

### When Does It Run?

```bash
# Automatically runs on:
git push origin develop           # Push to develop
git push origin main               # Push to main
gh pr create --base main          # Create PR to main
gh pr create --base develop       # Create PR to develop
```

### Expected Outcome

All jobs must pass for PRs to be merged. If any job fails:
1. Review the error logs in GitHub Actions
2. Fix the issues locally
3. Push the fixes
4. CI will automatically re-run

---

## Integration Tests Workflow

**File:** `.github/workflows/integration-tests.yml`
**Triggers:** Manual workflow dispatch only (expensive to run)

### Purpose

Tests the complete setup and teardown flow in a real AWS Organization to ensure:
- Accounts can be created successfully
- CDK bootstrap works correctly
- Resources can be cleaned up properly

### How to Run

#### Via GitHub UI:
1. Go to Actions tab in GitHub
2. Select "Integration Tests" workflow
3. Click "Run workflow"
4. Provide required inputs:
   - `test_ou_id`: AWS OU ID where test accounts will be created
   - `email_prefix`: Email prefix for test accounts

#### Via GitHub CLI:
```bash
gh workflow run integration-tests.yml \
  -f test_ou_id=ou-xxxx-xxxxxxxx \
  -f email_prefix=your.email
```

### What It Does

1. **Creates test accounts** with PROJECT_CODE="TST":
   - TST_DEV
   - TST_STAGING
   - TST_PROD

2. **Bootstraps CDK** in all test accounts

3. **Captures account IDs** for cleanup

4. **Cleanup** (always runs, even on failure):
   - Closes all test accounts
   - Note: AWS keeps closed accounts for 90 days

### Cost Considerations

Integration tests are **expensive** because they:
- Create real AWS accounts
- Bootstrap CDK (creates S3, ECR, KMS resources)
- May incur charges even with immediate cleanup

**Recommendations:**
- Run sparingly (before major releases)
- Use a dedicated test OU
- Monitor costs in AWS Billing console

### Required GitHub Secrets

This workflow requires AWS credentials stored as repository secrets:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

**Setup:**
```bash
# Create IAM user with Organizations permissions
aws iam create-user --user-name github-integration-tests

# Attach policy (use least privilege in production)
aws iam attach-user-policy \
  --user-name github-integration-tests \
  --policy-arn arn:aws:iam::aws:policy/AWSOrganizationsFullAccess

# Create access key
aws iam create-access-key --user-name github-integration-tests

# Add to GitHub secrets
gh secret set AWS_ACCESS_KEY_ID
gh secret set AWS_SECRET_ACCESS_KEY
```

### Environment Protection

This workflow uses the `integration-testing` environment which can be configured to:
- Require manual approval before running
- Restrict who can approve
- Add deployment protection rules

**Configure in GitHub:**
Settings → Environments → Create "integration-testing" environment

---

## Release Workflow

**File:** `.github/workflows/release.yml`
**Triggers:** Push to `main` branch

### Purpose

Automates versioning and releases using semantic-release based on conventional commit messages.

### How It Works

1. **Analyzes commit messages** since last release
2. **Determines version bump** based on commit types:
   - `feat:` → Minor version (1.0.0 → 1.1.0)
   - `fix:` → Patch version (1.0.0 → 1.0.1)
   - `feat!:` or `BREAKING CHANGE:` → Major version (1.0.0 → 2.0.0)
   - `docs:`, `chore:`, etc. → No release

3. **Generates changelog** from commits
4. **Creates GitHub release** with release notes
5. **Updates CHANGELOG.md** in repository
6. **Creates git tag** for the new version

### Commit Message Format

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```bash
# New feature (minor release)
git commit -m "feat: add support for 5-account setup template"

# Bug fix (patch release)
git commit -m "fix: correct account email validation regex"

# Breaking change (major release)
git commit -m "feat!: redesign Makefile parameter structure

BREAKING CHANGE: All Makefile commands now use different parameter names"

# Documentation (no release)
git commit -m "docs: update integration testing guide"

# Chore (no release)
git commit -m "chore: update dependencies"
```

### Release Process

```bash
# 1. Create feature branch
git checkout -b feature/my-feature

# 2. Make changes and commit with conventional commit message
git add .
git commit -m "feat: add new feature"

# 3. Push and create PR to develop
git push origin feature/my-feature
gh pr create --base develop

# 4. Merge to develop (tests will run, but no release)
gh pr merge

# 5. When ready for release, create PR from develop to main
git checkout develop
git pull
gh pr create --base main --title "Release: Next version"

# 6. Merge to main → Automatic release!
gh pr merge
# Release workflow runs automatically
# New version is tagged and released
```

### What Gets Released?

- **Git tag** (e.g., v1.2.0)
- **GitHub Release** with auto-generated release notes
- **CHANGELOG.md** updated in the repository

### Configuration

Release behavior is configured in `.releaserc.json`:
- Commit analysis rules
- Release note generation
- Changelog format
- Git commit settings

---

## Workflow Files Summary

```
.github/
├── workflows/
│   ├── ci.yml                    # Linting, validation, tests
│   ├── integration-tests.yml     # Real AWS setup/teardown tests
│   └── release.yml               # Semantic versioning & releases
├── ISSUE_TEMPLATE/
│   ├── bug_report.yml            # Bug report template
│   ├── feature_request.yml       # Feature request template
│   └── config.yml                # Issue template configuration
├── pull_request_template.md      # PR template
└── markdown-link-check-config.json  # Link checker config
```

---

## Best Practices

### For Contributors

1. **Always use conventional commits**
   ```bash
   git commit -m "type: description"
   ```

2. **Test locally before pushing**
   ```bash
   make check-prerequisites
   shellcheck scripts/*.sh
   ```

3. **Create PRs to develop first**, then release to main

4. **Fill out PR template completely**

5. **Ensure CI passes** before requesting review

### For Maintainers

1. **Protect main and develop branches**
   - Require PR reviews
   - Require CI to pass
   - Disable direct pushes

2. **Run integration tests before major releases**
   ```bash
   gh workflow run integration-tests.yml -f test_ou_id=... -f email_prefix=...
   ```

3. **Review generated changelogs** after releases

4. **Monitor workflow runs** for failures

---

## Troubleshooting

### CI Workflow Failures

**ShellCheck errors:**
```bash
# Run locally
shellcheck scripts/*.sh
```

**Markdown link check failures:**
- Check that URLs are valid
- Update `.github/markdown-link-check-config.json` to ignore false positives

**Unit test failures:**
```bash
npm install
npm test
```

### Integration Test Failures

**"Cannot assume OrganizationAccountAccessRole":**
- Wait 30 seconds and retry (AWS propagation delay)
- Verify AWS credentials have Organizations permissions

**Account already exists:**
- Test accounts from previous run may still exist (closed accounts remain for 90 days)
- Use different PROJECT_CODE or wait for cleanup

**Cost concerns:**
- Review AWS Billing console
- Delete CloudFormation stacks if cleanup failed
- Close accounts manually if needed

### Release Workflow Issues

**No release created:**
- Check commit messages use conventional format
- Verify commits are `feat:` or `fix:` (not `docs:` or `chore:`)
- Check workflow logs for semantic-release output

**Wrong version number:**
- Review commit messages since last release
- Ensure breaking changes use `feat!:` or `BREAKING CHANGE:` footer

**Permission denied:**
- Verify `GITHUB_TOKEN` has correct permissions
- Check workflow permissions in `.github/workflows/release.yml`

---

## Future Enhancements

Planned improvements to workflows:

### v1.1
- [ ] Add unit tests with bats-core
- [ ] Automated dependency updates (Dependabot)
- [ ] Security scanning (CodeQL)
- [ ] Performance benchmarks

### v1.2
- [ ] Multi-region integration tests
- [ ] Cost estimation in PRs
- [ ] Terraform validation (when Terraform support added)
- [ ] Automated documentation generation

### v2.0
- [ ] Compliance scanning
- [ ] Security policy enforcement
- [ ] Automated rollback on failures
- [ ] Advanced cost tracking

---

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Semantic Release Documentation](https://semantic-release.gitbook.io/)
- [Conventional Commits Specification](https://www.conventionalcommits.org/)
- [ShellCheck Wiki](https://github.com/koalaman/shellcheck/wiki)
- [Markdown Link Check](https://github.com/tcort/markdown-link-check)

---

## Questions?

If you have questions about the workflows:
1. Check this documentation
2. Review workflow run logs in GitHub Actions tab
3. Open a [Discussion](https://github.com/damon-houk/aws-multi-account-bootstrap/discussions)
4. File an [Issue](https://github.com/damon-houk/aws-multi-account-bootstrap/issues)