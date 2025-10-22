#!/bin/bash

# AWS CloudFormation Template Browser
# Interactive tool for browsing and selecting AWS templates
# Fully decoupled - can be used standalone or integrated with other tools

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the template discovery library
source "$SCRIPT_DIR/lib/template-discovery.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Default values
DEFAULT_REGION="us-east-1"
OUTPUT_FORMAT="interactive"  # interactive, json, yaml, list
SELECTED_CATEGORY="all"
SEARCH_KEYWORD=""
ACTION="browse"  # browse, download, analyze, estimate

# Show help
show_help() {
    cat << EOF
${BOLD}AWS CloudFormation Template Browser${NC}

Browse, search, and analyze AWS CloudFormation templates from the official AWS repositories.

${YELLOW}Usage:${NC}
    $(basename "$0") [options]

${YELLOW}Options:${NC}
    ${GREEN}-r, --region REGION${NC}      AWS region (default: us-east-1)
    ${GREEN}-c, --category CATEGORY${NC}  Filter by category (web, database, network, etc.)
    ${GREEN}-s, --search KEYWORD${NC}     Search templates by keyword
    ${GREEN}-f, --format FORMAT${NC}      Output format (interactive, json, yaml, list)
    ${GREEN}-d, --download TEMPLATE${NC}  Download a specific template
    ${GREEN}-a, --analyze TEMPLATE${NC}   Analyze a template for resources
    ${GREEN}-e, --estimate TEMPLATE${NC}  Estimate costs for a template
    ${GREEN}-q, --quickstarts${NC}        Browse AWS Quick Starts from GitHub
    ${GREEN}-g, --github${NC}             Browse official GitHub templates
    ${GREEN}--list-regions${NC}           List all available regions
    ${GREEN}--list-categories${NC}        List all template categories
    ${GREEN}--json${NC}                   Output in JSON format
    ${GREEN}-h, --help${NC}               Show this help message

${YELLOW}Examples:${NC}
    # Browse all templates interactively
    $(basename "$0")

    # Search for WordPress templates
    $(basename "$0") --search wordpress

    # List database templates in JSON format
    $(basename "$0") --category database --json

    # Download a specific template
    $(basename "$0") --download LAMP_Multi_AZ.template

    # Analyze a template
    $(basename "$0") --analyze WordPress_Single_Instance.template

    # Estimate costs for a template
    $(basename "$0") --estimate RDS_MySQL_With_Read_Replica.template

    # Browse Quick Starts
    $(basename "$0") --quickstarts

    # Browse official GitHub templates
    $(basename "$0") --github

${YELLOW}Categories:${NC}
    web         - Web applications (LAMP, WordPress, Drupal)
    database    - Database templates (RDS, DynamoDB)
    network     - Networking templates (VPC, ELB)
    container   - Container services (ECS, Batch)
    serverless  - Serverless templates (Lambda)
    platform    - Platform services (Elastic Beanstalk)
    windows     - Windows and Active Directory
    analytics   - Big Data and Analytics (EMR, Kinesis)
    other       - Other templates

${CYAN}For more information, visit:${NC}
    https://aws.amazon.com/cloudformation/resources/templates/

EOF
}

# Interactive template browser
browse_interactive() {
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}🔍 AWS CloudFormation Template Browser${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    while true; do
        echo -e "${BLUE}Current Settings:${NC}"
        echo -e "  Region: ${GREEN}$DEFAULT_REGION${NC}"
        echo -e "  Category: ${GREEN}$SELECTED_CATEGORY${NC}"
        if [ -n "$SEARCH_KEYWORD" ]; then
            echo -e "  Search: ${GREEN}$SEARCH_KEYWORD${NC}"
        fi
        echo ""

        echo -e "${YELLOW}Options:${NC}"
        echo "  1) Change Region"
        echo "  2) Select Category"
        echo "  3) Search Templates"
        echo "  4) List Templates"
        echo "  5) Download Template"
        echo "  6) Analyze Template"
        echo "  7) Browse Quick Starts"
        echo "  8) Clear Filters"
        echo "  9) Exit"
        echo ""

        read -r -p "Select option (1-9): " choice

        case $choice in
            1) select_region ;;
            2) select_category ;;
            3) search_templates_interactive ;;
            4) list_templates_interactive ;;
            5) download_template_interactive ;;
            6) analyze_template_interactive ;;
            7) browse_quickstarts_interactive ;;
            8) clear_filters ;;
            9) exit 0 ;;
            *) echo -e "${RED}Invalid option${NC}" ;;
        esac

        echo ""
        read -r -p "Press Enter to continue..."
        clear
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}🔍 AWS CloudFormation Template Browser${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
    done
}

# Select region
select_region() {
    echo ""
    echo -e "${BLUE}Available Regions:${NC}"
    local regions
    regions=($(list_template_regions))

    local i=1
    for region in "${regions[@]}"; do
        echo "  $i) $region"
        ((i++))
    done

    echo ""
    read -r -p "Select region (1-${#regions[@]}): " choice

    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#regions[@]}" ]; then
        DEFAULT_REGION="${regions[$((choice-1))]}"
        echo -e "${GREEN}✓ Region set to $DEFAULT_REGION${NC}"
    else
        echo -e "${RED}Invalid selection${NC}"
    fi
}

# Select category
select_category() {
    echo ""
    echo -e "${BLUE}Available Categories:${NC}"
    local categories
    categories=($(get_template_categories "$DEFAULT_REGION"))
    categories+=("all")

    local i=1
    for category in "${categories[@]}"; do
        echo "  $i) $category"
        ((i++))
    done

    echo ""
    read -r -p "Select category (1-${#categories[@]}): " choice

    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#categories[@]}" ]; then
        SELECTED_CATEGORY="${categories[$((choice-1))]}"
        echo -e "${GREEN}✓ Category set to $SELECTED_CATEGORY${NC}"
    else
        echo -e "${RED}Invalid selection${NC}"
    fi
}

# Search templates interactively
search_templates_interactive() {
    echo ""
    read -r -p "Enter search keyword: " keyword
    SEARCH_KEYWORD="$keyword"

    if [ -n "$SEARCH_KEYWORD" ]; then
        echo ""
        echo -e "${BLUE}Searching for '$SEARCH_KEYWORD'...${NC}"
        local results
        results=$(search_templates "$SEARCH_KEYWORD" "$DEFAULT_REGION")

        local count
        count=$(echo "$results" | jq 'length')
        echo -e "${GREEN}Found $count templates${NC}"
    fi
}

# List templates interactively
list_templates_interactive() {
    echo ""
    echo -e "${BLUE}Fetching templates...${NC}"

    local templates
    if [ -n "$SEARCH_KEYWORD" ]; then
        templates=$(search_templates "$SEARCH_KEYWORD" "$DEFAULT_REGION")
    elif [ "$SELECTED_CATEGORY" != "all" ]; then
        templates=$(filter_by_category "$SELECTED_CATEGORY" "$DEFAULT_REGION")
    else
        templates=$(fetch_template_list "$DEFAULT_REGION")
    fi

    # Display templates
    echo ""
    echo "$templates" | jq -r '
        ["#", "NAME", "CATEGORY", "TYPE"],
        ["--", "----", "--------", "----"],
        (to_entries | .[] | [
            .key + 1,
            .value.name[0:50],
            .value.category,
            .value.type
        ]) | @tsv' | column -t | head -30

    echo ""
    echo -e "${CYAN}Showing first 30 results. Use search to narrow down.${NC}"
}

# Download template interactively
download_template_interactive() {
    echo ""
    read -r -p "Enter template name to download: " template_name

    if [ -n "$template_name" ]; then
        echo -e "${BLUE}Downloading $template_name...${NC}"

        local content
        content=$(download_template "$template_name" "$DEFAULT_REGION")

        if [ $? -eq 0 ]; then
            local output_file="${template_name}"
            echo "$content" > "$output_file"
            echo -e "${GREEN}✓ Template saved to $output_file${NC}"
        else
            echo -e "${RED}Failed to download template${NC}"
        fi
    fi
}

# Analyze template interactively
analyze_template_interactive() {
    echo ""
    read -r -p "Enter template name to analyze: " template_name

    if [ -n "$template_name" ]; then
        echo -e "${BLUE}Analyzing $template_name...${NC}"

        local content
        content=$(download_template "$template_name" "$DEFAULT_REGION")

        if [ $? -eq 0 ]; then
            local analysis
            analysis=$(analyze_template "$content")

            echo ""
            echo -e "${GREEN}Template Analysis:${NC}"
            echo "$analysis" | jq '.'
        else
            echo -e "${RED}Failed to download template for analysis${NC}"
        fi
    fi
}

# Browse Quick Starts interactively
browse_quickstarts_interactive() {
    echo ""
    echo -e "${BLUE}Fetching AWS Quick Starts...${NC}"

    local quickstarts
    quickstarts=$(fetch_quickstart_list)

    # Display Quick Starts
    echo ""
    echo "$quickstarts" | jq -r '
        ["#", "NAME", "CATEGORY"],
        ["--", "----", "--------"],
        (to_entries | .[] | [
            .key + 1,
            .value.name[0:60],
            .value.category
        ]) | @tsv' | column -t | head -20

    echo ""
    echo -e "${CYAN}Showing first 20 Quick Starts${NC}"
}

# Clear filters
clear_filters() {
    SELECTED_CATEGORY="all"
    SEARCH_KEYWORD=""
    echo -e "${GREEN}✓ Filters cleared${NC}"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --region|-r)
            DEFAULT_REGION="$2"
            shift 2
            ;;
        --category|-c)
            SELECTED_CATEGORY="$2"
            shift 2
            ;;
        --search|-s)
            SEARCH_KEYWORD="$2"
            shift 2
            ;;
        --format|-f)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        --download|-d)
            ACTION="download"
            TEMPLATE_TO_DOWNLOAD="$2"
            shift 2
            ;;
        --analyze|-a)
            ACTION="analyze"
            TEMPLATE_TO_ANALYZE="$2"
            shift 2
            ;;
        --estimate|-e)
            ACTION="estimate"
            TEMPLATE_TO_ESTIMATE="$2"
            shift 2
            ;;
        --list-regions)
            list_template_regions
            exit 0
            ;;
        --list-categories)
            get_template_categories "$DEFAULT_REGION"
            exit 0
            ;;
        --quickstarts|-q)
            ACTION="quickstarts"
            shift
            ;;
        --github|-g)
            ACTION="github"
            shift
            ;;
        --json)
            OUTPUT_FORMAT="json"
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# Initialize cache
init_template_cache

# Main execution
case "$ACTION" in
    browse)
        if [ "$OUTPUT_FORMAT" = "interactive" ]; then
            browse_interactive
        else
            # Non-interactive listing
            if [ -n "$SEARCH_KEYWORD" ]; then
                search_templates "$SEARCH_KEYWORD" "$DEFAULT_REGION"
            elif [ "$SELECTED_CATEGORY" != "all" ]; then
                filter_by_category "$SELECTED_CATEGORY" "$DEFAULT_REGION"
            else
                fetch_template_list "$DEFAULT_REGION"
            fi
        fi
        ;;

    download)
        if [ -n "$TEMPLATE_TO_DOWNLOAD" ]; then
            content=$(download_template "$TEMPLATE_TO_DOWNLOAD" "$DEFAULT_REGION")
            if [ $? -eq 0 ]; then
                echo "$content"
            else
                echo -e "${RED}Failed to download template${NC}" >&2
                exit 1
            fi
        else
            echo -e "${RED}Template name required for download${NC}" >&2
            exit 1
        fi
        ;;

    analyze)
        if [ -n "$TEMPLATE_TO_ANALYZE" ]; then
            content=$(download_template "$TEMPLATE_TO_ANALYZE" "$DEFAULT_REGION")
            if [ $? -eq 0 ]; then
                analyze_template "$content"
            else
                echo -e "${RED}Failed to download template for analysis${NC}" >&2
                exit 1
            fi
        else
            echo -e "${RED}Template name required for analysis${NC}" >&2
            exit 1
        fi
        ;;

    estimate)
        if [ -n "$TEMPLATE_TO_ESTIMATE" ]; then
            content=$(download_template "$TEMPLATE_TO_ESTIMATE" "$DEFAULT_REGION")
            if [ $? -eq 0 ]; then
                echo -e "${BLUE}Estimating costs for $TEMPLATE_TO_ESTIMATE...${NC}"
                for level in minimal light moderate heavy; do
                    cost=$(estimate_template_cost "$content" "$level")
                    printf "  %-10s: \$%.2f/month\n" "$level" "$cost"
                done
            else
                echo -e "${RED}Failed to download template for estimation${NC}" >&2
                exit 1
            fi
        else
            echo -e "${RED}Template name required for estimation${NC}" >&2
            exit 1
        fi
        ;;

    quickstarts)
        if [ "$OUTPUT_FORMAT" = "json" ]; then
            fetch_quickstart_list
        else
            browse_quickstarts_interactive
        fi
        ;;

    github)
        if [ "$OUTPUT_FORMAT" = "json" ]; then
            fetch_github_templates
        else
            echo -e "${BLUE}Fetching official AWS CloudFormation templates from GitHub...${NC}"
            github_templates=$(fetch_github_templates)

            # Display GitHub templates
            echo ""
            echo "$github_templates" | jq -r '
                ["#", "NAME", "REPOSITORY", "SOURCE", "CATEGORY"],
                ["--", "----", "----------", "------", "--------"],
                (to_entries | .[] | [
                    .key + 1,
                    .value.name[0:40],
                    .value.repository[0:30],
                    .value.source,
                    .value.category
                ]) | @tsv' | column -t | head -30

            echo ""
            echo -e "${CYAN}Showing first 30 GitHub templates. Use --json for full list.${NC}"
        fi
        ;;
esac