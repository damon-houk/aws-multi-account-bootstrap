# Test Plan: Non-Interactive Mode

## Overview
This test plan covers the non-interactive mode implementation in commits:
- `684dd38` - Add non-interactive mode to setup-github-repo.sh
- `adbaca8` - Add non-interactive mode and generate package-lock.json

## Changes Being Tested

### Key Features
1. ✅ `-y` / `--yes` flag support in `setup-github-repo.sh`
2. ✅ Automatic passing of `--yes` flag from `setup-complete-project.sh` to `setup-github-repo.sh`
3. ✅ `npm install` runs during project creation to generate `package-lock.json`
4. ✅ Project files created in `output/{PROJECT_CODE}/` directory
5. ✅ Non-interactive defaults (private repo, no prompts)

### Files Modified
- `scripts/setup-complete-project.sh`
- `scripts/setup-github-repo.sh`

---

## Test Environment Setup

### Prerequisites
```bash
# 1. Ensure clean branch
git status
git branch  # Should be on: fix/github-repo-non-interactive-mode

# 2. Verify prerequisites installed
make check-prerequisites

# 3. Authenticate with AWS
aws sso login
aws sts get-caller-identity

# 4. Authenticate with GitHub
gh auth login
gh auth status

# 5. Clean up any previous test artifacts
rm -rf output/TST*
```

### Test Data
```bash
# Test project parameters (use consistent naming for cleanup)
PROJECT_CODE=TST
EMAIL_PREFIX=damon.o.houk
OU_ID=<your-test-ou-id>  # Create a test OU or use existing
GITHUB_ORG=damon-houk    # Use your GitHub username
REPO_NAME=test-non-interactive-mode-$(date +%s)  # Unique repo name
```

---

## Test Cases

### Test 1: Non-Interactive Mode - Full Setup
**Purpose:** Verify complete setup works with `-y` flag without any prompts

**Steps:**
```bash
# 1. Run full setup with -y flag
time ./scripts/setup-complete-project.sh \
  TST \
  damon.o.houk \
  <OU_ID> \
  damon-houk \
  test-ni-full-$(date +%s) \
  -y

# Expected: No prompts, completes automatically
```

**Expected Results:**
- [ ] Script runs without any user prompts
- [ ] No hanging or waiting for input
- [ ] 3 AWS accounts created (TST_DEV, TST_STAGING, TST_PROD)
- [ ] CDK bootstrapped in all accounts
- [ ] GitHub repository created (private by default)
- [ ] Project directory created at `output/TST/`
- [ ] `package-lock.json` exists in `output/TST/`
- [ ] All summary files created in `output/TST/`
- [ ] Exit code = 0

**Verification:**
```bash
# Check output directory
ls -la output/TST/

# Verify package-lock.json exists
test -f output/TST/package-lock.json && echo "✓ package-lock.json found" || echo "✗ Missing!"

# Verify summary files
test -f output/TST/CICD_SETUP_SUMMARY.md && echo "✓ CICD summary found" || echo "✗ Missing!"
test -f output/TST/GITHUB_SETUP_SUMMARY.md && echo "✓ GitHub summary found" || echo "✗ Missing!"
test -f output/TST/BILLING_ALERTS_SUMMARY.md && echo "✓ Billing summary found" || echo "✗ Missing!"

# Check GitHub repo was created (private)
gh repo view damon-houk/test-ni-full-XXXXX --json visibility -q .visibility
# Expected output: PRIVATE

# Check GitHub Actions workflows exist
gh api "repos/damon-houk/test-ni-full-XXXXX/contents/.github/workflows" --jq '.[].name'
# Expected: ci.yml, deploy-dev.yml, deploy-staging.yml, etc.

# Verify AWS accounts exist
aws organizations list-accounts --query 'Accounts[?Name==`TST_DEV`]' --output table
aws organizations list-accounts --query 'Accounts[?Name==`TST_STAGING`]' --output table
aws organizations list-accounts --query 'Accounts[?Name==`TST_PROD`]' --output table
```

**Cleanup:**
```bash
# Delete GitHub repo
gh repo delete damon-houk/test-ni-full-XXXXX --yes

# Note: AWS accounts cannot be easily deleted - mark them for testing
# You can close accounts via AWS Console if needed
```

---

### Test 2: Interactive Mode Still Works
**Purpose:** Verify `-y` flag doesn't break normal interactive mode

**Steps:**
```bash
# 1. Run setup WITHOUT -y flag
./scripts/setup-complete-project.sh \
  TST \
  damon.o.houk \
  <OU_ID> \
  damon-houk \
  test-interactive-$(date +%s)

# When prompted: "Proceed with setup? [y/N]"
# Answer: y

# When prompted (via setup-github-repo.sh): "Make repository private? [Y/n]"
# Answer: Y (or just press Enter)

# When prompted: "Continue with repository creation? [y/N]"
# Answer: y
```

**Expected Results:**
- [ ] Script prompts for confirmation at appropriate points
- [ ] User can answer prompts interactively
- [ ] Setup completes successfully after confirmations
- [ ] All files created in `output/TST/`

**Verification:**
```bash
# Same verification as Test 1
ls -la output/TST/
test -f output/TST/package-lock.json && echo "✓" || echo "✗"
```

---

### Test 3: setup-github-repo.sh Standalone - Non-Interactive
**Purpose:** Verify `setup-github-repo.sh` works independently with `--yes` flag

**Steps:**
```bash
# 1. Create a test project directory
mkdir -p output/TST-standalone
cd output/TST-standalone

# 2. Initialize git
git init
git config user.name "Test User"
git config user.email "test@example.com"

# 3. Create minimal files
echo "# Test" > README.md
git add README.md
git commit -m "Initial commit"

# 4. Run setup-github-repo.sh with --yes
cd ../..
./scripts/setup-github-repo.sh \
  TST \
  damon-houk \
  test-standalone-$(date +%s) \
  output/TST-standalone \
  --yes
```

**Expected Results:**
- [ ] No prompts displayed
- [ ] Repository created (private by default)
- [ ] GITHUB_SETUP_SUMMARY.md created in `output/TST-standalone/`
- [ ] Branch protection configured
- [ ] Environments created (dev, staging, prod)

**Verification:**
```bash
# Check summary file location
test -f output/TST-standalone/GITHUB_SETUP_SUMMARY.md && echo "✓" || echo "✗"

# Verify repo exists
gh repo view damon-houk/test-standalone-XXXXX
```

---

### Test 4: setup-github-repo.sh Standalone - Interactive
**Purpose:** Verify standalone script still works interactively

**Steps:**
```bash
# Similar to Test 3, but without --yes flag
mkdir -p output/TST-interactive
cd output/TST-interactive
git init
echo "# Test" > README.md
git add README.md
git commit -m "Initial commit"
cd ../..

./scripts/setup-github-repo.sh \
  TST \
  damon-houk \
  test-interactive-gh-$(date +%s) \
  output/TST-interactive

# Answer prompts when they appear
```

**Expected Results:**
- [ ] Prompts appear for repository visibility
- [ ] Prompts appear for confirmation
- [ ] Setup completes after answering prompts

---

### Test 5: Error Handling - GitHub Not Authenticated (Non-Interactive)
**Purpose:** Verify graceful failure when GitHub auth is missing in non-interactive mode

**Steps:**
```bash
# 1. Logout from GitHub
gh auth logout

# 2. Try running setup with -y flag
./scripts/setup-complete-project.sh \
  TST \
  test@example.com \
  <OU_ID> \
  someorg \
  test-no-auth \
  -y
```

**Expected Results:**
- [ ] Script fails early (before creating AWS resources)
- [ ] Clear error message about GitHub authentication
- [ ] Non-zero exit code
- [ ] Suggests running `gh auth login`

**Note:** This test will currently FAIL because we haven't added GitHub CLI checks to `setup-complete-project.sh` yet. This is a known gap we identified.

**Cleanup:**
```bash
# Re-authenticate
gh auth login
```

---

### Test 6: package-lock.json Generation
**Purpose:** Verify npm install runs and creates lock file

**Steps:**
```bash
# 1. Run minimal setup (can skip AWS parts if already tested)
# Just create project structure
mkdir -p output/TST-lockfile
cd output/TST-lockfile

# 2. Create package.json manually
cat > package.json <<'EOF'
{
  "name": "test-app",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "build": "tsc"
  },
  "devDependencies": {
    "@types/node": "^20.0.0",
    "typescript": "^5.0.0"
  }
}
EOF

# 3. Run npm install
npm install

# 4. Check lock file
ls -la package-lock.json
```

**Expected Results:**
- [ ] `package-lock.json` created
- [ ] `node_modules/` created
- [ ] Lock file contains dependency versions
- [ ] GitHub Actions can use lock file for caching

**Verification:**
```bash
# Check lock file is valid JSON
jq . package-lock.json > /dev/null && echo "✓ Valid JSON" || echo "✗ Invalid!"

# Check it has lockfileVersion
jq '.lockfileVersion' package-lock.json
```

---

### Test 7: Output Directory Structure
**Purpose:** Verify all files are created in correct output directory

**Steps:**
```bash
# Run full setup
./scripts/setup-complete-project.sh \
  OUT \
  damon.o.houk \
  <OU_ID> \
  damon-houk \
  test-output-structure-$(date +%s) \
  -y
```

**Expected Results:**
- [ ] Directory `output/OUT/` created
- [ ] All project files in `output/OUT/` (not repository root)
- [ ] Structure matches expected layout

**Verification:**
```bash
# Check directory structure
tree output/OUT/ -L 2

# Expected structure:
# output/OUT/
# ├── infrastructure/
# │   ├── bin/
# │   ├── lib/
# │   └── test/
# ├── src/
# │   ├── frontend/
# │   ├── backend/
# │   └── shared/
# ├── docs/
# ├── package.json
# ├── package-lock.json
# ├── tsconfig.json
# ├── cdk.json
# ├── README.md
# ├── CICD_SETUP_SUMMARY.md
# ├── GITHUB_SETUP_SUMMARY.md
# └── BILLING_ALERTS_SUMMARY.md

# Verify summary files are NOT in repository root
test ! -f CICD_SETUP_SUMMARY.md && echo "✓ No files in root" || echo "✗ Files leaked to root!"
test ! -f GITHUB_SETUP_SUMMARY.md && echo "✓ No files in root" || echo "✗ Files leaked to root!"
```

---

### Test 8: Argument Parsing
**Purpose:** Verify `-y` flag works in different positions

**Steps:**
```bash
# Test 1: Flag at end (current usage)
./scripts/setup-github-repo.sh TST org repo . -y
# Expected: Works

# Test 2: Flag at beginning
./scripts/setup-github-repo.sh -y TST org repo .
# Expected: Works (due to while loop parsing)

# Test 3: Flag in middle
./scripts/setup-github-repo.sh TST -y org repo .
# Expected: Works

# Test 4: --yes variant
./scripts/setup-github-repo.sh TST org repo . --yes
# Expected: Works

# Test 5: Both flags (edge case)
./scripts/setup-github-repo.sh TST org repo . -y --yes
# Expected: Works (flag set once, no errors)
```

**Expected Results:**
- [ ] All flag positions work correctly
- [ ] Both `-y` and `--yes` work
- [ ] No errors from argument parsing

---

### Test 9: Makefile Integration
**Purpose:** Verify setup works through Makefile

**Steps:**
```bash
# Run via make
make setup-all \
  PROJECT_CODE=MAK \
  EMAIL_PREFIX=damon.o.houk \
  OU_ID=<OU_ID> \
  GITHUB_ORG=damon-houk \
  REPO_NAME=test-makefile-$(date +%s)

# Note: This will be interactive unless we add -y support to Makefile
```

**Expected Results:**
- [ ] Makefile calls script correctly
- [ ] All parameters passed properly
- [ ] Setup completes successfully

---

### Test 10: CI Compatibility (Simulated)
**Purpose:** Verify script works in CI-like environment

**Steps:**
```bash
# Run in a subshell with no TTY simulation
# (Difficult to test locally, but check for common issues)

# 1. Check script doesn't use interactive commands when -y provided
grep -n "read -p" scripts/setup-complete-project.sh
grep -n "read -p" scripts/setup-github-repo.sh

# Ensure all read prompts are wrapped in AUTO_CONFIRM checks

# 2. Run with minimal environment
env -i \
  PATH="$PATH" \
  HOME="$HOME" \
  AWS_PROFILE="$AWS_PROFILE" \
  ./scripts/setup-complete-project.sh \
  TST \
  damon.o.houk \
  <OU_ID> \
  damon-houk \
  test-ci-sim-$(date +%s) \
  -y
```

**Expected Results:**
- [ ] Script doesn't rely on interactive shell features
- [ ] Works with minimal environment variables
- [ ] No TTY-dependent operations when `-y` is used

---

## Manual Test Execution Checklist

Run through tests in order:

### Quick Smoke Test (15 minutes)
- [ ] Test 6: package-lock.json generation
- [ ] Test 8: Argument parsing
- [ ] Test 3: setup-github-repo.sh standalone with --yes

### Medium Test (30 minutes)
- [ ] Test 2: Interactive mode still works
- [ ] Test 4: setup-github-repo.sh interactive
- [ ] Test 7: Output directory structure

### Full Test (2+ hours - requires AWS account creation)
- [ ] Test 1: Non-interactive full setup
- [ ] Test 5: Error handling (requires gh auth logout)
- [ ] Test 9: Makefile integration
- [ ] Test 10: CI compatibility

---

## Automated Test Script

```bash
#!/bin/bash
# Quick automated tests that don't require full AWS setup

set -e

echo "=== Running Automated Tests ==="

# Test 1: Argument parsing
echo "Test: Argument parsing for -y flag"
./scripts/setup-github-repo.sh 2>&1 | grep -q "auto-confirm" && echo "✗ Should show usage" || echo "✓"

# Test 2: Check help text includes -y option
./scripts/setup-github-repo.sh 2>&1 | grep -q "yes" && echo "✓ Help includes -y" || echo "✗ Missing!"

# Test 3: Verify file structure
echo "Test: Script file exists and is executable"
test -x scripts/setup-complete-project.sh && echo "✓" || echo "✗"
test -x scripts/setup-github-repo.sh && echo "✓" || echo "✗"

# Test 4: Check for TODO/FIXME comments
echo "Test: No leftover TODOs in modified files"
! grep -n "TODO\|FIXME" scripts/setup-complete-project.sh && echo "✓" || echo "⚠️ TODOs found"
! grep -n "TODO\|FIXME" scripts/setup-github-repo.sh && echo "✓" || echo "⚠️ TODOs found"

# Test 5: ShellCheck validation
if command -v shellcheck &> /dev/null; then
    echo "Test: ShellCheck validation"
    shellcheck scripts/setup-complete-project.sh && echo "✓" || echo "✗"
    shellcheck scripts/setup-github-repo.sh && echo "✓" || echo "✗"
else
    echo "⚠️ ShellCheck not installed, skipping"
fi

echo "=== Automated Tests Complete ==="
```

Save as `test-non-interactive.sh` and run with:
```bash
chmod +x test-non-interactive.sh
./test-non-interactive.sh
```

---

## Known Issues / Limitations

### Issues to Fix Before Merge
1. ❌ **GitHub CLI not checked in prerequisites** (setup-complete-project.sh)
   - Impact: Setup can run for 5+ minutes, then fail at GitHub step
   - Priority: HIGH
   - Fix: Add GitHub CLI check early in setup-complete-project.sh

2. ❌ **GitHub auth not verified in non-interactive mode**
   - Impact: Script will hang or fail when trying to run `gh auth login` with -y
   - Priority: HIGH
   - Fix: Check `gh auth status` before starting, fail fast if not authenticated

### Nice to Have
3. ⚠️ **No dry-run mode**
   - Impact: Can't preview what will be created without running full setup
   - Priority: MEDIUM
   - Planned for: v1.1 (guided wizard)

4. ⚠️ **package-lock.json shows install output**
   - Impact: Verbose output during npm install
   - Priority: LOW
   - Fix: Already using `--silent` flag

---

## Success Criteria

For this PR to be ready to merge:

### Must Have (Blocking)
- [ ] Test 1 passes (non-interactive full setup)
- [ ] Test 2 passes (interactive mode still works)
- [ ] Test 6 passes (package-lock.json created)
- [ ] Test 7 passes (output directory correct)
- [ ] All files in correct output directory
- [ ] No prompts appear when using `-y` flag
- [ ] Interactive prompts still work without `-y` flag
- [ ] ShellCheck passes (no warnings)

### Should Have (Strongly Recommended)
- [ ] Test 3 passes (standalone script with --yes)
- [ ] Test 8 passes (argument parsing)
- [ ] Add GitHub CLI prerequisite check
- [ ] Add GitHub auth verification for non-interactive mode
- [ ] Documentation updated (README mentions -y flag)

### Nice to Have
- [ ] All 10 tests pass
- [ ] Automated test script runs cleanly
- [ ] CI/CD pipeline passes

---

## Test Results Log

Use this section to record test results:

| Test # | Test Name | Status | Date | Notes |
|--------|-----------|--------|------|-------|
| 1 | Non-interactive full setup | ⏳ Pending | | |
| 2 | Interactive mode | ⏳ Pending | | |
| 3 | Standalone --yes | ⏳ Pending | | |
| 4 | Standalone interactive | ⏳ Pending | | |
| 5 | Error handling | ⏳ Pending | | |
| 6 | package-lock.json | ⏳ Pending | | |
| 7 | Output directory | ⏳ Pending | | |
| 8 | Argument parsing | ⏳ Pending | | |
| 9 | Makefile integration | ⏳ Pending | | |
| 10 | CI compatibility | ⏳ Pending | | |

Legend: ✅ Pass | ❌ Fail | ⚠️ Pass with issues | ⏳ Pending | ⏭️ Skipped

---

## Next Steps After Testing

1. **If all tests pass:**
   - Create PR from `fix/github-repo-non-interactive-mode` to `main`
   - Include test results in PR description
   - Tag for review

2. **If critical tests fail:**
   - Fix issues
   - Re-run failed tests
   - Update this document with results

3. **Document known issues:**
   - Create GitHub issues for items in "Known Issues" section
   - Link issues in PR description
   - Plan fixes for future PRs

---

## Appendix: Manual Cleanup

After testing, clean up test resources:

```bash
# List all test GitHub repos
gh repo list damon-houk --limit 100 | grep test-

# Delete test repos
gh repo delete damon-houk/test-ni-full-XXXXX --yes
gh repo delete damon-houk/test-standalone-XXXXX --yes
# ... repeat for all test repos

# Clean up output directory
rm -rf output/TST*
rm -rf output/OUT*
rm -rf output/MAK*

# Note: AWS accounts cannot be easily deleted via CLI
# To close test accounts:
# 1. Go to AWS Console → Organizations
# 2. Find TST_DEV, TST_STAGING, TST_PROD accounts
# 3. Move to root OU or delete if empty
# 4. Or keep for future testing
```