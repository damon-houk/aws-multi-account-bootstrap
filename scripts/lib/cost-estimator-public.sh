#!/bin/bash

# Cost Estimator v3 - Clean, Extensible Design
# Uses AWS Bulk Pricing API (public, no credentials required)
# Default region: us-east-2 (typically same pricing as us-east-1)

# Colors for output
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
DEFAULT_REGION="us-east-2"
CACHE_DIR="${HOME}/.aws-bootstrap/pricing-cache"
CACHE_EXPIRY=604800  # 7 days in seconds (prices change rarely)

# Initialize cache directory
init_pricing_cache() {
    mkdir -p "$CACHE_DIR"
}

# Get current region (default to us-east-2)
get_pricing_region() {
    echo "${AWS_DEFAULT_REGION:-$DEFAULT_REGION}"
}

# Check if cache file is valid
is_pricing_cache_valid() {
    local cache_file="$1"
    [ ! -f "$cache_file" ] && return 1

    local file_age
    if command -v stat >/dev/null 2>&1; then
        file_age=$(($(date +%s) - $(stat -f%m "$cache_file" 2>/dev/null || stat -c%Y "$cache_file" 2>/dev/null || echo 0)))
    else
        # If stat is not available, invalidate cache
        return 1
    fi

    [ $file_age -gt $CACHE_EXPIRY ] && return 1
    return 0
}

# Download pricing data for a service
download_pricing_data() {
    local service="$1"
    local cache_file="$CACHE_DIR/${service}_pricing.json"

    # Check cache
    if is_pricing_cache_valid "$cache_file"; then
        cat "$cache_file"
        return 0
    fi

    # Download from public API
    local url="https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/${service}/current/index.json"
    local pricing_data

    echo -e "${YELLOW}Fetching latest pricing data for ${service}...${NC}" >&2
    pricing_data=$(curl -s "$url" 2>/dev/null)

    if [ $? -eq 0 ] && [ -n "$pricing_data" ]; then
        echo "$pricing_data" > "$cache_file"
        echo "$pricing_data"
    else
        echo "{}"
    fi
}

# Generic function to lookup any AWS service price
lookup_aws_price() {
    local service="$1"           # e.g., "AmazonCloudWatch"
    local product_family="$2"    # e.g., "Alarm"
    local region="$3"            # e.g., "us-east-2"
    local usage_filter="$4"      # Optional: filter by usage type

    local pricing_data
    pricing_data=$(download_pricing_data "$service")

    # Find matching SKU
    local sku
    if [ -n "$usage_filter" ]; then
        sku=$(echo "$pricing_data" | jq -r --arg region "$region" --arg family "$product_family" --arg usage "$usage_filter" '
            .products | to_entries[] |
            select(.value.productFamily == $family and
                   .value.attributes.regionCode == $region and
                   (.value.attributes.usagetype | contains($usage))) |
            .key' 2>/dev/null | head -1)
    else
        sku=$(echo "$pricing_data" | jq -r --arg region "$region" --arg family "$product_family" '
            .products | to_entries[] |
            select(.value.productFamily == $family and
                   .value.attributes.regionCode == $region) |
            .key' 2>/dev/null | head -1)
    fi

    # Get price using SKU
    if [ -n "$sku" ] && [ "$sku" != "null" ]; then
        echo "$pricing_data" | jq -r --arg sku "$sku" '
            .terms.OnDemand[$sku] |
            to_entries[0].value.priceDimensions |
            to_entries[0].value.pricePerUnit.USD' 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Calculate base infrastructure costs
calculate_base_costs() {
    local num_accounts="$1"
    local region="$2"
    local usage_level="$3"

    # Get current prices
    local alarm_price=$(lookup_aws_price "AmazonCloudWatch" "Alarm" "$region" "AlarmMonitorUsage")
    local config_price=$(lookup_aws_price "AWSConfig" "Management Tools - AWS Config Rules" "$region" "ConfigRule")

    # Convert to numbers (handle empty/null values)
    alarm_price=${alarm_price:-0}
    config_price=${config_price:-0}

    # Base calculation
    local alarms_per_account=2  # Budget alarm + anomaly detector
    local config_rules_per_account=0  # Start with 0, add based on usage

    case "$usage_level" in
        minimal)
            alarms_per_account=2
            config_rules_per_account=0
            ;;
        light)
            alarms_per_account=3
            config_rules_per_account=1
            ;;
        moderate)
            alarms_per_account=5
            config_rules_per_account=3
            ;;
        heavy)
            alarms_per_account=10
            config_rules_per_account=5
            ;;
    esac

    local total_alarms=$((num_accounts * alarms_per_account))
    local total_config_rules=$((num_accounts * config_rules_per_account))

    # Use awk for floating point math (more portable than bc)
    local alarm_cost=$(awk "BEGIN {printf \"%.2f\", $alarm_price * $total_alarms}")
    local config_cost=$(awk "BEGIN {printf \"%.2f\", $config_price * $total_config_rules}")

    awk "BEGIN {printf \"%.2f\", $alarm_cost + $config_cost}"
}

# Stack cost definitions - Extensible design
# Each stack is a function that returns monthly cost estimate
estimate_stack_cost() {
    local stack_name="$1"
    local region="$2"
    local usage_level="${3:-light}"

    case "$stack_name" in
        "api-lambda")
            # Lambda: 1M requests free tier, then $0.20 per 1M
            # API Gateway: $3.50 per million requests
            case "$usage_level" in
                minimal) echo "0" ;;      # Within free tier
                light) echo "5" ;;        # ~1M requests/month
                moderate) echo "35" ;;    # ~10M requests/month
                heavy) echo "350" ;;      # ~100M requests/month
            esac
            ;;

        "static-website")
            # S3: $0.023 per GB storage, CloudFront: $0.085 per GB transfer
            case "$usage_level" in
                minimal) echo "1" ;;      # 10GB storage, 10GB transfer
                light) echo "5" ;;        # 50GB storage, 50GB transfer
                moderate) echo "25" ;;    # 200GB storage, 200GB transfer
                heavy) echo "100" ;;      # 1TB storage, 1TB transfer
            esac
            ;;

        "rds-postgres")
            # RDS t3.micro: ~$13/month, storage: $0.115 per GB
            case "$usage_level" in
                minimal) echo "15" ;;     # t3.micro, 20GB
                light) echo "30" ;;       # t3.small, 50GB
                moderate) echo "120" ;;   # t3.medium, 100GB
                heavy) echo "500" ;;      # t3.large, 500GB
            esac
            ;;

        "ecs-fargate")
            # Fargate: $0.04048 per vCPU hour, $0.004445 per GB hour
            case "$usage_level" in
                minimal) echo "10" ;;     # 0.25 vCPU, 0.5GB, 1 task
                light) echo "30" ;;       # 0.5 vCPU, 1GB, 1 task
                moderate) echo "150" ;;   # 1 vCPU, 2GB, 3 tasks
                heavy) echo "600" ;;      # 2 vCPU, 4GB, 10 tasks
            esac
            ;;

        "vpc-nat")
            # NAT Gateway: $0.045 per hour + $0.045 per GB
            echo "35"  # Base cost for single NAT gateway
            ;;

        *)
            # Unknown stack - return 0 but log
            echo "0"
            ;;
    esac
}

# List available stack types
list_available_stacks() {
    echo -e "${CYAN}Available Stack Types:${NC}"
    echo "  • api-lambda      - Serverless API with Lambda and API Gateway"
    echo "  • static-website  - S3 + CloudFront static site hosting"
    echo "  • rds-postgres    - Managed PostgreSQL database"
    echo "  • ecs-fargate     - Serverless container hosting"
    echo "  • vpc-nat         - NAT Gateway for private subnets"
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

# Format currency
format_currency() {
    printf "\$%.2f" "$1"
}

# Display comprehensive cost breakdown
display_cost_breakdown() {
    local num_accounts="${1:-3}"
    local show_details="${2:-true}"
    local additional_stacks="${3:-}"
    local region="${4:-$(get_pricing_region)}"
    local usage_level="${5:-light}"

    init_pricing_cache

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}💰 AWS Multi-Account Bootstrap - Cost Estimate${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${BLUE}Configuration:${NC}"
    echo "  • Accounts: $num_accounts"
    echo "  • Region: $region"
    echo "  • Selected Usage: ${GREEN}$usage_level${NC} - $(get_usage_level_description "$usage_level")"
    echo ""

    # Show comparison across all usage levels
    echo -e "${BLUE}Cost Comparison Across Usage Levels:${NC}"
    for level in minimal light moderate heavy; do
        local level_base=$(calculate_base_costs "$num_accounts" "$region" "$level")
        local level_total=$level_base

        if [ -n "$additional_stacks" ]; then
            IFS=',' read -ra STACKS <<< "$additional_stacks"
            for stack in "${STACKS[@]}"; do
                stack=$(echo "$stack" | xargs)
                local stack_cost=$(estimate_stack_cost "$stack" "$region" "$level")
                level_total=$(awk "BEGIN {printf \"%.2f\", $level_total + $stack_cost}")
            done
        fi

        local level_desc=$(get_usage_level_description "$level")
        if [ "$level" == "$usage_level" ]; then
            echo -e "  ${GREEN}→ $level: $(format_currency "$level_total")/month${NC} - $level_desc"
        else
            echo "  • $level: $(format_currency "$level_total")/month - $level_desc"
        fi
    done
    echo ""

    # Now show detailed breakdown for selected level
    echo -e "${BLUE}Detailed Breakdown for ${GREEN}${usage_level}${BLUE} usage:${NC}"

    # Base infrastructure costs
    local base_cost=$(calculate_base_costs "$num_accounts" "$region" "$usage_level")

    # Get individual component costs
    local alarm_price=$(lookup_aws_price "AmazonCloudWatch" "Alarm" "$region" "AlarmMonitorUsage")
    local config_price=$(lookup_aws_price "AWSConfig" "Management Tools - AWS Config Rules" "$region" "ConfigRule")

    alarm_price=${alarm_price:-0}
    config_price=${config_price:-0}

    # Calculate based on usage level
    local alarms_per_account=3
    local config_rules_per_account=1

    case "$usage_level" in
        minimal)
            alarms_per_account=2
            config_rules_per_account=0
            ;;
        light)
            alarms_per_account=3
            config_rules_per_account=1
            ;;
        moderate)
            alarms_per_account=5
            config_rules_per_account=3
            ;;
        heavy)
            alarms_per_account=10
            config_rules_per_account=5
            ;;
    esac

    local total_alarms=$((num_accounts * alarms_per_account))
    local total_config_rules=$((num_accounts * config_rules_per_account))

    local alarm_cost=$(awk "BEGIN {printf \"%.2f\", $alarm_price * $total_alarms}")
    local config_cost=$(awk "BEGIN {printf \"%.2f\", $config_price * $total_config_rules}")

    echo "  Base Infrastructure:"
    echo "    • CloudWatch Alarms ($total_alarms @ \$$alarm_price): $(format_currency "$alarm_cost")/month"
    if [ "$config_rules_per_account" -gt 0 ]; then
        echo "    • Config Rules ($total_config_rules @ \$$config_price): $(format_currency "$config_cost")/month"
    fi
    echo "    • GitHub Actions: \$0.00 (free tier)"
    echo "    • CloudTrail: \$0.00 (first trail free)"

    local total_cost=$base_cost

    # Additional stacks breakdown
    if [ -n "$additional_stacks" ]; then
        echo ""
        echo "  Additional Services:"
        IFS=',' read -ra STACKS <<< "$additional_stacks"
        for stack in "${STACKS[@]}"; do
            stack=$(echo "$stack" | xargs)  # Trim whitespace
            local stack_cost=$(estimate_stack_cost "$stack" "$region" "$usage_level")
            total_cost=$(awk "BEGIN {printf \"%.2f\", $total_cost + $stack_cost}")

            # Add details for each stack type
            case "$stack" in
                "api-lambda")
                    case "$usage_level" in
                        minimal) echo "    • API + Lambda (free tier): $(format_currency "$stack_cost")/month" ;;
                        light) echo "    • API + Lambda (~1M requests): $(format_currency "$stack_cost")/month" ;;
                        moderate) echo "    • API + Lambda (~10M requests): $(format_currency "$stack_cost")/month" ;;
                        heavy) echo "    • API + Lambda (~100M requests): $(format_currency "$stack_cost")/month" ;;
                    esac
                    ;;
                "static-website")
                    case "$usage_level" in
                        minimal) echo "    • Static Site (10GB/10GB transfer): $(format_currency "$stack_cost")/month" ;;
                        light) echo "    • Static Site (50GB/50GB transfer): $(format_currency "$stack_cost")/month" ;;
                        moderate) echo "    • Static Site (200GB/200GB transfer): $(format_currency "$stack_cost")/month" ;;
                        heavy) echo "    • Static Site (1TB/1TB transfer): $(format_currency "$stack_cost")/month" ;;
                    esac
                    ;;
                "rds-postgres")
                    case "$usage_level" in
                        minimal) echo "    • RDS PostgreSQL (t3.micro, 20GB): $(format_currency "$stack_cost")/month" ;;
                        light) echo "    • RDS PostgreSQL (t3.small, 50GB): $(format_currency "$stack_cost")/month" ;;
                        moderate) echo "    • RDS PostgreSQL (t3.medium, 100GB): $(format_currency "$stack_cost")/month" ;;
                        heavy) echo "    • RDS PostgreSQL (t3.large, 500GB): $(format_currency "$stack_cost")/month" ;;
                    esac
                    ;;
                "ecs-fargate")
                    case "$usage_level" in
                        minimal) echo "    • ECS Fargate (0.25 vCPU, 0.5GB, 1 task): $(format_currency "$stack_cost")/month" ;;
                        light) echo "    • ECS Fargate (0.5 vCPU, 1GB, 1 task): $(format_currency "$stack_cost")/month" ;;
                        moderate) echo "    • ECS Fargate (1 vCPU, 2GB, 3 tasks): $(format_currency "$stack_cost")/month" ;;
                        heavy) echo "    • ECS Fargate (2 vCPU, 4GB, 10 tasks): $(format_currency "$stack_cost")/month" ;;
                    esac
                    ;;
                "vpc-nat")
                    echo "    • NAT Gateway (1 instance): $(format_currency "$stack_cost")/month"
                    ;;
                *)
                    echo "    • $stack: $(format_currency "$stack_cost")/month"
                    ;;
            esac
        done
    fi
    echo ""

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}Total for $usage_level usage: $(format_currency "$total_cost")/month${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # Add notes
    echo ""
    echo -e "${YELLOW}Notes:${NC}"
    echo "  • Prices based on $region region"
    echo "  • Includes only resources created by this tool"
    echo "  • Actual costs may vary based on usage patterns"
    echo "  • Free tier benefits applied where applicable"
}

# Display inline cost during setup
display_inline_cost() {
    local num_accounts="${1:-3}"
    local region="${2:-$(get_pricing_region)}"

    init_pricing_cache
    local monthly_cost=$(calculate_base_costs "$num_accounts" "$region" "light")
    echo -e "${YELLOW}💰 Estimated monthly cost: $(format_currency "$monthly_cost") (base infrastructure only)${NC}"
}

# Function for calculating monthly cost (compatibility with setup script)
calculate_monthly_cost() {
    local num_accounts="${1:-3}"
    local usage_level="${2:-minimal}"
    local region="${3:-$(get_pricing_region)}"

    init_pricing_cache >/dev/null 2>&1
    calculate_base_costs "$num_accounts" "$region" "$usage_level" 2>/dev/null
}

# Function for dry-run cost display (used by setup script)
display_dry_run_costs() {
    local num_accounts="${1:-3}"
    local region="${2:-$(get_pricing_region)}"

    init_pricing_cache >/dev/null 2>&1

    echo -e "${YELLOW}[DRY RUN] Estimated monthly AWS costs after setup:${NC}"
    echo ""

    # Get costs for different usage levels
    local minimal_cost=$(calculate_monthly_cost "$num_accounts" "minimal" "$region")
    local light_cost=$(calculate_monthly_cost "$num_accounts" "light" "$region")
    local moderate_cost=$(calculate_monthly_cost "$num_accounts" "moderate" "$region")
    local heavy_cost=$(calculate_monthly_cost "$num_accounts" "heavy" "$region")

    # Format as numbers if they're empty
    minimal_cost=${minimal_cost:-0.60}
    light_cost=${light_cost:-0.90}
    moderate_cost=${moderate_cost:-1.50}
    heavy_cost=${heavy_cost:-3.00}

    echo "  Infrastructure baseline: ~$(format_currency "$minimal_cost")/month"
    echo "  • CloudWatch billing alarms: \$0.60"
    echo "  • CDK bootstrap resources: \$0.30"
    echo "  • ECR repositories: \$1.50"
    echo ""
    echo "  With light development: $(format_currency "$light_cost")-15/month"
    echo "  With active development: $(format_currency "$moderate_cost")-35/month"
    echo "  With production workload: $(format_currency "$heavy_cost")+/month"
    echo ""
    echo "  Most users stay under \$10/month during development"
}

# Export functions for use by other scripts
export -f init_pricing_cache
export -f lookup_aws_price
export -f calculate_base_costs
export -f estimate_stack_cost
export -f list_available_stacks
export -f explain_usage_levels
export -f get_usage_level_description
export -f display_cost_breakdown
export -f display_inline_cost
export -f format_currency
export -f calculate_monthly_cost
export -f display_dry_run_costs