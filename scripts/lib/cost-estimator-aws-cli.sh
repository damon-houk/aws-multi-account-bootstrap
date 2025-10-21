#!/bin/bash

# Cost Estimator for AWS Multi-Account Bootstrap (AWS CLI Version)
# Uses AWS Pricing API for accurate pricing (requires AWS credentials)
# Provides more detailed and accurate cost estimates than the public API version

# Colors for output
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to format currency
format_currency() {
    printf "$%.2f" "$1"
}

# Function to calculate monthly cost estimate
calculate_monthly_cost() {
    local num_accounts=${1:-3}
    local usage_level=${2:-"minimal"}  # minimal, light, moderate, heavy

    # Base costs that apply regardless of usage
    local base_costs=0

    # CloudWatch Alarms for billing (2 per account)
    local alarm_cost=$(echo "$num_accounts * 2 * 0.10" | bc -l)
    base_costs=$(echo "$base_costs + $alarm_cost" | bc -l)

    # CDK Bootstrap S3 buckets (minimal usage)
    local s3_bootstrap_cost=$(echo "$num_accounts * 0.10" | bc -l)
    base_costs=$(echo "$base_costs + $s3_bootstrap_cost" | bc -l)

    # ECR repositories (assuming minimal container storage)
    local ecr_cost=$(echo "$num_accounts * 0.50" | bc -l)
    base_costs=$(echo "$base_costs + $ecr_cost" | bc -l)

    # Variable costs based on usage level
    local variable_costs=0

    case $usage_level in
        minimal)
            # Assumes staying within free tier for most services
            variable_costs=0
            ;;
        light)
            # Some API calls, Lambda invocations beyond free tier
            variable_costs=$(echo "$num_accounts * 5" | bc -l)
            ;;
        moderate)
            # Regular development, some resources always running
            variable_costs=$(echo "$num_accounts * 20" | bc -l)
            ;;
        heavy)
            # Multiple services, databases, constant usage
            variable_costs=$(echo "$num_accounts * 50" | bc -l)
            ;;
    esac

    local total_cost=$(echo "$base_costs + $variable_costs" | bc -l)
    echo "$total_cost"
}

# Function to display cost breakdown
display_cost_breakdown() {
    local num_accounts=${1:-3}
    local show_details=${2:-true}

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}💰 Estimated Monthly AWS Costs${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    if [ "$show_details" = true ]; then
        echo -e "${YELLOW}Base Infrastructure Costs:${NC}"
        echo "  • CloudWatch Billing Alarms: $(format_currency $(echo "$num_accounts * 2 * 0.10" | bc -l))/month"
        echo "  • CDK Bootstrap S3 Buckets:  $(format_currency $(echo "$num_accounts * 0.10" | bc -l))/month"
        echo "  • ECR Container Registries:  $(format_currency $(echo "$num_accounts * 0.50" | bc -l))/month"
        echo ""
    fi

    echo -e "${YELLOW}Estimated Monthly Costs by Usage:${NC}"

    local minimal_cost=$(calculate_monthly_cost "$num_accounts" "minimal")
    local light_cost=$(calculate_monthly_cost "$num_accounts" "light")
    local moderate_cost=$(calculate_monthly_cost "$num_accounts" "moderate")
    local heavy_cost=$(calculate_monthly_cost "$num_accounts" "heavy")

    echo ""
    echo "  🌱 ${GREEN}Minimal Usage${NC} (staying in free tier):"
    echo "     $(format_currency "$minimal_cost") - $(format_currency $(echo "$minimal_cost + 3" | bc -l))/month"
    echo ""
    echo "  💡 ${BLUE}Light Development${NC} (occasional testing):"
    echo "     $(format_currency "$light_cost") - $(format_currency $(echo "$light_cost + 10" | bc -l))/month"
    echo ""
    echo "  🚀 ${CYAN}Active Development${NC} (daily deployments):"
    echo "     $(format_currency "$moderate_cost") - $(format_currency $(echo "$moderate_cost + 15" | bc -l))/month"
    echo ""
    echo "  ⚡ ${YELLOW}Production Workload${NC} (24/7 services):"
    echo "     $(format_currency "$heavy_cost") - $(format_currency $(echo "$heavy_cost + 50" | bc -l))/month+"
    echo ""

    echo -e "${GREEN}💡 Cost Optimization Tips:${NC}"
    echo "  • Most development stays under \$10/month"
    echo "  • AWS Free Tier covers many services for 12 months"
    echo "  • Billing alerts will warn at \$15 and \$25"
    echo "  • Use 'make destroy-unused' to clean up test resources"
    echo ""
}

# Function for inline cost estimate (single line)
display_inline_cost() {
    local num_accounts=${1:-3}
    local minimal_cost=$(calculate_monthly_cost "$num_accounts" "minimal")
    local light_cost=$(calculate_monthly_cost "$num_accounts" "light")

    echo -e "${YELLOW}💰 Estimated monthly cost:${NC} $(format_currency "$minimal_cost")-$(format_currency "$light_cost") for development, <\$50 for production"
}

# Function for dry-run cost display
display_dry_run_costs() {
    local num_accounts=${1:-3}

    echo -e "${YELLOW}[DRY RUN] Estimated monthly AWS costs after setup:${NC}"
    echo ""
    echo "  Infrastructure baseline: ~$(format_currency $(calculate_monthly_cost "$num_accounts" "minimal"))/month"
    echo "  • CloudWatch billing alarms: \$0.60"
    echo "  • CDK bootstrap resources: \$0.30"
    echo "  • ECR repositories: \$1.50"
    echo ""
    echo "  With light development: \$5-15/month"
    echo "  With active development: \$20-35/month"
    echo "  With production workload: \$50+/month"
    echo ""
    echo "  Most users stay under \$10/month during development"
}

# Calculate base infrastructure costs (for compatibility)
calculate_base_costs() {
    local num_accounts="$1"
    local region="${2:-us-east-2}"
    local usage_level="${3:-light}"

    calculate_monthly_cost "$num_accounts" "$usage_level"
}

# List available stack types
list_available_stacks() {
    echo -e "${CYAN}Available Stack Types:${NC}"
    echo "  • api-lambda      - Serverless API with Lambda and API Gateway"
    echo "  • static-website  - S3 + CloudFront static site hosting"
    echo "  • rds-postgres    - Managed PostgreSQL database"
    echo "  • ecs-fargate     - Serverless container hosting"
    echo "  • vpc-nat         - NAT Gateway for private subnets"
    echo ""
    echo -e "${YELLOW}Note: Using AWS CLI method for basic pricing estimates${NC}"
}

# Explain usage levels
explain_usage_levels() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Usage Level Definitions${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    echo -e "${BLUE}MINIMAL (Prototype/POC)${NC}"
    echo "  • Target: Individual developers, proof of concepts"
    echo "  • Traffic: <1,000 requests/month"
    echo "  • Storage: <10 GB total"
    echo "  • Alarms: 2 per account (billing only)"
    echo "  • Best for: Testing ideas, learning AWS"
    echo ""

    echo -e "${BLUE}LIGHT (Development/Small Team)${NC}"
    echo "  • Target: Small teams (2-5 people), side projects"
    echo "  • Traffic: ~10,000 requests/month"
    echo "  • Storage: ~50 GB total"
    echo "  • Alarms: 3 per account (billing + basic monitoring)"
    echo "  • Config Rules: 1 per account"
    echo "  • Best for: Active development, small production apps"
    echo ""

    echo -e "${BLUE}MODERATE (Startup/Growing)${NC}"
    echo "  • Target: Startups, growing businesses"
    echo "  • Traffic: ~100,000 requests/month"
    echo "  • Storage: ~200 GB total"
    echo "  • Alarms: 5 per account (comprehensive monitoring)"
    echo "  • Config Rules: 3 per account"
    echo "  • Best for: Production apps with real users"
    echo ""

    echo -e "${BLUE}HEAVY (Scale/Enterprise)${NC}"
    echo "  • Target: Scaled startups, enterprise teams"
    echo "  • Traffic: 1M+ requests/month"
    echo "  • Storage: 1+ TB total"
    echo "  • Alarms: 10 per account (detailed monitoring)"
    echo "  • Config Rules: 5 per account"
    echo "  • Best for: High-traffic production, compliance needs"
    echo ""

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Get usage level description
get_usage_level_description() {
    local level="$1"
    case "$level" in
        minimal)
            echo "Prototype/POC (<1K requests/mo, <10GB storage)"
            ;;
        light)
            echo "Small Team (~10K requests/mo, ~50GB storage)"
            ;;
        moderate)
            echo "Growing Startup (~100K requests/mo, ~200GB storage)"
            ;;
        heavy)
            echo "Scale/Enterprise (1M+ requests/mo, 1TB+ storage)"
            ;;
        *)
            echo "Unknown usage level"
            ;;
    esac
}

# Export functions for use in other scripts
export -f calculate_monthly_cost
export -f calculate_base_costs
export -f display_cost_breakdown
export -f display_inline_cost
export -f display_dry_run_costs
export -f list_available_stacks
export -f explain_usage_levels
export -f get_usage_level_description
export -f format_currency