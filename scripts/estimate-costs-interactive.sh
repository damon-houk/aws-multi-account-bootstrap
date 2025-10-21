#!/bin/bash

# Interactive Cost Estimator for AWS Multi-Account Bootstrap
# Provides a user-friendly interface to explore different cost scenarios

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the cost estimator
source "$SCRIPT_DIR/lib/cost-estimator.sh"

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
NUM_ACCOUNTS=3
USAGE_LEVEL="light"
SELECTED_STACKS=""
REGION="${AWS_DEFAULT_REGION:-us-east-2}"
SHOW_BREAKDOWN=true

# Available regions (common ones)
REGIONS=(
    "us-east-1:US East (N. Virginia)"
    "us-east-2:US East (Ohio)"
    "us-west-1:US West (N. California)"
    "us-west-2:US West (Oregon)"
    "eu-west-1:EU (Ireland)"
    "eu-central-1:EU (Frankfurt)"
    "ap-southeast-1:Asia Pacific (Singapore)"
    "ap-northeast-1:Asia Pacific (Tokyo)"
)

# Available stacks
STACKS=(
    "api-lambda:Serverless API with Lambda"
    "static-website:S3 + CloudFront hosting"
    "rds-postgres:Managed PostgreSQL database"
    "ecs-fargate:Serverless containers"
    "vpc-nat:NAT Gateway for private subnets"
)

# Clear screen and show header
show_header() {
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}💰 AWS Multi-Account Bootstrap - Interactive Cost Estimator${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Show current configuration
show_current_config() {
    echo -e "${BLUE}Current Configuration:${NC}"
    echo -e "  ${BOLD}Accounts:${NC} $NUM_ACCOUNTS"
    echo -e "  ${BOLD}Region:${NC} $REGION"
    echo -e "  ${BOLD}Usage Level:${NC} $USAGE_LEVEL - $(get_usage_level_description "$USAGE_LEVEL")"

    if [ -n "$SELECTED_STACKS" ]; then
        echo -e "  ${BOLD}Additional Stacks:${NC}"
        IFS=',' read -ra STACK_ARRAY <<< "$SELECTED_STACKS"
        for stack in "${STACK_ARRAY[@]}"; do
            echo "    • $stack"
        done
    else
        echo -e "  ${BOLD}Additional Stacks:${NC} None"
    fi
    echo ""
}

# Calculate and show current estimate
show_current_estimate() {
    echo -e "${GREEN}Calculating estimate...${NC}"
    echo ""

    # Use the display_cost_breakdown function but capture output
    display_cost_breakdown "$NUM_ACCOUNTS" true "$SELECTED_STACKS" "$REGION" "$USAGE_LEVEL"
}

# Change number of accounts
change_accounts() {
    echo -e "${YELLOW}Enter number of AWS accounts (1-20):${NC}"
    read -r -p "> " new_accounts

    if [[ "$new_accounts" =~ ^[0-9]+$ ]] && [ "$new_accounts" -ge 1 ] && [ "$new_accounts" -le 20 ]; then
        NUM_ACCOUNTS=$new_accounts
        echo -e "${GREEN}✓ Accounts set to $NUM_ACCOUNTS${NC}"
    else
        echo -e "${RED}Invalid input. Please enter a number between 1 and 20.${NC}"
    fi

    echo ""
    read -r -p "Press Enter to continue..."
}

# Change region
change_region() {
    echo -e "${YELLOW}Select AWS Region:${NC}"
    echo ""

    local i=1
    for region_info in "${REGIONS[@]}"; do
        IFS=':' read -r code name <<< "$region_info"
        if [ "$code" == "$REGION" ]; then
            echo -e "  ${GREEN}$i) $name ($code) [current]${NC}"
        else
            echo "  $i) $name ($code)"
        fi
        ((i++))
    done

    echo ""
    echo -e "${YELLOW}Enter choice (1-${#REGIONS[@]}):${NC}"
    read -r -p "> " choice

    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#REGIONS[@]}" ]; then
        IFS=':' read -r code name <<< "${REGIONS[$((choice-1))]}"
        REGION=$code
        echo -e "${GREEN}✓ Region set to $name ($code)${NC}"
    else
        echo -e "${RED}Invalid choice.${NC}"
    fi

    echo ""
    read -r -p "Press Enter to continue..."
}

# Change usage level
change_usage_level() {
    echo -e "${YELLOW}Select Usage Level:${NC}"
    echo ""

    local levels=("minimal" "light" "moderate" "heavy")
    local i=1

    for level in "${levels[@]}"; do
        local desc=$(get_usage_level_description "$level")
        if [ "$level" == "$USAGE_LEVEL" ]; then
            echo -e "  ${GREEN}$i) ${BOLD}$level${NC}${GREEN} - $desc [current]${NC}"
        else
            echo -e "  $i) ${BOLD}$level${NC} - $desc"
        fi
        ((i++))
    done

    echo ""
    echo "  5) Show detailed usage level definitions"
    echo ""
    echo -e "${YELLOW}Enter choice (1-5):${NC}"
    read -r -p "> " choice

    case "$choice" in
        1) USAGE_LEVEL="minimal"
           echo -e "${GREEN}✓ Usage level set to minimal${NC}" ;;
        2) USAGE_LEVEL="light"
           echo -e "${GREEN}✓ Usage level set to light${NC}" ;;
        3) USAGE_LEVEL="moderate"
           echo -e "${GREEN}✓ Usage level set to moderate${NC}" ;;
        4) USAGE_LEVEL="heavy"
           echo -e "${GREEN}✓ Usage level set to heavy${NC}" ;;
        5) echo ""
           explain_usage_levels
           echo "" ;;
        *) echo -e "${RED}Invalid choice.${NC}" ;;
    esac

    echo ""
    read -r -p "Press Enter to continue..."
}

# Manage additional stacks
manage_stacks() {
    echo -e "${YELLOW}Manage Additional Stacks:${NC}"
    echo ""

    # Parse current stacks into array
    if [ -n "$SELECTED_STACKS" ]; then
        IFS=',' read -ra CURRENT_STACKS <<< "$SELECTED_STACKS"
    else
        CURRENT_STACKS=()
    fi

    local i=1
    for stack_info in "${STACKS[@]}"; do
        IFS=':' read -r code name <<< "$stack_info"

        # Check if stack is currently selected
        local is_selected=false
        for selected in "${CURRENT_STACKS[@]}"; do
            if [ "$selected" == "$code" ]; then
                is_selected=true
                break
            fi
        done

        if [ "$is_selected" == true ]; then
            echo -e "  ${GREEN}[$i] ✓ $code - $name${NC}"
        else
            echo "  [$i]   $code - $name"
        fi
        ((i++))
    done

    echo ""
    echo "  [A] Select all stacks"
    echo "  [N] Clear all stacks"
    echo "  [Q] Done"
    echo ""
    echo -e "${YELLOW}Toggle stack by number, or choose an option:${NC}"
    read -r -p "> " choice

    case "$choice" in
        [1-5])
            # Toggle individual stack
            if [[ "$choice" -le "${#STACKS[@]}" ]]; then
                IFS=':' read -r code name <<< "${STACKS[$((choice-1))]}"

                # Check if already selected
                local new_stacks=""
                local found=false

                for selected in "${CURRENT_STACKS[@]}"; do
                    if [ "$selected" == "$code" ]; then
                        found=true
                    else
                        if [ -n "$new_stacks" ]; then
                            new_stacks="$new_stacks,$selected"
                        else
                            new_stacks="$selected"
                        fi
                    fi
                done

                if [ "$found" == false ]; then
                    # Add the stack
                    if [ -n "$new_stacks" ]; then
                        new_stacks="$new_stacks,$code"
                    else
                        new_stacks="$code"
                    fi
                    echo -e "${GREEN}✓ Added $code${NC}"
                else
                    echo -e "${YELLOW}✓ Removed $code${NC}"
                fi

                SELECTED_STACKS="$new_stacks"
            fi

            # Recurse to show updated menu
            manage_stacks
            ;;

        [Aa])
            # Select all
            local all_stacks=""
            for stack_info in "${STACKS[@]}"; do
                IFS=':' read -r code name <<< "$stack_info"
                if [ -n "$all_stacks" ]; then
                    all_stacks="$all_stacks,$code"
                else
                    all_stacks="$code"
                fi
            done
            SELECTED_STACKS="$all_stacks"
            echo -e "${GREEN}✓ All stacks selected${NC}"
            echo ""
            read -r -p "Press Enter to continue..."
            ;;

        [Nn])
            # Clear all
            SELECTED_STACKS=""
            echo -e "${YELLOW}✓ All stacks cleared${NC}"
            echo ""
            read -r -p "Press Enter to continue..."
            ;;

        [Qq])
            # Done
            return
            ;;

        *)
            echo -e "${RED}Invalid choice.${NC}"
            echo ""
            read -r -p "Press Enter to continue..."
            manage_stacks
            ;;
    esac
}

# Export current configuration
export_config() {
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local filename="aws_cost_estimate_${timestamp}.txt"

    echo -e "${YELLOW}Exporting current estimate to $filename...${NC}"

    {
        echo "AWS Multi-Account Bootstrap - Cost Estimate"
        echo "Generated: $(date)"
        echo "=========================================="
        echo ""
        echo "Configuration:"
        echo "  Accounts: $NUM_ACCOUNTS"
        echo "  Region: $REGION"
        echo "  Usage Level: $USAGE_LEVEL - $(get_usage_level_description "$USAGE_LEVEL")"
        echo "  Additional Stacks: ${SELECTED_STACKS:-None}"
        echo ""
        # Disable colors for export and strip ANSI codes
        NO_COLOR=1 display_cost_breakdown "$NUM_ACCOUNTS" true "$SELECTED_STACKS" "$REGION" "$USAGE_LEVEL" 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g'
    } > "$filename"

    echo -e "${GREEN}✓ Estimate exported to $filename${NC}"
    echo ""
    read -r -p "Press Enter to continue..."
}

# Main menu
main_menu() {
    while true; do
        show_header
        show_current_config

        echo -e "${BLUE}Options:${NC}"
        echo "  1) Show current cost estimate"
        echo "  2) Change number of accounts [$NUM_ACCOUNTS]"
        echo "  3) Change region [$REGION]"
        echo "  4) Change usage level [$USAGE_LEVEL]"
        echo "  5) Manage additional stacks [$(echo "$SELECTED_STACKS" | tr ',' ' ' | wc -w | xargs) selected]"
        echo "  6) Export estimate to file"
        echo "  7) Exit"
        echo ""
        echo -e "${YELLOW}Enter choice (1-7):${NC}"
        read -r -p "> " choice

        case "$choice" in
            1)
                show_header
                show_current_config
                show_current_estimate
                echo ""
                read -r -p "Press Enter to continue..."
                ;;
            2)
                show_header
                change_accounts
                ;;
            3)
                show_header
                change_region
                ;;
            4)
                show_header
                change_usage_level
                ;;
            5)
                show_header
                manage_stacks
                ;;
            6)
                export_config
                ;;
            7)
                echo -e "${GREEN}Thank you for using the AWS Cost Estimator!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid choice. Please try again.${NC}"
                sleep 1
                ;;
        esac
    done
}

# Check if running in interactive mode
if [ -t 0 ] && [ -t 1 ]; then
    # Running interactively
    main_menu
else
    # Not interactive, show usage
    echo "This script must be run interactively."
    echo "Usage: $0"
    exit 1
fi