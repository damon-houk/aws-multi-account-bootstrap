#!/bin/bash

# Cost Estimator for AWS Multi-Account Bootstrap
# Provides rough cost estimates for the infrastructure created

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

# Export functions for use in other scripts
export -f calculate_monthly_cost
export -f display_cost_breakdown
export -f display_inline_cost
export -f display_dry_run_costs
export -f format_currency