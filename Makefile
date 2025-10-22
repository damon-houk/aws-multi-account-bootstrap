# AWS Multi-Account Bootstrap - Monorepo Makefile
#
# This Makefile provides targets for both v1 (bash) and v2 (Go) implementations.

.PHONY: help test test-bash test-go build build-go clean setup check-prerequisites all

# Default target
help: ## Show this help message
	@echo "AWS Multi-Account Bootstrap - Monorepo"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Version 1 (bash): Stable, maintenance mode"
	@echo "Version 2 (go):   Active development"

# Testing
test: test-bash test-go ## Run all tests (bash + go)

test-bash: ## Run bash v1 tests
	@echo "Running bash tests..."
	@cd bash/tests && ./test-config-simple.sh

test-go: ## Run Go v2 tests
	@echo "Running Go tests..."
	@cd go && go test ./... -race -timeout 30s

# Building
build: build-go ## Build all binaries

build-go: ## Build Go v2 CLI
	@echo "Building Go v2 CLI..."
	@cd go && make build

# Setup
setup-all: ## Setup complete AWS environment (v1 bash script)
	@bash/scripts/setup-complete-project.sh

check-prerequisites: ## Check system prerequisites (v1)
	@bash/scripts/lib/prerequisite-checker.sh

# Cleanup
clean: clean-go ## Clean all build artifacts
	@echo "Cleaning..."

clean-go: ## Clean Go build artifacts
	@cd go && make clean

# Development
dev-go: ## Quick Go development workflow (fmt, vet, test)
	@cd go && make dev

fmt-go: ## Format Go code
	@cd go && make fmt

# Pre-push checks (run BEFORE pushing!)
pre-push: check-structure check-links test ## Run all checks before pushing

check-structure: ## Validate monorepo structure
	@echo "Checking monorepo structure..."
	@bash -c '\
		for file in README.md LICENSE Makefile CLAUDE.md; do \
			[ -f "$$file" ] && echo "✅ $$file" || (echo "❌ Missing: $$file" && exit 1); \
		done; \
		for file in bash/README.md bash/scripts/setup-complete-project.sh go/README.md go/Makefile go/go.mod; do \
			[ -f "$$file" ] && echo "✅ $$file" || (echo "❌ Missing: $$file" && exit 1); \
		done; \
		echo "✅ Structure validated"'

check-links: ## Check markdown links (requires: npm install -g markdown-link-check)
	@echo "Checking markdown links..."
	@if command -v markdown-link-check >/dev/null 2>&1; then \
		find . -name '*.md' -not -path './node_modules/*' -not -path './.git/*' \
		  -exec markdown-link-check {} --config .github/markdown-link-check-config.json \; ; \
	else \
		echo "⚠️  markdown-link-check not installed. Install: npm install -g markdown-link-check"; \
		exit 1; \
	fi

# CI
ci: test build ## Full CI workflow (test + build)

# Convenience targets for v1 (bash)
deploy-dev: ## Deploy to dev environment (v1)
	@bash/scripts/deploy-environment.sh dev

deploy-staging: ## Deploy to staging environment (v1)
	@bash/scripts/deploy-environment.sh staging

deploy-prod: ## Deploy to prod environment (v1)
	@bash/scripts/deploy-environment.sh prod
