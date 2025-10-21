#!/bin/bash

# Standalone cost estimation tool
# Usage: ./estimate-costs.sh [options]
#
# Options:
#   --accounts NUM       Number of AWS accounts (default: 3)
#   --usage LEVEL        Usage level: minimal, light, moderate, heavy (default: light)
#   --stacks STACKS      Comma-separated list of stack types to estimate
#   --region REGION      AWS region (default: us-east-1)
#   --list-stacks        List available stack types
#   --update-cache       Force update pricing cache
#   --help               Show this help message

set -e

# Get script directory (save it before sourcing other scripts)
MAIN_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$MAIN_SCRIPT_DIR"

# Source the cost estimator
source "$SCRIPT_DIR/lib/cost-estimator.sh"

# Default values
NUM_ACCOUNTS=3
USAGE_LEVEL="light"
STACKS=""
REGION="${AWS_DEFAULT_REGION:-us-east-2}"
UPDATE_CACHE=false
PRICING_METHOD="${COST_ESTIMATOR_METHOD:-public}"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --accounts)
            NUM_ACCOUNTS="$2"
            shift 2
            ;;
        --usage)
            USAGE_LEVEL="$2"
            shift 2
            ;;
        --stacks)
            STACKS="$2"
            shift 2
            ;;
        --region)
            REGION="$2"
            export AWS_DEFAULT_REGION="$REGION"
            shift 2
            ;;
        --list-stacks)
            list_available_stacks
            exit 0
            ;;
        --explain-usage)
            explain_usage_levels
            exit 0
            ;;
        --update-cache)
            UPDATE_CACHE=true
            shift
            ;;
        --method)
            PRICING_METHOD="$2"
            export COST_ESTIMATOR_METHOD="$PRICING_METHOD"
            shift 2
            ;;
        --interactive|-i)
            # Launch interactive mode
            exec "$MAIN_SCRIPT_DIR/estimate-costs-interactive.sh"
            ;;
        --help|-h)
            echo "AWS Multi-Account Bootstrap - Cost Estimator"
            echo ""
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --interactive, -i    Launch interactive mode"
            echo "  --accounts NUM       Number of AWS accounts (default: 3)"
            echo "  --usage LEVEL        Usage level: minimal, light, moderate, heavy (default: light)"
            echo "  --stacks STACKS      Comma-separated list of stack types to estimate"
            echo "  --region REGION      AWS region (default: us-east-2)"
            echo "  --list-stacks        List available stack types"
            echo "  --explain-usage      Show detailed usage level definitions"
            echo "  --update-cache       Force update pricing cache"
            echo "  --method METHOD      Pricing method: public, aws-cli, auto (default: public)"
            echo "  --help               Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 --interactive              # Launch interactive mode"
            echo "  $0                            # Basic estimate with defaults"
            echo "  $0 --accounts 3 --usage moderate"
            echo "  $0 --stacks api-lambda,static-website"
            echo "  $0 --region eu-west-1 --accounts 5"
            echo ""
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Clear cache if requested
if [ "$UPDATE_CACHE" = true ]; then
    echo "Clearing pricing cache..."
    rm -rf "${HOME}/.aws-bootstrap/pricing-cache"
    echo "Cache cleared."
    echo ""
fi

# Display the cost breakdown
display_cost_breakdown "$NUM_ACCOUNTS" true "$STACKS" "$REGION" "$USAGE_LEVEL"

# Show how to customize
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Customize this estimate:${NC}"
echo "  • Different number of accounts: --accounts 5"
echo "  • Different usage level: --usage moderate"
echo "  • Add specific stacks: --stacks api-lambda,rds-postgres"
echo "  • Different region: --region eu-west-1"
echo "  • See available stacks: --list-stacks"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"