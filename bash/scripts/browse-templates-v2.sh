#!/bin/bash

# AWS CloudFormation Template Browser v2
# Improved interactive browsing experience
# Features: Pagination, details view, better navigation, no unnecessary prompts

# Don't exit on error for interactive commands
set +e

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
DIM='\033[2m'

# Configuration
PAGE_SIZE=15
CURRENT_PAGE=1
TOTAL_PAGES=1
CURRENT_SOURCE="production"  # production, github, s3, quickstarts
CURRENT_CATEGORY="all"
SEARCH_FILTER=""
TEMPLATES_CACHE=""
FILTERED_TEMPLATES=""

# Initialize
init_template_cache

# Clear screen and show header
show_header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} ${BOLD}${YELLOW}             AWS CloudFormation Template Browser v2.0                      ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
}

# Show current filters
show_filters() {
    echo -e "${DIM}Source: ${GREEN}$CURRENT_SOURCE${NC} ${DIM}| Category: ${GREEN}$CURRENT_CATEGORY${NC} ${DIM}| Search: ${GREEN}${SEARCH_FILTER:-none}${NC}"
    echo -e "${DIM}────────────────────────────────────────────────────────────────────────────────${NC}"
}

# Load templates based on current source
load_templates() {
    local loading_msg="Loading templates from $CURRENT_SOURCE..."
    echo -ne "${BLUE}$loading_msg${NC}"

    case "$CURRENT_SOURCE" in
        production)
            TEMPLATES_CACHE=$(fetch_production_templates 2>/dev/null || echo "[]")
            ;;
        github)
            TEMPLATES_CACHE=$(fetch_github_templates 2>/dev/null || echo "[]")
            ;;
        s3)
            TEMPLATES_CACHE=$(fetch_template_list 2>/dev/null || echo "[]")
            ;;
        quickstarts)
            TEMPLATES_CACHE=$(fetch_quickstart_list 2>/dev/null || echo "[]")
            ;;
    esac

    # Clear loading message
    echo -ne "\r\033[K"

    apply_filters
}

# Apply category and search filters
apply_filters() {
    local filtered="$TEMPLATES_CACHE"

    # Apply category filter
    if [ "$CURRENT_CATEGORY" != "all" ]; then
        filtered=$(echo "$filtered" | jq --arg cat "$CURRENT_CATEGORY" \
            '[.[] | select(.category == $cat)]')
    fi

    # Apply search filter
    if [ -n "$SEARCH_FILTER" ]; then
        filtered=$(echo "$filtered" | jq --arg search "$SEARCH_FILTER" \
            '[.[] | select(
                (.name // "" | test($search; "i")) or
                (.description // "" | test($search; "i")) or
                (.repository // "" | test($search; "i"))
            )]')
    fi

    FILTERED_TEMPLATES="$filtered"

    # Calculate pagination
    local total_items=$(echo "$FILTERED_TEMPLATES" | jq 'length')
    TOTAL_PAGES=$(( (total_items + PAGE_SIZE - 1) / PAGE_SIZE ))
    [ $TOTAL_PAGES -eq 0 ] && TOTAL_PAGES=1

    # Reset to page 1 if current page is out of bounds
    [ $CURRENT_PAGE -gt $TOTAL_PAGES ] && CURRENT_PAGE=1
}

# Display current page of templates
show_templates_page() {
    local start=$(( (CURRENT_PAGE - 1) * PAGE_SIZE ))
    local end=$(( start + PAGE_SIZE ))

    # Get current page items
    local page_items=$(echo "$FILTERED_TEMPLATES" | jq ".[$start:$end]")
    local total_items=$(echo "$FILTERED_TEMPLATES" | jq 'length')

    if [ "$total_items" -eq 0 ]; then
        echo -e "\n${YELLOW}No templates found matching current filters.${NC}\n"
        return
    fi

    # Table header
    printf "\n${BOLD}%-3s %-40s %-15s %-15s${NC}\n" "#" "Name" "Category" "Source/Author"
    echo -e "${DIM}────────────────────────────────────────────────────────────────────────────────${NC}"

    # Display items
    local idx=$start
    echo "$page_items" | jq -r '.[] |
        "\(.name // "unknown")|\(.category // "other")|\(.source // .author // "unknown")"' | \
    while IFS='|' read -r name category source; do
        idx=$((idx + 1))
        # Truncate long names
        [ ${#name} -gt 38 ] && name="${name:0:35}..."
        printf "%-3d %-40s %-15s %-15s\n" "$idx" "$name" "$category" "$source"
    done

    echo ""
    echo -e "${DIM}Page $CURRENT_PAGE of $TOTAL_PAGES (Total: $total_items templates)${NC}"
}

# Show template details
show_template_details() {
    local idx=$1
    local template=$(echo "$FILTERED_TEMPLATES" | jq ".[$((idx-1))]")

    if [ "$template" = "null" ] || [ -z "$template" ]; then
        echo -e "${RED}Invalid template number${NC}"
        return 1
    fi

    show_header
    echo -e "\n${BOLD}${CYAN}Template Details${NC}"
    echo -e "${DIM}────────────────────────────────────────────────────────────────────────────────${NC}\n"

    echo "$template" | jq -r '
        "Name:        \(.name // "N/A")",
        "Category:    \(.category // "N/A")",
        "Source:      \(.source // "N/A")",
        "Author:      \(.author // "N/A")",
        "Repository:  \(.repository // "N/A")",
        "Description: \(.description // "No description available")",
        "",
        "URLs:",
        "  View:      \(.url // "N/A")",
        "  Download:  \(.download_url // .url // "N/A")"'

    echo -e "\n${DIM}────────────────────────────────────────────────────────────────────────────────${NC}"
    echo -e "\n${YELLOW}Actions:${NC}"
    echo "  [d] Download template"
    echo "  [a] Analyze template"
    echo "  [o] Open in browser"
    echo "  [b] Back to list"
    echo ""

    printf "Select action: "
    read -r action
    # Take only first character
    action="${action:0:1}"

    case "$action" in
        d|D)
            download_template_interactive "$idx"
            ;;
        a|A)
            analyze_template_interactive "$idx"
            ;;
        o|O)
            open_in_browser "$idx"
            ;;
        *)
            return 0
            ;;
    esac
}

# Analyze template
analyze_template_interactive() {
    local idx=$1
    local template=$(echo "$FILTERED_TEMPLATES" | jq -r ".[$((idx-1))]")
    local name=$(echo "$template" | jq -r '.name')
    local download_url=$(echo "$template" | jq -r '.download_url // .url // ""')

    if [ -z "$download_url" ] || [ "$download_url" = "null" ]; then
        # For non-downloadable templates, show basic info
        echo -e "${YELLOW}Cannot download template for analysis${NC}"
        echo -e "\n${CYAN}Template Information:${NC}"
        echo "$template" | jq -r '
            "Name: \(.name)",
            "Category: \(.category)",
            "Source: \(.source // .author // "unknown")",
            "Repository: \(.repository // "N/A")"'

        printf "\nPress Enter to continue..."
        read -r
        return 0
    fi

    echo -e "${BLUE}Analyzing template: $name${NC}\n"
    echo -e "${DIM}Downloading template for analysis...${NC}"

    # Download template content
    local content
    content=$(curl -s "$download_url" 2>/dev/null)

    if [ -z "$content" ]; then
        echo -e "${RED}Failed to download template for analysis${NC}"
        printf "Press Enter to continue..."
        read -r
        return 1
    fi

    # Analyze the template
    local analysis
    analysis=$(analyze_template "$content" 2>/dev/null)

    if [ -n "$analysis" ]; then
        show_header
        echo -e "\n${BOLD}${CYAN}Template Analysis: $name${NC}"
        echo -e "${DIM}────────────────────────────────────────────────────────────────────────────────${NC}\n"

        # Parse and display analysis results
        local resource_count=$(echo "$analysis" | jq -r '.resource_count')
        local services=$(echo "$analysis" | jq -r '.services | join(", ")')
        local resource_types=$(echo "$analysis" | jq -r '.resource_types | length')

        echo -e "${GREEN}Resource Summary:${NC}"
        echo -e "  Total Resources:     $resource_count"
        echo -e "  Resource Types:      $resource_types"
        echo -e "  AWS Services:        $services"
        echo ""

        # Check for specific resource types
        echo -e "${GREEN}Infrastructure Components:${NC}"

        if [ "$(echo "$analysis" | jq -r '.has_vpc')" = "true" ]; then
            echo -e "  ${CYAN}✓${NC} VPC/Networking"
        fi

        if [ "$(echo "$analysis" | jq -r '.has_rds')" = "true" ]; then
            echo -e "  ${CYAN}✓${NC} RDS Database"
        fi

        if [ "$(echo "$analysis" | jq -r '.has_lambda')" = "true" ]; then
            echo -e "  ${CYAN}✓${NC} Lambda Functions"
        fi

        if [ "$(echo "$analysis" | jq -r '.has_ecs')" = "true" ]; then
            echo -e "  ${CYAN}✓${NC} ECS/Container Services"
        fi

        if [ "$(echo "$analysis" | jq -r '.has_s3')" = "true" ]; then
            echo -e "  ${CYAN}✓${NC} S3 Storage"
        fi

        echo ""
        echo -e "${GREEN}Resource Types Found:${NC}"
        echo "$analysis" | jq -r '.resource_types[]' | head -15 | while read -r type; do
            echo -e "  • $type"
        done

        # If more than 15 resource types
        local total_types=$(echo "$analysis" | jq -r '.resource_types | length')
        if [ "$total_types" -gt 15 ]; then
            echo -e "  ${DIM}... and $((total_types - 15)) more${NC}"
        fi

        # Estimate costs
        echo ""
        echo -e "${GREEN}Estimated Monthly Costs (USD):${NC}"
        echo -e "${DIM}Note: These are rough estimates based on resource types${NC}"

        for level in minimal light moderate heavy; do
            local cost=$(estimate_template_cost "$content" "$level" 2>/dev/null || echo "0")
            printf "  %-10s: \$%.2f/month\n" "$level" "$cost"
        done

    else
        echo -e "${YELLOW}Unable to analyze template structure${NC}"
        echo -e "The template may be in an unsupported format or empty."
    fi

    echo ""
    printf "Press Enter to continue..."
    read -r
}

# Download template
download_template_interactive() {
    local idx=$1
    local template=$(echo "$FILTERED_TEMPLATES" | jq -r ".[$((idx-1))]")
    local name=$(echo "$template" | jq -r '.name')
    local download_url=$(echo "$template" | jq -r '.download_url // .url // ""')

    if [ -z "$download_url" ] || [ "$download_url" = "null" ]; then
        echo -e "${RED}No download URL available for this template${NC}"
        printf "Press Enter to continue..."
        read -r
        return 1
    fi

    echo -e "${BLUE}Downloading $name...${NC}"
    if curl -s -o "$name" "$download_url"; then
        echo -e "${GREEN}✓ Template saved to: $name${NC}"
    else
        echo -e "${RED}Failed to download template${NC}"
    fi

    printf "Press Enter to continue..."
    read -r
}

# Open template in browser
open_in_browser() {
    local idx=$1
    local url=$(echo "$FILTERED_TEMPLATES" | jq -r ".[$((idx-1))].url // .html_url // \"\"")

    if [ -z "$url" ] || [ "$url" = "null" ]; then
        echo -e "${RED}No URL available for this template${NC}"
        printf "Press Enter to continue..."
        read -r
        return 1
    fi

    if command -v open >/dev/null 2>&1; then
        open "$url"
    elif command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$url"
    else
        echo -e "${YELLOW}URL: $url${NC}"
        echo "Copy and paste this URL into your browser"
        printf "Press Enter to continue..."
    read -r
    fi
}

# Get available categories from current templates
get_current_categories() {
    echo "$TEMPLATES_CACHE" | jq -r '[.[].category] | unique | sort | .[]' 2>/dev/null
}

# Category selection menu
select_category() {
    show_header
    echo -e "\n${BOLD}Select Category${NC}"
    echo -e "${DIM}────────────────────────────────────────────────────────────────────────────────${NC}\n"

    local categories=("all")
    while IFS= read -r cat; do
        [ -n "$cat" ] && categories+=("$cat")
    done < <(get_current_categories)

    local idx=1
    for cat in "${categories[@]}"; do
        printf "  %-2d) %-20s" "$idx" "$cat"
        [ $((idx % 3)) -eq 0 ] && echo ""
        ((idx++))
    done
    [ $((idx % 3)) -ne 1 ] && echo ""

    echo ""
    read -r -p "Select category (1-${#categories[@]}): " choice

    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#categories[@]}" ]; then
        CURRENT_CATEGORY="${categories[$((choice-1))]}"
        CURRENT_PAGE=1
        apply_filters
    fi
}

# Source selection menu
select_source() {
    show_header
    echo -e "\n${BOLD}Select Template Source${NC}"
    echo -e "${DIM}────────────────────────────────────────────────────────────────────────────────${NC}\n"

    echo "  1) Production Templates   - Curated production-ready patterns"
    echo "  2) GitHub Official       - AWS official GitHub templates"
    echo "  3) S3 Samples           - Classic AWS sample templates"
    echo "  4) Quick Starts         - Enterprise Quick Start solutions"

    echo ""
    read -r -p "Select source (1-4): " choice

    case "$choice" in
        1) CURRENT_SOURCE="production" ;;
        2) CURRENT_SOURCE="github" ;;
        3) CURRENT_SOURCE="s3" ;;
        4) CURRENT_SOURCE="quickstarts" ;;
        *) return ;;
    esac

    CURRENT_CATEGORY="all"
    CURRENT_PAGE=1
    SEARCH_FILTER=""
    load_templates
}

# Search templates
search_templates() {
    echo -e "\n${BOLD}Search Templates${NC}"
    read -r -p "Enter search term (empty to clear): " search

    SEARCH_FILTER="$search"
    CURRENT_PAGE=1
    apply_filters
}

# Show help
show_quick_help() {
    echo -e "\n${BOLD}Navigation:${NC}"
    echo "  [n/N] Next page     [p/P] Previous page    [#] View template details"
    echo "  [s/S] Search        [c/C] Categories       [r/R] Change source"
    echo "  [x/X] Clear filters [h/H] Help             [q/Q] Quit"
}

# Main interactive loop
main_loop() {
    # Initial load
    load_templates

    while true; do
        show_header
        show_filters
        show_templates_page
        show_quick_help

        echo ""
        # More compatible read - some systems don't support -n
        printf "> "
        IFS= read -r command
        # If command is longer than 1 char, just take first char for navigation
        if [ ${#command} -gt 1 ]; then
            # Check if it's a number
            if [[ "$command" =~ ^[0-9]+$ ]]; then
                # It's a full number, process as template selection
                show_template_details "$command"
                continue
            else
                # Take just first character for commands
                command="${command:0:1}"
            fi
        fi

        case "$command" in
            n|N)
                [ $CURRENT_PAGE -lt $TOTAL_PAGES ] && ((CURRENT_PAGE++))
                ;;
            p|P)
                [ $CURRENT_PAGE -gt 1 ] && ((CURRENT_PAGE--))
                ;;
            [0-9]*)
                # Read full number
                echo -ne "\r> $command"
                read -r rest
                local num="${command}${rest}"
                if [[ "$num" =~ ^[0-9]+$ ]]; then
                    show_template_details "$num"
                fi
                ;;
            s|S)
                search_templates
                ;;
            c|C)
                select_category
                ;;
            r|R)
                select_source
                ;;
            x|X)
                SEARCH_FILTER=""
                CURRENT_CATEGORY="all"
                CURRENT_PAGE=1
                apply_filters
                ;;
            h|H)
                show_header
                echo -e "\n${BOLD}Help - Template Browser v2${NC}"
                echo -e "${DIM}────────────────────────────────────────────────────────────────────────────────${NC}\n"
                echo "Navigation:"
                echo "  • Use 'n' and 'p' to navigate between pages"
                echo "  • Type a number and press Enter to view template details"
                echo "  • Search filters templates by name, description, and repository"
                echo "  • Categories let you filter by template type"
                echo "  • Sources provide different template collections:"
                echo "    - Production: Curated, production-ready patterns"
                echo "    - GitHub: Official AWS GitHub templates"
                echo "    - S3: Classic AWS sample templates"
                echo "    - Quick Starts: Enterprise solutions"
                echo ""
                printf "Press Enter to continue..."
    read -r
                ;;
            q|Q)
                echo -e "\n${GREEN}Goodbye!${NC}"
                exit 0
                ;;
        esac
    done
}

# Handle command-line arguments for non-interactive use
if [ $# -gt 0 ]; then
    case "$1" in
        --help|-h)
            echo "AWS CloudFormation Template Browser v2"
            echo ""
            echo "Usage: $(basename "$0") [options]"
            echo ""
            echo "Options:"
            echo "  --json           Output all production templates as JSON"
            echo "  --list-sources   List available template sources"
            echo "  --source SOURCE  Select source (production, github, s3, quickstarts)"
            echo "  --search TERM    Search templates"
            echo "  -h, --help       Show this help"
            echo ""
            echo "Run without arguments for interactive mode."
            exit 0
            ;;
        --json)
            fetch_production_templates
            exit 0
            ;;
        --list-sources)
            echo "Available template sources:"
            echo "  production  - Curated production-ready patterns"
            echo "  github      - AWS official GitHub templates"
            echo "  s3          - Classic AWS sample templates"
            echo "  quickstarts - Enterprise Quick Start solutions"
            exit 0
            ;;
        --source)
            CURRENT_SOURCE="${2:-production}"
            load_templates
            echo "$TEMPLATES_CACHE"
            exit 0
            ;;
        --search)
            SEARCH_FILTER="$2"
            load_templates
            echo "$FILTERED_TEMPLATES"
            exit 0
            ;;
    esac
fi

# Run interactive mode
main_loop