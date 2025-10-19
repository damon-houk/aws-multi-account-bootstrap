# Configuration Guide

The AWS Multi-Account Bootstrap tool supports flexible configuration through multiple methods, with different precedence rules depending on the execution mode.

## Table of Contents

- [Quick Start](#quick-start)
- [Execution Modes](#execution-modes)
- [Configuration Methods](#configuration-methods)
- [Precedence Rules](#precedence-rules)
- [Configuration File Formats](#configuration-file-formats)
- [Environment Variables](#environment-variables)
- [Required Configuration Values](#required-configuration-values)
- [Examples](#examples)
- [Troubleshooting](#troubleshooting)

## Quick Start

### Interactive Mode (Default)

Run the setup wizard that prompts for missing values:

```bash
make setup-all
```

Or use a configuration file to pre-fill values:

```bash
# Create config file (YAML or JSON)
cat > .aws-bootstrap.yml <<EOF
PROJECT_CODE: MYP
EMAIL_PREFIX: your.email@gmail.com
OU_ID: ou-xxxx-xxxxxxxx
GITHUB_ORG: your-github-username
REPO_NAME: my-project
EOF

# Run setup (will use config file values)
make setup-all
```

### CI Mode

Set environment variables for automated execution:

```bash
export BOOTSTRAP_MODE=ci
export BOOTSTRAP_PROJECT_CODE=MYP
export BOOTSTRAP_EMAIL_PREFIX=your.email@gmail.com
export BOOTSTRAP_OU_ID=ou-xxxx-xxxxxxxx
export BOOTSTRAP_GITHUB_ORG=your-github-username
export BOOTSTRAP_REPO_NAME=my-project

make setup-all
```

## Execution Modes

The tool operates in two modes:

### Interactive Mode (Default)

- **When**: Default behavior when run from a terminal
- **Behavior**: Prompts for missing configuration values
- **Best for**: Manual setup, first-time users, development

### CI Mode

- **When**:
  - `BOOTSTRAP_MODE=ci` is set, OR
  - Running in CI environment (`$CI`, `$GITHUB_ACTIONS`, `$GITLAB_CI` detected)
- **Behavior**: Fails immediately if any required value is missing
- **Best for**: Automated pipelines, testing, reproducible builds

## Configuration Methods

### 1. Configuration Files

#### YAML (Recommended)

```yaml
# .aws-bootstrap.yml
PROJECT_CODE: MYP
EMAIL_PREFIX: your.email@gmail.com
OU_ID: ou-xxxx-xxxxxxxx
GITHUB_ORG: your-github-username
REPO_NAME: my-project
```

**Requirements**: `yq` must be installed for YAML support
- macOS: `brew install yq`
- Linux: See [yq installation guide](https://github.com/mikefarah/yq)

#### JSON

```json
{
  "PROJECT_CODE": "MYP",
  "EMAIL_PREFIX": "your.email@gmail.com",
  "OU_ID": "ou-xxxx-xxxxxxxx",
  "GITHUB_ORG": "your-github-username",
  "REPO_NAME": "my-project"
}
```

**Requirements**: `jq` (already required by this tool)

**File Detection Order**:
1. `.aws-bootstrap.yml` (checked first)
2. `.aws-bootstrap.yaml`
3. `.aws-bootstrap.json` (fallback)

### 2. Environment Variables

Prefix any configuration key with `BOOTSTRAP_`:

```bash
export BOOTSTRAP_PROJECT_CODE=MYP
export BOOTSTRAP_EMAIL_PREFIX=your.email@gmail.com
export BOOTSTRAP_OU_ID=ou-xxxx-xxxxxxxx
export BOOTSTRAP_GITHUB_ORG=your-github-username
export BOOTSTRAP_REPO_NAME=my-project
```

**Best for**: CI/CD pipelines, temporary overrides, secrets management

### 3. Command-Line Arguments

Pass values as positional arguments:

```bash
make setup-all PROJECT_CODE=MYP EMAIL_PREFIX=your.email OU_ID=ou-xxxx GITHUB_ORG=username REPO_NAME=project

# Or call script directly:
scripts/setup-complete-project.sh MYP your.email@gmail.com ou-xxxx-xxxxxxxx username my-project
```

**Best for**: One-off overrides, scripting

### 4. Interactive Prompts

In interactive mode, the tool prompts for missing values:

```bash
$ make setup-all

Project Code (3 uppercase letters): MYP
Email: your.email@gmail.com
OU ID: ou-xxxx-xxxxxxxx
...
```

**Best for**: First-time setup, guided experience

## Precedence Rules

Configuration sources are evaluated in different orders depending on the mode:

### Interactive Mode

```
1. CLI arguments          (highest priority - explicit override)
2. Config file            (YAML → JSON)
3. Interactive prompts    (lowest priority - fallback)
```

After setup completes, you'll be offered to save configuration to a file.

### CI Mode

```
1. CLI arguments             (highest priority - explicit override)
2. Environment variables     (BOOTSTRAP_* vars)
3. Config file              (YAML → JSON)
4. ERROR if missing         (no prompts - fail fast)
```

### Examples

**Interactive mode with partial config file:**
```bash
# .aws-bootstrap.yml has PROJECT_CODE and EMAIL_PREFIX
# Script will prompt for missing: OU_ID, GITHUB_ORG, REPO_NAME
make setup-all
```

**CI mode with mixed sources:**
```bash
# .aws-bootstrap.json has non-secret values
echo '{"PROJECT_CODE": "MYP", "GITHUB_ORG": "myorg", "REPO_NAME": "myrepo"}' > .aws-bootstrap.json

# Secrets from environment variables
export BOOTSTRAP_EMAIL_PREFIX="${SECRET_EMAIL}"
export BOOTSTRAP_OU_ID="${SECRET_OU_ID}"
export BOOTSTRAP_MODE=ci

# Override one value via CLI
make setup-all PROJECT_CODE=TST
# Result: Uses TST (CLI), SECRET_EMAIL (env), myorg (file), myrepo (file), SECRET_OU_ID (env)
```

## Configuration File Formats

### YAML Format

```yaml
# .aws-bootstrap.yml
# AWS Multi-Account Bootstrap Configuration

PROJECT_CODE: MYP
EMAIL_PREFIX: your.email@gmail.com
OU_ID: ou-xxxx-xxxxxxxx
GITHUB_ORG: your-github-username
REPO_NAME: my-project

# Optional: Add comments for team members
# PROJECT_CODE: 3-letter identifier for this project
# EMAIL_PREFIX: Gmail address (uses + addressing for account emails)
# OU_ID: Find this in AWS Organizations console
```

**Advantages**:
- Human-readable
- Supports comments
- Industry standard for infrastructure tools

**Disadvantages**:
- Requires `yq` to be installed

### JSON Format

```json
{
  "PROJECT_CODE": "MYP",
  "EMAIL_PREFIX": "your.email@gmail.com",
  "OU_ID": "ou-xxxx-xxxxxxxx",
  "GITHUB_ORG": "your-github-username",
  "REPO_NAME": "my-project"
}
```

**Advantages**:
- No additional dependencies (`jq` already required)
- Simple and widely supported

**Disadvantages**:
- No comment support
- Strict syntax

## Environment Variables

All configuration values can be set via environment variables with the `BOOTSTRAP_` prefix:

| Variable | Description | Example |
|----------|-------------|---------|
| `BOOTSTRAP_MODE` | Execution mode | `ci` or `interactive` |
| `BOOTSTRAP_PROJECT_CODE` | 3-letter project identifier | `MYP` |
| `BOOTSTRAP_EMAIL_PREFIX` | Gmail address | `your.email@gmail.com` |
| `BOOTSTRAP_OU_ID` | AWS Organization Unit ID | `ou-xxxx-xxxxxxxx` |
| `BOOTSTRAP_GITHUB_ORG` | GitHub username/org | `your-username` |
| `BOOTSTRAP_REPO_NAME` | Repository name | `my-project` |

### Auto-Detected CI Variables

The tool automatically enters CI mode when these environment variables are detected:

- `CI` (set by most CI systems)
- `GITHUB_ACTIONS` (GitHub Actions)
- `GITLAB_CI` (GitLab CI)

## Required Configuration Values

### PROJECT_CODE

- **Format**: Exactly 3 uppercase alphanumeric characters
- **Valid**: `MYP`, `TST`, `ABC`, `A1B`
- **Invalid**: `my` (too short), `test` (too long), `abc` (lowercase)
- **Purpose**: Unique identifier for AWS account names and resource tagging

### EMAIL_PREFIX

- **Format**: Valid email address
- **Example**: `your.email@gmail.com`
- **Purpose**: Used with Gmail + addressing for account emails
  - Dev: `your.email+myp-dev@gmail.com`
  - Staging: `your.email+myp-staging@gmail.com`
  - Prod: `your.email+myp-prod@gmail.com`

### OU_ID

- **Format**: `ou-xxxx-xxxxxxxx` (AWS Organization Unit ID)
- **Example**: `ou-a1b2-c3d4e5f6`
- **Find it**: AWS Console → Organizations → Organizational Units
- **Purpose**: Determines where AWS accounts are created in your organization

### GITHUB_ORG

- **Format**: GitHub username or organization name
- **Example**: `your-username` or `your-org`
- **Purpose**: Owner of the GitHub repository to be created

### REPO_NAME

- **Format**: Valid GitHub repository name
- **Example**: `my-project`, `therapy-practice-app`
- **Purpose**: Name of the GitHub repository to be created

## Examples

### Example 1: First-Time Interactive Setup

```bash
# No config file, no environment variables
make setup-all

# You'll be prompted for all values
# At the end, you'll be offered to save configuration
```

### Example 2: Team Shared Configuration

```bash
# Team commits .aws-bootstrap.json to repository
cat > .aws-bootstrap.json <<EOF
{
  "PROJECT_CODE": "MYP",
  "GITHUB_ORG": "our-team",
  "REPO_NAME": "therapy-app"
}
EOF

git add .aws-bootstrap.json
git commit -m "Add bootstrap configuration"
git push

# Team members only need to provide secrets
export BOOTSTRAP_EMAIL_PREFIX="team.member@gmail.com"
export BOOTSTRAP_OU_ID="ou-xxxx-xxxxxxxx"  # Get from team lead

make setup-all
```

### Example 3: GitHub Actions CI

```yaml
# .github/workflows/setup.yml
name: Setup AWS Accounts

on:
  workflow_dispatch:
    inputs:
      project_code:
        description: '3-letter project code'
        required: true

jobs:
  setup:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Run AWS Bootstrap
        env:
          BOOTSTRAP_MODE: ci
          BOOTSTRAP_PROJECT_CODE: ${{ github.event.inputs.project_code }}
          BOOTSTRAP_EMAIL_PREFIX: ${{ secrets.EMAIL_PREFIX }}
          BOOTSTRAP_OU_ID: ${{ secrets.OU_ID }}
          BOOTSTRAP_GITHUB_ORG: ${{ github.repository_owner }}
          BOOTSTRAP_REPO_NAME: ${{ github.event.repository.name }}
        run: make setup-all
```

### Example 4: Override Single Value

```bash
# Config file has most values
cat > .aws-bootstrap.yml <<EOF
PROJECT_CODE: MYP
EMAIL_PREFIX: your.email@gmail.com
OU_ID: ou-xxxx-xxxxxxxx
GITHUB_ORG: your-username
REPO_NAME: my-project
EOF

# But you want to test with a different project code
make setup-all PROJECT_CODE=TST
```

## Troubleshooting

### "yq not installed" but I have a YAML file

If you create a `.aws-bootstrap.yml` file but don't have `yq` installed:

**Interactive mode**: Values will be empty, and you'll be prompted
**CI mode**: Setup will fail

**Solution**: Either install `yq` or use JSON instead:

```bash
# Option 1: Install yq
brew install yq  # macOS
# or follow: https://github.com/mikefarah/yq

# Option 2: Convert to JSON
rm .aws-bootstrap.yml
cat > .aws-bootstrap.json <<EOF
{
  "PROJECT_CODE": "MYP",
  ...
}
EOF
```

### "Missing required configuration in CI mode"

This error occurs when required values are not provided in CI mode.

**Check**:
1. Environment variables are set correctly (`BOOTSTRAP_*`)
2. Config file exists and contains all required values
3. Config file is in the correct location (project root)

**Debug**:
```bash
# Check what config file is detected
source scripts/lib/config-manager.sh
detect_config_file

# Check mode detection
detect_mode

# Test parsing
parse_config_value "PROJECT_CODE" "$(detect_config_file)"
```

### Interactive prompts appearing in CI

If you're seeing prompts in your CI pipeline:

**Cause**: CI mode not detected

**Solution**: Explicitly set CI mode:
```bash
export BOOTSTRAP_MODE=ci
```

### CLI arguments not working with Makefile

**Wrong**:
```bash
make setup-all MYP user@gmail.com  # Positional args don't work with make
```

**Right**:
```bash
make setup-all PROJECT_CODE=MYP EMAIL_PREFIX=user@gmail.com  # Named parameters

# Or call script directly:
scripts/setup-complete-project.sh MYP user@gmail.com ou-xxx username repo
```

### Config file not being detected

**Check**:
1. File is in project root (same directory as `Makefile`)
2. File has correct name: `.aws-bootstrap.yml`, `.aws-bootstrap.yaml`, or `.aws-bootstrap.json`
3. File has correct format (valid YAML/JSON syntax)

**Test**:
```bash
# Verify file location
ls -la .aws-bootstrap.*

# Test JSON syntax
jq . .aws-bootstrap.json

# Test YAML syntax (if yq installed)
yq eval . .aws-bootstrap.yml
```

## Best Practices

### 1. Version Control

**DO commit**:
- `.aws-bootstrap.yml` or `.aws-bootstrap.json` with non-sensitive values
- Example:
  ```yaml
  PROJECT_CODE: MYP
  GITHUB_ORG: our-team
  REPO_NAME: therapy-app
  # OU_ID and EMAIL_PREFIX should be set via environment variables
  ```

**DON'T commit**:
- Sensitive values like `OU_ID` (if it reveals org structure)
- Personal email addresses
- Use environment variables or CI secrets for these

### 2. Team Workflows

**Recommended approach**:
1. Commit config file with team-shared values (PROJECT_CODE, GITHUB_ORG, REPO_NAME)
2. Document which environment variables team members need to set
3. Provide example `.env.example` file:
   ```bash
   # .env.example (don't commit actual .env)
   BOOTSTRAP_EMAIL_PREFIX=your.email@gmail.com
   BOOTSTRAP_OU_ID=ou-xxxx-xxxxxxxx  # Get from team lead
   ```

### 3. CI/CD Pipelines

**Recommended approach**:
1. Store non-sensitive config in `.aws-bootstrap.json` (committed)
2. Store secrets in CI environment variables or secrets manager
3. Use explicit `BOOTSTRAP_MODE=ci` to ensure fail-fast behavior

### 4. Development vs Production

**Development**:
```bash
# Use interactive mode, save config for reuse
make setup-all
# Choose to save configuration when prompted
```

**Production/CI**:
```bash
# Use CI mode with explicit configuration
export BOOTSTRAP_MODE=ci
export BOOTSTRAP_PROJECT_CODE=PROD
...
make setup-all
```

## See Also

- [Main README](../README.md) - Project overview and quick start
- [Contributing Guide](../CONTRIBUTING.md) - Development setup
- [Roadmap](./ROADMAP.md) - Future configuration features planned