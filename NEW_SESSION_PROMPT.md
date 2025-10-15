# Quick Start Prompt for New Claude Code Session

## 📌 Copy and paste this into your new Claude Code session:

---

**Prompt:**

```
I'm continuing work on the aws-multi-account-bootstrap project. We were about to run an end-to-end test of the v1.0 MVP before building v1.1 features.

Current status:
- v1.2.0 was just released
- All v1.0 features are implemented
- CI/CD pipeline is working (tested with CDK synth)
- We need to run a full E2E test with real AWS accounts

Please read E2E_TEST_PLAN.md and help me execute the test plan step by step.

Context from previous session:
- We're on Windows
- AWS CLI is installed (v2.13.7)
- The MVP code is complete but hasn't been tested end-to-end yet
- After successful E2E test, we'll start building v1.1 features (see ROADMAP.md)

Let's start with Phase 1: Prerequisites Verification from the E2E test plan.
```

---

## Alternative Shorter Prompt:

```
Continue E2E testing for aws-multi-account-bootstrap. Read E2E_TEST_PLAN.md and let's start testing the MVP end-to-end. We're on Phase 1: Prerequisites Verification.
```

---

## 📂 Files to Reference:

1. **E2E_TEST_PLAN.md** - Complete test plan (just created)
2. **docs/ROADMAP.md** - Feature roadmap showing v1.0 vs v1.1
3. **README.md** - Main documentation
4. **CLAUDE.md** - Project instructions for Claude

---

## 🎯 What We're Testing:

Testing the complete workflow:
1. Create 3 AWS accounts (dev/staging/prod)
2. Bootstrap CDK in all accounts
3. Create GitHub repository with CI/CD
4. Set up billing alerts
5. Deploy a test stack
6. Verify semantic release works

---

## Expected Outcome:

- ✅ All tests pass → Mark v1.0 production-ready, start v1.1
- ❌ Tests fail → Document issues, fix them, retest

---

## Current Machine: Windows
- AWS CLI: v2.13.7 ✓
- Node.js: (to be verified)
- CDK: (to be verified)
- GitHub CLI: (to be verified)
- jq: (to be verified)

---

## Test Parameters (suggested):
- PROJECT_CODE: `TST` or `E2E`
- EMAIL_PREFIX: `your.email`
- OU_ID: `ou-xxxx-xxxxxxxx` (create in AWS Console first)
- GITHUB_ORG: `your-github-username`
- REPO_NAME: `test-aws-bootstrap`

---

**Good luck with the testing!**
