#!/bin/bash

# Template API Service
# Provides JSON API endpoints for template discovery
# Can be used by web frontends, CLIs, or other automation tools

# Source the template discovery library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/template-discovery.sh"

# API version
API_VERSION="1.0.0"

# Initialize the service
init_template_service() {
    init_template_cache
}

# API endpoint: Get service info
api_info() {
    jq -n \
        --arg version "$API_VERSION" \
        --arg cache_dir "$TEMPLATE_CACHE_DIR" \
        --arg cache_ttl "$TEMPLATE_CACHE_TTL" \
        '{
            version: $version,
            service: "AWS CloudFormation Template API",
            endpoints: [
                "/info",
                "/regions",
                "/templates",
                "/templates/{name}",
                "/templates/{name}/analyze",
                "/templates/{name}/estimate",
                "/categories",
                "/quickstarts",
                "/search"
            ],
            cache: {
                directory: $cache_dir,
                ttl_seconds: ($cache_ttl | tonumber)
            }
        }'
}

# API endpoint: List regions
api_regions() {
    local regions
    regions=($(list_template_regions))

    printf '%s\n' "${regions[@]}" | jq -R -s 'split("\n") | map(select(length > 0)) |
        map({
            code: .,
            name: (
                if . == "us-east-1" then "US East (N. Virginia)"
                elif . == "us-east-2" then "US East (Ohio)"
                elif . == "us-west-1" then "US West (N. California)"
                elif . == "us-west-2" then "US West (Oregon)"
                elif . == "eu-west-1" then "EU (Ireland)"
                elif . == "eu-central-1" then "EU (Frankfurt)"
                elif . == "ap-southeast-1" then "Asia Pacific (Singapore)"
                elif . == "ap-northeast-1" then "Asia Pacific (Tokyo)"
                else .
                end
            ),
            bucket: ("cloudformation-templates-" + .)
        })'
}

# API endpoint: List templates
api_templates() {
    local region="${1:-us-east-1}"
    local category="${2:-all}"
    local page="${3:-1}"
    local per_page="${4:-50}"

    local templates
    if [ "$category" = "all" ]; then
        templates=$(fetch_template_list "$region")
    else
        templates=$(filter_by_category "$category" "$region")
    fi

    # Add pagination
    local total
    total=$(echo "$templates" | jq 'length')
    local start=$(( (page - 1) * per_page ))
    local end=$(( start + per_page ))

    echo "$templates" | jq \
        --argjson start "$start" \
        --argjson end "$end" \
        --argjson page "$page" \
        --argjson per_page "$per_page" \
        --argjson total "$total" \
        '{
            data: .[$start:$end],
            pagination: {
                page: $page,
                per_page: $per_page,
                total: $total,
                total_pages: (($total + $per_page - 1) / $per_page | floor)
            }
        }'
}

# API endpoint: Get template details
api_template_details() {
    local template_name="$1"
    local region="${2:-us-east-1}"

    local metadata
    metadata=$(get_template_metadata "$template_name" "$region")

    if [ -z "$metadata" ] || [ "$metadata" = "null" ]; then
        jq -n '{error: "Template not found", code: 404}'
        return 1
    fi

    # Download and analyze template
    local content
    content=$(download_template "$template_name" "$region")

    if [ $? -eq 0 ]; then
        local analysis
        analysis=$(analyze_template "$content")

        echo "$metadata" | jq \
            --argjson analysis "$analysis" \
            '. + {analysis: $analysis}'
    else
        echo "$metadata"
    fi
}

# API endpoint: Analyze template
api_template_analyze() {
    local template_name="$1"
    local region="${2:-us-east-1}"

    local content
    content=$(download_template "$template_name" "$region")

    if [ $? -eq 0 ]; then
        analyze_template "$content"
    else
        jq -n '{error: "Failed to download template", code: 500}'
        return 1
    fi
}

# API endpoint: Estimate template cost
api_template_estimate() {
    local template_name="$1"
    local region="${2:-us-east-1}"

    local content
    content=$(download_template "$template_name" "$region")

    if [ $? -eq 0 ]; then
        local estimates="{}"
        for level in minimal light moderate heavy; do
            local cost
            cost=$(estimate_template_cost "$content" "$level")
            estimates=$(echo "$estimates" | jq \
                --arg level "$level" \
                --arg cost "$cost" \
                '. + {($level): ($cost | tonumber)}')
        done

        jq -n \
            --arg template "$template_name" \
            --arg region "$region" \
            --argjson estimates "$estimates" \
            '{
                template: $template,
                region: $region,
                currency: "USD",
                period: "monthly",
                estimates: $estimates,
                disclaimer: "Estimates are approximate and may vary based on actual usage"
            }'
    else
        jq -n '{error: "Failed to download template", code: 500}'
        return 1
    fi
}

# API endpoint: List categories
api_categories() {
    local region="${1:-us-east-1}"

    local categories
    categories=($(get_template_categories "$region"))

    printf '%s\n' "${categories[@]}" | jq -R -s 'split("\n") | map(select(length > 0)) |
        map({
            id: .,
            name: (
                if . == "web" then "Web Applications"
                elif . == "database" then "Databases"
                elif . == "network" then "Networking"
                elif . == "container" then "Containers"
                elif . == "serverless" then "Serverless"
                elif . == "platform" then "Platform Services"
                elif . == "windows" then "Windows"
                elif . == "analytics" then "Analytics & Big Data"
                else . | split("-") | map(.[0:1] | ascii_upcase + .[1:]) | join(" ")
                end
            ),
            description: (
                if . == "web" then "LAMP, WordPress, Drupal, and other web applications"
                elif . == "database" then "RDS, DynamoDB, and database solutions"
                elif . == "network" then "VPC, Load Balancers, and networking components"
                elif . == "container" then "ECS, Batch, and container services"
                elif . == "serverless" then "Lambda functions and serverless architectures"
                elif . == "platform" then "Elastic Beanstalk and platform services"
                elif . == "windows" then "Windows Server and Active Directory"
                elif . == "analytics" then "EMR, Kinesis, and data analytics"
                else "Other templates and solutions"
                end
            )
        })'
}

# API endpoint: List Quick Starts
api_quickstarts() {
    local category="${1:-all}"
    local page="${2:-1}"
    local per_page="${3:-50}"

    local quickstarts
    quickstarts=$(fetch_quickstart_list)

    # Filter by category if specified
    if [ "$category" != "all" ]; then
        quickstarts=$(echo "$quickstarts" | jq \
            --arg category "$category" \
            '[.[] | select(.category == $category)]')
    fi

    # Add pagination
    local total
    total=$(echo "$quickstarts" | jq 'length')
    local start=$(( (page - 1) * per_page ))
    local end=$(( start + per_page ))

    echo "$quickstarts" | jq \
        --argjson start "$start" \
        --argjson end "$end" \
        --argjson page "$page" \
        --argjson per_page "$per_page" \
        --argjson total "$total" \
        '{
            data: .[$start:$end],
            pagination: {
                page: $page,
                per_page: $per_page,
                total: $total,
                total_pages: (($total + $per_page - 1) / $per_page | floor)
            }
        }'
}

# API endpoint: Search templates
api_search() {
    local query="$1"
    local region="${2:-us-east-1}"
    local page="${3:-1}"
    local per_page="${4:-50}"

    if [ -z "$query" ]; then
        jq -n '{error: "Search query required", code: 400}'
        return 1
    fi

    local results
    results=$(search_templates "$query" "$region")

    # Add relevance scoring
    results=$(echo "$results" | jq --arg query "$query" '
        map(. + {
            relevance: (
                if (.name | ascii_downcase | contains($query | ascii_downcase)) then 100
                elif (.name | ascii_downcase | startswith($query | ascii_downcase)) then 90
                elif (.category | contains($query | ascii_downcase)) then 50
                else 10
                end
            )
        }) | sort_by(.relevance) | reverse')

    # Add pagination
    local total
    total=$(echo "$results" | jq 'length')
    local start=$(( (page - 1) * per_page ))
    local end=$(( start + per_page ))

    echo "$results" | jq \
        --arg query "$query" \
        --argjson start "$start" \
        --argjson end "$end" \
        --argjson page "$page" \
        --argjson per_page "$per_page" \
        --argjson total "$total" \
        '{
            query: $query,
            data: .[$start:$end],
            pagination: {
                page: $page,
                per_page: $per_page,
                total: $total,
                total_pages: (($total + $per_page - 1) / $per_page | floor)
            }
        }'
}

# API endpoint: Get template content
api_template_content() {
    local template_name="$1"
    local region="${2:-us-east-1}"
    local format="${3:-raw}"  # raw, formatted, minified

    local content
    content=$(download_template "$template_name" "$region")

    if [ $? -eq 0 ]; then
        case "$format" in
            raw)
                echo "$content"
                ;;
            formatted)
                if echo "$content" | jq empty 2>/dev/null; then
                    echo "$content" | jq '.'
                else
                    echo "$content"
                fi
                ;;
            minified)
                if echo "$content" | jq empty 2>/dev/null; then
                    echo "$content" | jq -c '.'
                else
                    echo "$content"
                fi
                ;;
            base64)
                echo "$content" | base64
                ;;
            *)
                echo "$content"
                ;;
        esac
    else
        jq -n '{error: "Failed to download template", code: 500}'
        return 1
    fi
}

# Export API functions
export -f api_info
export -f api_regions
export -f api_templates
export -f api_template_details
export -f api_template_analyze
export -f api_template_estimate
export -f api_categories
export -f api_quickstarts
export -f api_search
export -f api_template_content