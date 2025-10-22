.PHONY: help test test-verbose test-coverage build clean fmt vet lint all

# Default target
help: ## Show this help message
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

all: fmt vet test build ## Run fmt, vet, test, and build

test: ## Run tests
	@echo "Running tests..."
	@go test ./... -race -timeout 30s

test-verbose: ## Run tests with verbose output
	@echo "Running tests (verbose)..."
	@go test ./... -v -race -timeout 30s

test-coverage: ## Run tests with coverage
	@echo "Running tests with coverage..."
	@go test ./... -race -coverprofile=coverage.out -timeout 30s
	@go tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report: coverage.html"

build: ## Build the CLI binary
	@echo "Building aws-bootstrap CLI..."
	@go build -o bin/aws-bootstrap ./cmd/aws-bootstrap
	@echo "Binary created: bin/aws-bootstrap"

clean: ## Remove build artifacts and test coverage files
	@echo "Cleaning..."
	@rm -rf bin/
	@rm -f coverage.out coverage.html
	@echo "Done."

fmt: ## Format Go code
	@echo "Formatting code..."
	@go fmt ./...

vet: ## Run go vet
	@echo "Running go vet..."
	@go vet ./...

lint: ## Run golangci-lint (if installed)
	@echo "Running golangci-lint..."
	@if command -v golangci-lint >/dev/null 2>&1; then \
		golangci-lint run; \
	else \
		echo "golangci-lint not installed. Install: https://golangci-lint.run/welcome/install/"; \
	fi

mod-tidy: ## Tidy Go modules
	@echo "Tidying modules..."
	@go mod tidy

mod-verify: ## Verify Go modules
	@echo "Verifying modules..."
	@go mod verify

# Development workflow
dev: fmt vet test ## Quick development workflow (fmt, vet, test)

# CI workflow
ci: mod-verify fmt vet test-coverage build ## Full CI workflow
