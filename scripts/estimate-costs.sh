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

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the cost estimator
source "$SCRIPT_DIR/lib/cost-estimator-v2.sh"

# Default values
NUM_ACCOUNTS=3
USAGE_LEVEL="light"
STACKS=""
REGION="${AWS_DEFAULT_REGION:-us-east-1}"
UPDATE_CACHE=false

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
            display_stack_options
            exit 0
            ;;
        --update-cache)
            UPDATE_CACHE=true
            shift
            ;;
        --help|-h)
            echo "AWS Multi-Account Bootstrap - Cost Estimator"
            echo ""
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --accounts NUM       Number of AWS accounts (default: 3)"
            echo "  --usage LEVEL        Usage level: minimal, light, moderate, heavy (default: light)"
            echo "  --stacks STACKS      Comma-separated list of stack types to estimate"
            echo "  --region REGION      AWS region (default: us-east-1)"
            echo "  --list-stacks        List available stack types"
            echo "  --update-cache       Force update pricing cache"
            echo "  --help               Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0"
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
display_cost_breakdown_real "$NUM_ACCOUNTS" true "$STACKS"

# Show how to customize
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Customize this estimate:${NC}"
echo "  • Different number of accounts: --accounts 5"
echo "  • Different usage level: --usage moderate"
echo "  • Add specific stacks: --stacks api-lambda,rds-postgres"
echo "  • Different region: --region eu-west-1"
echo "  • See available stacks: --list-stacks"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"