## Description

<!-- Provide a clear and concise description of your changes -->

## Type of Change

<!-- Mark the relevant option with an "x" -->

- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update
- [ ] Refactoring (no functional changes)
- [ ] CI/CD changes
- [ ] Test additions/improvements

## Related Issue

<!-- Link to the issue this PR addresses -->
Fixes #(issue number)

## Changes Made

<!-- List the specific changes made in this PR -->

-
-
-

## Testing

<!-- Describe the testing you've done -->

- [ ] Tested locally with `make check-prerequisites`
- [ ] Ran ShellCheck on modified scripts
- [ ] Tested account creation flow
- [ ] Tested CDK bootstrap
- [ ] Tested GitHub setup
- [ ] Tested billing alerts
- [ ] Added/updated tests
- [ ] All existing tests pass

## Testing Instructions

<!-- How should reviewers test this? -->

```bash
# Example commands for testing
make setup-all PROJECT_CODE=TST ...
```

## Documentation

- [ ] Updated README.md (if needed)
- [ ] Updated CLAUDE.md (if needed)
- [ ] Updated relevant docs/ files
- [ ] Added/updated code comments
- [ ] Updated CHANGELOG.md (will be auto-generated)

## Screenshots/Output

<!-- If applicable, add screenshots or command output -->

```
# Paste relevant output here
```

## Checklist

- [ ] My code follows the project's style guidelines
- [ ] I have performed a self-review of my code
- [ ] I have commented my code, particularly in hard-to-understand areas
- [ ] I have made corresponding changes to the documentation
- [ ] My changes generate no new warnings
- [ ] I have added tests that prove my fix is effective or that my feature works
- [ ] New and existing unit tests pass locally with my changes
- [ ] Any dependent changes have been merged and published

## Additional Context

<!-- Add any other context about the PR here -->

## Commit Message Format

<!-- Confirm your commit messages follow conventional commits -->

- [ ] My commit messages follow the [Conventional Commits](https://www.conventionalcommits.org/) format
  - `feat:` for new features
  - `fix:` for bug fixes
  - `docs:` for documentation changes
  - `chore:` for maintenance tasks
  - `refactor:` for code refactoring
  - `test:` for test additions/changes
  - `ci:` for CI/CD changes