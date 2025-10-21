#!/bin/bash

# AWS CloudFormation Template Discovery Service
# Fully decoupled library for discovering and accessing AWS templates
# Can be used by CLI tools, web frontends, or other automation

# Configuration
TEMPLATE_CACHE_DIR="${HOME}/.aws-bootstrap/template-cache"
TEMPLATE_CACHE_TTL="${TEMPLATE_CACHE_TTL:-86400}"  # 24 hours default
TEMPLATE_API_TIMEOUT="${TEMPLATE_API_TIMEOUT:-10}"

# Available AWS regions with template buckets (using functions for compatibility)
TEMPLATE_REGIONS="us-east-1 us-east-2 us-west-1 us-west-2 eu-west-1 eu-central-1 ap-southeast-1 ap-northeast-1"

# Initialize template cache directory
init_template_cache() {
    mkdir -p "$TEMPLATE_CACHE_DIR"
    mkdir -p "$TEMPLATE_CACHE_DIR/metadata"
    mkdir -p "$TEMPLATE_CACHE_DIR/templates"
    mkdir -p "$TEMPLATE_CACHE_DIR/quickstarts"
}

# Check if cache file is still valid
is_cache_valid() {
    local cache_file="$1"

    [ ! -f "$cache_file" ] && return 1

    local file_age
    if command -v stat >/dev/null 2>&1; then
        local current_time=$(date +%s)
        local file_time
        if [[ "$OSTYPE" == "darwin"* ]]; then
            file_time=$(stat -f%m "$cache_file" 2>/dev/null || echo 0)
        else
            file_time=$(stat -c%Y "$cache_file" 2>/dev/null || echo 0)
        fi
        file_age=$((current_time - file_time))
    else
        return 1
    fi

    [ "$file_age" -gt "$TEMPLATE_CACHE_TTL" ] && return 1
    return 0
}

# List all available regions with template buckets
list_template_regions() {
    echo "$TEMPLATE_REGIONS" | tr ' ' '\n' | sort
}

# Get S3 bucket name for a region
get_template_bucket() {
    local region="${1:-us-east-1}"
    echo "cloudformation-templates-${region}"
}

# Fetch template list from S3 bucket
fetch_template_list() {
    local region="${1:-us-east-1}"
    local cache_file="$TEMPLATE_CACHE_DIR/metadata/templates-${region}.json"

    # Check cache
    if is_cache_valid "$cache_file"; then
        cat "$cache_file"
        return 0
    fi

    local bucket=$(get_template_bucket "$region")
    local url="https://s3.amazonaws.com/${bucket}/"

    # Fetch and convert XML to JSON
    local response
    response=$(curl -s --max-time "$TEMPLATE_API_TIMEOUT" "$url" 2>/dev/null)

    if [ $? -eq 0 ] && [ -n "$response" ]; then
        # Parse XML and convert to JSON format
        local json_output
        json_output=$(echo "$response" | \
            grep "<Key>" | \
            sed 's/<Key>//g' | \
            sed 's/<\/Key>//g' | \
            sed 's/^[[:space:]]*//g' | \
            jq -R -s 'split("\n") | map(select(length > 0)) |
                map({
                    name: .,
                    region: "'"$region"'",
                    url: "https://s3.amazonaws.com/'"$bucket"'/\(.)",
                    type: (
                        if test(".template$") then "json"
                        elif test(".yaml$") then "yaml"
                        elif test(".yml$") then "yaml"
                        else "unknown"
                        end
                    ),
                    category: (
                        if test("(?i)lamp|wordpress|drupal|joomla") then "web"
                        elif test("(?i)rds|database|mysql|postgres") then "database"
                        elif test("(?i)vpc|network|subnet") then "network"
                        elif test("(?i)ecs|docker|container|batch") then "container"
                        elif test("(?i)lambda|serverless") then "serverless"
                        elif test("(?i)elastic.?beanstalk") then "platform"
                        elif test("(?i)windows|active.?directory") then "windows"
                        elif test("(?i)emr|kinesis|data") then "analytics"
                        else "other"
                        end
                    )
                })'
        )

        echo "$json_output" > "$cache_file"
        echo "$json_output"
    else
        echo "[]"
    fi
}

# Search templates by keyword
search_templates() {
    local keyword="$1"
    local region="${2:-us-east-1}"

    local templates
    templates=$(fetch_template_list "$region")

    if [ -n "$keyword" ]; then
        echo "$templates" | jq --arg keyword "$keyword" \
            '[.[] | select(.name | test($keyword; "i"))]'
    else
        echo "$templates"
    fi
}

# Filter templates by category
filter_by_category() {
    local category="$1"
    local region="${2:-us-east-1}"

    local templates
    templates=$(fetch_template_list "$region")

    echo "$templates" | jq --arg category "$category" \
        '[.[] | select(.category == $category)]'
}

# Get template categories
get_template_categories() {
    local region="${1:-us-east-1}"

    local templates
    templates=$(fetch_template_list "$region")

    echo "$templates" | jq -r '[.[].category] | unique | .[]'
}

# Download a specific template
download_template() {
    local template_name="$1"
    local region="${2:-us-east-1}"
    local output_file="${3:-}"

    # If no output file specified, use cache
    if [ -z "$output_file" ]; then
        output_file="$TEMPLATE_CACHE_DIR/templates/${region}_${template_name}"
    fi

    # Check cache if using default location
    if [ "$output_file" = "$TEMPLATE_CACHE_DIR/templates/${region}_${template_name}" ] && \
       is_cache_valid "$output_file"; then
        cat "$output_file"
        return 0
    fi

    local bucket=$(get_template_bucket "$region")
    local url="https://s3.amazonaws.com/${bucket}/${template_name}"

    local content
    content=$(curl -s --max-time "$TEMPLATE_API_TIMEOUT" "$url" 2>/dev/null)

    if [ $? -eq 0 ] && [ -n "$content" ]; then
        echo "$content" > "$output_file"
        echo "$content"
    else
        return 1
    fi
}

# Analyze template for resource types
analyze_template() {
    local template_content="$1"

    # Extract resource types
    local resources
    if echo "$template_content" | jq empty 2>/dev/null; then
        # JSON format
        resources=$(echo "$template_content" | jq -r '.Resources | to_entries[] | .value.Type' 2>/dev/null | sort -u)
    else
        # YAML format - basic extraction
        resources=$(echo "$template_content" | grep "Type:" | sed 's/.*Type:[[:space:]]*//' | sort -u)
    fi

    # Create analysis report
    jq -n \
        --arg resources "$resources" \
        --argjson resource_count "$(echo "$resources" | wc -l | xargs)" \
        '{
            resource_types: ($resources | split("\n") | map(select(length > 0))),
            resource_count: $resource_count,
            services: ($resources | split("\n") | map(select(length > 0)) | map(split("::")[1]) | unique),
            has_vpc: ($resources | contains("AWS::EC2::VPC")),
            has_rds: ($resources | contains("AWS::RDS::")),
            has_lambda: ($resources | contains("AWS::Lambda::")),
            has_ecs: ($resources | contains("AWS::ECS::")),
            has_s3: ($resources | contains("AWS::S3::"))
        }'
}

# Estimate template cost (basic estimation based on resource types)
estimate_template_cost() {
    local template_content="$1"
    local usage_level="${2:-light}"  # minimal, light, moderate, heavy

    local analysis
    analysis=$(analyze_template "$template_content")

    # Basic cost estimation based on resource types
    local base_cost=0

    # Check for common resources and add estimated costs
    if echo "$analysis" | jq -e '.has_rds' >/dev/null; then
        case "$usage_level" in
            minimal) base_cost=$(echo "$base_cost + 15" | bc -l) ;;
            light) base_cost=$(echo "$base_cost + 30" | bc -l) ;;
            moderate) base_cost=$(echo "$base_cost + 100" | bc -l) ;;
            heavy) base_cost=$(echo "$base_cost + 500" | bc -l) ;;
        esac
    fi

    if echo "$analysis" | jq -e '.has_vpc' >/dev/null; then
        # NAT Gateway costs
        case "$usage_level" in
            minimal) base_cost=$(echo "$base_cost + 0" | bc -l) ;;
            light) base_cost=$(echo "$base_cost + 45" | bc -l) ;;
            moderate) base_cost=$(echo "$base_cost + 90" | bc -l) ;;
            heavy) base_cost=$(echo "$base_cost + 180" | bc -l) ;;
        esac
    fi

    if echo "$analysis" | jq -e '.has_lambda' >/dev/null; then
        case "$usage_level" in
            minimal) base_cost=$(echo "$base_cost + 0" | bc -l) ;;
            light) base_cost=$(echo "$base_cost + 5" | bc -l) ;;
            moderate) base_cost=$(echo "$base_cost + 25" | bc -l) ;;
            heavy) base_cost=$(echo "$base_cost + 100" | bc -l) ;;
        esac
    fi

    echo "$base_cost"
}

# Fetch AWS Quick Start templates from GitHub
fetch_quickstart_list() {
    local cache_file="$TEMPLATE_CACHE_DIR/metadata/quickstarts.json"

    # Check cache
    if is_cache_valid "$cache_file"; then
        cat "$cache_file"
        return 0
    fi

    # Fetch from GitHub API
    local response
    response=$(curl -s --max-time "$TEMPLATE_API_TIMEOUT" \
        "https://api.github.com/orgs/aws-quickstart/repos?per_page=100" 2>/dev/null)

    if [ $? -eq 0 ] && [ -n "$response" ]; then
        # Parse and enhance with categories
        local enhanced
        enhanced=$(echo "$response" | jq '[.[] | {
            name: .name,
            description: .description,
            url: .html_url,
            clone_url: .clone_url,
            updated: .updated_at,
            category: (
                if (.name | test("(?i)vpc|network")) then "network"
                elif (.name | test("(?i)eks|kubernetes|k8s")) then "kubernetes"
                elif (.name | test("(?i)database|rds|dynamodb")) then "database"
                elif (.name | test("(?i)microsoft|windows|active-directory")) then "windows"
                elif (.name | test("(?i)security|compliance")) then "security"
                elif (.name | test("(?i)devops|cicd|jenkins")) then "devops"
                elif (.name | test("(?i)data|analytics|ml")) then "analytics"
                elif (.name | test("(?i)serverless|lambda")) then "serverless"
                else "other"
                end
            )
        }]')

        echo "$enhanced" > "$cache_file"
        echo "$enhanced"
    else
        echo "[]"
    fi
}

# Get template metadata as JSON
get_template_metadata() {
    local template_name="$1"
    local region="${2:-us-east-1}"

    local templates
    templates=$(fetch_template_list "$region")

    echo "$templates" | jq --arg name "$template_name" \
        '.[] | select(.name == $name)'
}

# List templates in a formatted table (for CLI output)
list_templates_formatted() {
    local region="${1:-us-east-1}"
    local category="${2:-all}"

    local templates
    if [ "$category" = "all" ]; then
        templates=$(fetch_template_list "$region")
    else
        templates=$(filter_by_category "$category" "$region")
    fi

    echo "$templates" | jq -r '
        ["NAME", "CATEGORY", "TYPE"],
        ["----", "--------", "----"],
        (.[] | [.name[0:50], .category, .type]) |
        @tsv' | column -t
}

# Export functions for use by other scripts
export -f init_template_cache
export -f list_template_regions
export -f fetch_template_list
export -f search_templates
export -f filter_by_category
export -f get_template_categories
export -f download_template
export -f analyze_template
export -f estimate_template_cost
export -f fetch_quickstart_list
export -f get_template_metadata
export -f list_templates_formatted