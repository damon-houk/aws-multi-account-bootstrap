# Makefile for AWS Multi-Account Project Setup
# Usage: make help

.PHONY: help
help: ## Show this help message
	@echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
	@echo '  AWS Multi-Account Project Setup'
	@echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
	@echo ''
	@echo 'Usage:'
	@echo '  make <target> [VARS]'
	@echo ''
	@echo 'Targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ''
	@echo 'Required Variables:'
	@echo '  PROJECT_CODE  - 3-letter project identifier (e.g., TPA)'
	@echo '  EMAIL_PREFIX  - Email without domain (e.g., damon.o.houk)'
	@echo '  OU_ID         - Organizational Unit ID (e.g., ou-813y-xxxxxxxx)'
	@echo '  GITHUB_ORG    - GitHub organization or username'
	@echo '  REPO_NAME     - GitHub repository name'
	@echo '  EMAIL         - Email for billing alerts (optional, defaults to EMAIL_PREFIX@gmail.com)'
	@echo ''
	@echo 'Examples:'
	@echo '  make setup-all PROJECT_CODE=TPA EMAIL_PREFIX=damon.o.houk OU_ID=ou-813y-xxx GITHUB_ORG=myorg REPO_NAME=myrepo'
	@echo '  make create-accounts PROJECT_CODE=TPA EMAIL_PREFIX=damon.o.houk OU_ID=ou-813y-xxx'
	@echo '  make bootstrap PROJECT_CODE=TPA'
	@echo ''

.PHONY: check-vars
check-vars: ## Check if required variables are set
	@if [ -z "$(PROJECT_CODE)" ]; then echo "ERROR: PROJECT_CODE is required"; exit 1; fi
	@if [ -z "$(EMAIL_PREFIX)" ]; then echo "ERROR: EMAIL_PREFIX is required"; exit 1; fi

.PHONY: check-all-vars
check-all-vars: check-vars ## Check all variables including GitHub
	@if [ -z "$(OU_ID)" ]; then echo "ERROR: OU_ID is required"; exit 1; fi
	@if [ -z "$(GITHUB_ORG)" ]; then echo "ERROR: GITHUB_ORG is required"; exit 1; fi
	@if [ -z "$(REPO_NAME)" ]; then echo "ERROR: REPO_NAME is required"; exit 1; fi

.PHONY: make-executable
make-executable: ## Make all scripts executable
	@echo "Making scripts executable..."
	@chmod +x *.sh 2>/dev/null || true
	@echo "✓ Done"

.PHONY: create-accounts
create-accounts: check-vars make-executable ## Create AWS accounts (requires OU_ID)
	@if [ -z "$(OU_ID)" ]; then echo "ERROR: OU_ID is required"; exit 1; fi
	@./create-project-accounts.sh $(PROJECT_CODE) $(EMAIL_PREFIX) $(OU_ID)

.PHONY: bootstrap
bootstrap: check-vars make-executable ## Bootstrap CDK in all accounts
	@./bootstrap-cdk.sh $(PROJECT_CODE)

.PHONY: setup-cicd
setup-cicd: check-all-vars make-executable ## Set up GitHub Actions CI/CD
	@./setup-github-cicd.sh $(PROJECT_CODE) $(GITHUB_ORG) $(REPO_NAME)

.PHONY: setup-github
setup-github: check-all-vars make-executable ## Create and configure GitHub repository
	@./setup-github-repo.sh $(PROJECT_CODE) $(GITHUB_ORG) $(REPO_NAME)

.PHONY: setup-billing
setup-billing: check-vars make-executable ## Set up billing alerts and budgets
	@if [ -z "$(EMAIL)" ]; then \
		./setup-billing-alerts.sh $(PROJECT_CODE); \
	else \
		./setup-billing-alerts.sh $(PROJECT_CODE) $(EMAIL); \
	fi

.PHONY: setup-all
setup-all: check-all-vars make-executable ## Complete setup (accounts + CDK + CI/CD + GitHub + billing)
	@./setup-complete-project.sh $(PROJECT_CODE) $(EMAIL_PREFIX) $(OU_ID) $(GITHUB_ORG) $(REPO_NAME)

.PHONY: install
install: ## Install npm dependencies
	@echo "Installing dependencies..."
	@npm install
	@echo "✓ Dependencies installed"

.PHONY: build
build: ## Build TypeScript code
	@npm run build

.PHONY: test
test: ## Run tests
	@npm test

.PHONY: synth
synth: ## Synthesize CDK stacks
	@npm run cdk synth

.PHONY: diff
diff: ## Show diff between deployed and local stacks
	@npm run cdk diff

.PHONY: deploy-dev
deploy-dev: ## Deploy to dev environment
	@ENV=dev npm run cdk deploy -- --all

.PHONY: deploy-staging
deploy-staging: ## Deploy to staging environment
	@ENV=staging npm run cdk deploy -- --all

.PHONY: deploy-prod
deploy-prod: ## Deploy to production environment (use with caution!)
	@ENV=prod npm run cdk deploy -- --all

.PHONY: destroy-dev
destroy-dev: ## Destroy dev environment (use with caution!)
	@ENV=dev npm run cdk destroy -- --all

.PHONY: list-accounts
list-accounts: ## List all AWS accounts in organization
	@aws organizations list-accounts --output table

.PHONY: account-info
account-info: check-vars ## Show account information for project
	@echo "Fetching account information for $(PROJECT_CODE)..."
	@aws cloudformation describe-stacks \
		--stack-name "$(PROJECT_CODE)-Accounts" \
		--query "Stacks[0].Outputs" \
		--output table

.PHONY: clean
clean: ## Clean build artifacts
	@echo "Cleaning build artifacts..."
	@rm -rf node_modules cdk.out dist build *.js *.d.ts
	@echo "✓ Clean complete"

.PHONY: fresh-install
fresh-install: clean install ## Clean install of dependencies
	@echo "✓ Fresh install complete"

.PHONY: git-setup
git-setup: ## Initialize git repository
	@if [ -d ".git" ]; then \
		echo "Git repository already exists"; \
	else \
		git init; \
		git add .; \
		git commit -m "Initial commit"; \
		echo "✓ Git repository initialized"; \
	fi

.PHONY: create-branches
create-branches: ## Create develop branch
	@git checkout -b develop 2>/dev/null || git checkout develop
	@echo "✓ Develop branch ready"

.PHONY: show-summary
show-summary: ## Show CI/CD setup summary
	@if [ -f "CICD_SETUP_SUMMARY.md" ]; then \
		cat CICD_SETUP_SUMMARY.md; \
	else \
		echo "ERROR: CICD_SETUP_SUMMARY.md not found. Run 'make setup-cicd' first"; \
	fi

.PHONY: show-github-summary
show-github-summary: ## Show GitHub setup summary
	@if [ -f "GITHUB_SETUP_SUMMARY.md" ]; then \
		cat GITHUB_SETUP_SUMMARY.md; \
	else \
		echo "ERROR: GITHUB_SETUP_SUMMARY.md not found. Run 'make setup-github' first"; \
	fi

.PHONY: show-billing-summary
show-billing-summary: ## Show billing alerts summary
	@if [ -f "BILLING_ALERTS_SUMMARY.md" ]; then \
		cat BILLING_ALERTS_SUMMARY.md; \
	else \
		echo "ERROR: BILLING_ALERTS_SUMMARY.md not found. Run 'make setup-billing' first"; \
	fi

.PHONY: check-prerequisites
check-prerequisites: ## Check if all required tools are installed
	@echo "Checking prerequisites..."
	@command -v aws >/dev/null 2>&1 && echo "✓ AWS CLI" || echo "✗ AWS CLI (install required)"
	@command -v cdk >/dev/null 2>&1 && echo "✓ AWS CDK" || echo "✗ AWS CDK (npm install -g aws-cdk)"
	@command -v jq >/dev/null 2>&1 && echo "✓ jq" || echo "✗ jq (brew install jq)"
	@command -v node >/dev/null 2>&1 && echo "✓ Node.js" || echo "✗ Node.js"
	@command -v git >/dev/null 2>&1 && echo "✓ Git" || echo "✗ Git"
	@command -v gh >/dev/null 2>&1 && echo "✓ GitHub CLI" || echo "✗ GitHub CLI (brew install gh / winget install GitHub.cli)"
	@echo ""
	@aws sts get-caller-identity >/dev/null 2>&1 && echo "✓ AWS authenticated" || echo "✗ AWS not authenticated (run: aws sso login)"
	@gh auth status >/dev/null 2>&1 && echo "✓ GitHub authenticated" || echo "✗ GitHub not authenticated (run: gh auth login)"

.PHONY: setup-branch-protection
setup-branch-protection: ## Setup GitHub branch protection rules (requires gh CLI)
	@if ! command -v gh >/dev/null 2>&1; then \
		echo "ERROR: GitHub CLI (gh) is not installed"; \
		echo "Install with: winget install --id GitHub.cli (Windows) or brew install gh (macOS)"; \
		exit 1; \
	fi
	@if ! gh auth status >/dev/null 2>&1; then \
		echo "ERROR: Not authenticated with GitHub"; \
		echo "Run: gh auth login"; \
		exit 1; \
	fi
	@bash scripts/setup-branch-protection.sh

.PHONY: watch
watch: ## Watch for changes and auto-rebuild
	@npm run watch

.PHONY: lint
lint: ## Run linter
	@npm run lint

.PHONY: lint-scripts
lint-scripts: ## Lint bash scripts with ShellCheck (optional locally, required in CI)
	@echo "Linting bash scripts..."
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck scripts/*.sh && echo "✓ ShellCheck passed"; \
	else \
		echo "⚠️  ShellCheck not installed (optional for local development)"; \
		echo "   Install: brew install shellcheck (Mac) | apt install shellcheck (Linux)"; \
		echo "   CI will run ShellCheck automatically"; \
		echo "✓ Skipped (not required locally)"; \
	fi

.PHONY: check-links
check-links: ## Check markdown links
	@echo "Checking markdown links..."
	@if [ -f "package.json" ]; then \
		npm run check:links; \
	else \
		npx markdown-link-check@3.11.2 README.md -c .github/markdown-link-check-config.json && \
		npx markdown-link-check@3.11.2 docs/*.md -c .github/markdown-link-check-config.json && \
		echo "✓ Link check passed"; \
	fi

.PHONY: validate-structure
validate-structure: ## Validate project structure
	@echo "Validating project structure..."
	@for file in README.md LICENSE Makefile scripts/setup-complete-project.sh scripts/create-project-accounts.sh scripts/bootstrap-cdk.sh scripts/setup-github-cicd.sh scripts/setup-github-repo.sh scripts/setup-billing-alerts.sh; do \
		if [ ! -f "$$file" ]; then \
			echo "✗ Missing: $$file"; \
			exit 1; \
		else \
			echo "✓ Found: $$file"; \
		fi \
	done
	@echo "✓ Structure validation passed"

.PHONY: ci-local
ci-local: ## Run all CI checks locally (before pushing)
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  Running CI Checks Locally"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@echo "1️⃣  Linting bash scripts..."
	@$(MAKE) lint-scripts
	@echo ""
	@echo "2️⃣  Checking markdown links..."
	@$(MAKE) check-links
	@echo ""
	@echo "3️⃣  Validating project structure..."
	@$(MAKE) validate-structure
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  ✅ All CI checks passed!"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@echo "You can now safely push your changes:"
	@echo "  git push origin $$(git branch --show-current)"
	@echo ""

.DEFAULT_GOAL := help