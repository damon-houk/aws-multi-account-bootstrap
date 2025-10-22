# AWS Multi-Account Bootstrap - v1 (Bash)

> ⚠️ **This is v1 (bash) - now in maintenance mode**
>
> For new projects, see [v2 (Go)](../go) with:
> - Better UI/UX (TUI, Web, Mobile, Desktop)
> - Strong typing and better testing
> - Single binary distribution
> - Multi-platform support

---

## About v1 (Bash)

This is the original bash implementation of AWS Multi-Account Bootstrap. It creates a production-ready AWS multi-account setup with GitHub CI/CD in one command.

**Status**: Maintenance mode - bug fixes only
**Version**: v1.x
**Last Major Update**: 2025-10-21

### What v1 Provides

- ✅ 3-account AWS setup (dev/staging/prod)
- ✅ GitHub Actions with OIDC (no stored credentials)
- ✅ AWS CDK bootstrap
- ✅ Billing alerts and budgets
- ✅ Configuration system (YAML/JSON/env vars)
- ✅ Hexagonal architecture (Ports & Adapters)
- ✅ Mock adapters for testing

### Quick Start

```bash
# From bash/ directory
make setup-all PROJECT_CODE=XYZ EMAIL_PREFIX=email \
  OU_ID=ou-xxxx-xxxxxxxx GITHUB_ORG=username REPO_NAME=repo
```

### Documentation

- [Configuration Guide](docs/CONFIGURATION.md)
- [Architecture](docs/ARCHITECTURE_REFACTORING.md)
- [Template Browser](docs/TEMPLATE_BROWSER.md)
- [Billing Management](docs/BILLING_MANAGEMENT.md)

### Testing

```bash
# Run all tests
./tests/test-config-simple.sh
./tests/test-mock-adapters.sh
```

### Migration to v2

See [Migration Guide](../docs/migration/BASH_TO_GO.md) for how to migrate from v1 to v2.

### Why Maintenance Mode?

v1 (bash) achieved its goals but has limitations:
- ❌ No GUI/TUI - only CLI prompts
- ❌ Bash testing is difficult
- ❌ Hard to distribute (requires bash + dependencies)
- ❌ Limited type safety

v2 (Go) addresses these with:
- ✅ Beautiful TUI (Bubbletea)
- ✅ Web UI, Mobile apps, Desktop app
- ✅ Strong typing (Go + TypeScript)
- ✅ Single binary distribution
- ✅ Excellent testing (Go test + pytest)

### Support

v1 will receive:
- ✅ Critical bug fixes
- ✅ Security updates
- ❌ No new features
- ❌ No major refactoring

For new features, use v2 (Go).

---

**Version**: 1.x
**Maintained**: Yes (bug fixes only)
**Recommended**: No (use v2 for new projects)

AI: Claude Code
