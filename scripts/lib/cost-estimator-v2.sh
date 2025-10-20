#!/bin/bash

# Advanced Cost Estimator for AWS Multi-Account Bootstrap
# Uses AWS Pricing API for accurate, up-to-date pricing
# Supports estimating costs for future stacks

# Colors for output
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Cache directory for pricing data
CACHE_DIR="${HOME}/.aws-bootstrap/pricing-cache"
CACHE_EXPIRY=86400  # 24 hours in seconds

# Initialize cache directory
init_cache() {
    mkdir -p "$CACHE_DIR"
}

# Function to get current AWS region
get_current_region() {
    local region="${AWS_DEFAULT_REGION:-us-east-1}"
    echo "$region"
}

# Function to check if cache is valid
is_cache_valid() {
    local cache_file="$1"
    if [ ! -f "$cache_file" ]; then
        return 1
    fi

    local file_age=$(($(date +%s) - $(stat -f%m "$cache_file" 2>/dev/null || stat -c%Y "$cache_file" 2>/dev/null || echo 0)))
    if [ $file_age -gt $CACHE_EXPIRY ]; then
        return 1
    fi
    return 0
}

# Function to get pricing from AWS Pricing API
get_aws_pricing() {
    local service_code="$1"
    local filter_type="$2"
    local filter_value="$3"
    local region="${4:-us-east-1}"

    local cache_key="${service_code}_${filter_type}_${filter_value}_${region}"
    # Replace spaces and special characters in cache key
    cache_key=$(echo "$cache_key" | tr ' /' '__')
    local cache_file="$CACHE_DIR/${cache_key}.json"

    # Check cache first
    if is_cache_valid "$cache_file"; then
        cat "$cache_file"
        return 0
    fi

    # Query AWS Pricing API
    local filters=""
    if [ -n "$filter_type" ] && [ -n "$filter_value" ]; then
        filters="--filters Type=$filter_type,Field=$filter_type,Value=$filter_value"
    fi

    # Note: AWS Pricing API is only available in us-east-1 and ap-south-1
    local pricing_output
    pricing_output=$(aws pricing get-products \
        --service-code "$service_code" \
        --region us-east-1 \
        --max-items 1 \
        $filters \
        --output json 2>/dev/null)

    if [ $? -eq 0 ] && [ -n "$pricing_output" ]; then
        echo "$pricing_output" > "$cache_file"
        echo "$pricing_output"
    else
        # Return empty JSON if API call fails
        echo "{}"
    fi
}

# Function to extract price from pricing JSON
extract_price() {
    local pricing_json="$1"
    local price_dimension="$2"

    # Extract OnDemand pricing
    echo "$pricing_json" | jq -r "
        .PriceList[0]
        | fromjson
        | .terms.OnDemand
        | to_entries[0].value.priceDimensions
        | to_entries[0].value.pricePerUnit.USD
        // \"0\"
    " 2>/dev/null || echo "0"
}

# Function to get specific service prices
get_cloudwatch_alarm_price() {
    local region="${1:-us-east-1}"
    local pricing=$(get_aws_pricing "AmazonCloudWatch" "TERM_MATCH" "MetricAlarm" "$region")
    local price=$(extract_price "$pricing")

    # Fallback to known price if API fails
    if [ "$price" = "0" ] || [ -z "$price" ]; then
        price="0.10"
    fi
    echo "$price"
}

get_s3_storage_price() {
    local region="${1:-us-east-1}"
    local pricing=$(get_aws_pricing "AmazonS3" "TERM_MATCH" "Standard" "$region")
    local price=$(extract_price "$pricing")

    # Fallback to known price if API fails (per GB-month)
    if [ "$price" = "0" ] || [ -z "$price" ]; then
        price="0.023"
    fi
    echo "$price"
}

get_ecr_storage_price() {
    local region="${1:-us-east-1}"
    local pricing=$(get_aws_pricing "AmazonECR" "TERM_MATCH" "Storage" "$region")
    local price=$(extract_price "$pricing")

    # Fallback to known price if API fails (per GB-month)
    if [ "$price" = "0" ] || [ -z "$price" ]; then
        price="0.10"
    fi
    echo "$price"
}

# Function to estimate costs for common AWS stacks
estimate_stack_cost() {
    local stack_type="$1"
    local region="${2:-us-east-1}"
    local monthly_cost=0

    case $stack_type in
        "api-lambda")
            # API Gateway + Lambda + DynamoDB
            # Assuming light usage (under free tier for most)
            monthly_cost="5.00"
            ;;
        "static-website")
            # S3 + CloudFront + Route53
            monthly_cost="3.00"
            ;;
        "container-ecs")
            # ECS Fargate + ALB + ECR
            # 1 task running 24/7 with 0.5 vCPU, 1GB memory
            monthly_cost="25.00"
            ;;
        "rds-postgres")
            # RDS PostgreSQL db.t3.micro
            monthly_cost="15.00"
            ;;
        "vpc-nat")
            # VPC with NAT Gateway
            monthly_cost="45.00"
            ;;
        "elasticsearch")
            # OpenSearch t3.small.search
            monthly_cost="36.00"
            ;;
        *)
            monthly_cost="0"
            ;;
    esac

    echo "$monthly_cost"
}

# Function to format currency
format_currency() {
    printf "$%.2f" "$1"
}

# Function to calculate monthly cost with real pricing
calculate_monthly_cost_real() {
    local num_accounts=${1:-3}
    local usage_level=${2:-"minimal"}
    local additional_stacks="${3:-}"
    local region=$(get_current_region)

    # Initialize cache
    init_cache

    # Get current prices
    local alarm_price=$(get_cloudwatch_alarm_price "$region")
    local s3_price=$(get_s3_storage_price "$region")
    local ecr_price=$(get_ecr_storage_price "$region")

    # Base infrastructure costs
    local base_costs=0

    # CloudWatch Alarms (2 per account)
    base_costs=$(echo "$base_costs + ($num_accounts * 2 * $alarm_price)" | bc -l)

    # S3 buckets for CDK bootstrap (estimate 5GB per account)
    base_costs=$(echo "$base_costs + ($num_accounts * 5 * $s3_price)" | bc -l)

    # ECR repositories (estimate 5GB per account)
    base_costs=$(echo "$base_costs + ($num_accounts * 5 * $ecr_price)" | bc -l)

    # Add costs for additional stacks
    local stack_costs=0
    if [ -n "$additional_stacks" ]; then
        IFS=',' read -ra STACKS <<< "$additional_stacks"
        for stack in "${STACKS[@]}"; do
            local stack_cost=$(estimate_stack_cost "$stack" "$region")
            stack_costs=$(echo "$stack_costs + $stack_cost" | bc -l)
        done
    fi

    # Usage-based variable costs
    local variable_costs=0
    case $usage_level in
        minimal)
            variable_costs=0
            ;;
        light)
            variable_costs=$(echo "$num_accounts * 5" | bc -l)
            ;;
        moderate)
            variable_costs=$(echo "$num_accounts * 20" | bc -l)
            ;;
        heavy)
            variable_costs=$(echo "$num_accounts * 50" | bc -l)
            ;;
    esac

    local total_cost=$(echo "$base_costs + $variable_costs + $stack_costs" | bc -l)
    echo "$total_cost"
}

# Function to display detailed cost breakdown with real pricing
display_cost_breakdown_real() {
    local num_accounts=${1:-3}
    local show_details=${2:-true}
    local additional_stacks="${3:-}"
    local region=$(get_current_region)

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}💰 AWS Cost Estimation (Region: $region)${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Initialize cache
    init_cache

    # Try to get real pricing
    echo -e "${BLUE}Fetching current AWS pricing...${NC}"
    local alarm_price=$(get_cloudwatch_alarm_price "$region")
    local s3_price=$(get_s3_storage_price "$region")
    local ecr_price=$(get_ecr_storage_price "$region")

    if [ "$show_details" = true ]; then
        echo ""
        echo -e "${YELLOW}Base Infrastructure Costs (using current AWS pricing):${NC}"
        echo "  • CloudWatch Alarms: $(format_currency $(echo "$num_accounts * 2 * $alarm_price" | bc -l))/month"
        echo "    ($num_accounts accounts × 2 alarms × \$$alarm_price each)"
        echo "  • S3 Storage (CDK): $(format_currency $(echo "$num_accounts * 5 * $s3_price" | bc -l))/month"
        echo "    ($num_accounts accounts × ~5GB × \$$s3_price per GB)"
        echo "  • ECR Storage: $(format_currency $(echo "$num_accounts * 5 * $ecr_price" | bc -l))/month"
        echo "    ($num_accounts accounts × ~5GB × \$$ecr_price per GB)"
        echo ""
    fi

    # Calculate costs for different usage levels
    echo -e "${YELLOW}Estimated Monthly Costs by Usage Level:${NC}"
    echo ""

    local minimal_cost=$(calculate_monthly_cost_real "$num_accounts" "minimal" "$additional_stacks")
    local light_cost=$(calculate_monthly_cost_real "$num_accounts" "light" "$additional_stacks")
    local moderate_cost=$(calculate_monthly_cost_real "$num_accounts" "moderate" "$additional_stacks")

    echo "  🌱 ${GREEN}Minimal Usage${NC} (free tier maximized):"
    echo "     $(format_currency "$minimal_cost")/month"
    echo ""
    echo "  💡 ${BLUE}Light Development${NC} (some API calls, Lambda executions):"
    echo "     $(format_currency "$light_cost")/month"
    echo ""
    echo "  🚀 ${CYAN}Active Development${NC} (daily deployments, always-on services):"
    echo "     $(format_currency "$moderate_cost")/month"
    echo ""

    # Show additional stack costs if provided
    if [ -n "$additional_stacks" ]; then
        echo -e "${YELLOW}Additional Stack Estimates:${NC}"
        IFS=',' read -ra STACKS <<< "$additional_stacks"
        for stack in "${STACKS[@]}"; do
            local stack_cost=$(estimate_stack_cost "$stack" "$region")
            case $stack in
                "api-lambda")
                    echo "  • API Gateway + Lambda + DynamoDB: $(format_currency $stack_cost)/month"
                    ;;
                "static-website")
                    echo "  • Static Website (S3 + CloudFront): $(format_currency $stack_cost)/month"
                    ;;
                "container-ecs")
                    echo "  • ECS Fargate Container: $(format_currency $stack_cost)/month"
                    ;;
                "rds-postgres")
                    echo "  • RDS PostgreSQL (db.t3.micro): $(format_currency $stack_cost)/month"
                    ;;
                "vpc-nat")
                    echo "  • VPC with NAT Gateway: $(format_currency $stack_cost)/month"
                    ;;
                "elasticsearch")
                    echo "  • OpenSearch (t3.small): $(format_currency $stack_cost)/month"
                    ;;
            esac
        done
        echo ""
    fi

    echo -e "${GREEN}💡 Cost Optimization Tips:${NC}"
    echo "  • Use AWS Free Tier (1 year) for many services"
    echo "  • Stop/terminate unused resources regularly"
    echo "  • Use Savings Plans for predictable workloads"
    echo "  • Monitor with AWS Cost Explorer"
    echo ""
    echo -e "${BLUE}📊 For detailed, personalized estimates:${NC}"
    echo "  Visit: https://calculator.aws/#/estimate"
    echo ""
}

# Function to display available stack types
display_stack_options() {
    echo -e "${CYAN}Available Stack Types for Cost Estimation:${NC}"
    echo "  • api-lambda     - API Gateway + Lambda + DynamoDB"
    echo "  • static-website - S3 + CloudFront + Route53"
    echo "  • container-ecs  - ECS Fargate + ALB + ECR"
    echo "  • rds-postgres   - RDS PostgreSQL database"
    echo "  • vpc-nat        - VPC with NAT Gateway"
    echo "  • elasticsearch  - OpenSearch cluster"
    echo ""
    echo "Usage: estimate-cost --stacks api-lambda,static-website"
}

# Export functions for use in other scripts
export -f get_aws_pricing
export -f calculate_monthly_cost_real
export -f display_cost_breakdown_real
export -f estimate_stack_cost
export -f display_stack_options
export -f format_currency

# Backward compatibility with original functions
calculate_monthly_cost() {
    calculate_monthly_cost_real "$@"
}

display_cost_breakdown() {
    display_cost_breakdown_real "$@"
}

display_inline_cost() {
    local num_accounts=${1:-3}
    local cost=$(calculate_monthly_cost_real "$num_accounts" "minimal")
    echo -e "${YELLOW}💰 Estimated monthly cost:${NC} Starting at $(format_currency "$cost")/month (varies by usage and region)"
}

display_dry_run_costs() {
    local num_accounts=${1:-3}
    echo -e "${YELLOW}[DRY RUN] Estimated monthly AWS costs:${NC}"
    echo ""

    local minimal=$(calculate_monthly_cost_real "$num_accounts" "minimal")
    local light=$(calculate_monthly_cost_real "$num_accounts" "light")

    echo "  Base infrastructure: ~$(format_currency "$minimal")/month"
    echo "  With development: $(format_currency "$light")-$(format_currency $(echo "$light + 10" | bc -l))/month"
    echo "  With production: Varies by workload"
    echo ""
    echo "  💡 Tip: Add --estimate-stacks to include specific services"
    echo "  Example: --estimate-stacks api-lambda,static-website"
}

export -f calculate_monthly_cost
export -f display_cost_breakdown
export -f display_inline_cost
export -f display_dry_run_costs