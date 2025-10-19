#!/bin/bash

# UI Helper Library for AWS Multi-Account Bootstrap
# Reusable functions for creating beautiful, interactive CLI experiences
#
# Usage:
#   source "$(dirname "${BASH_SOURCE[0]}")/../lib/ui-helpers.sh"
#
# Functions provided:
#   - Drawing: draw_box, section, separator
#   - Progress: progress_bar, spinner
#   - Interaction: menu, confirm, input
#   - Messaging: success, error, warning, info
#   - Formatting: bold, dim, underline

# ============================================================================
# Colors and Formatting
# ============================================================================

# Standard colors
export UI_RED='\033[0;31m'
export UI_GREEN='\033[0;32m'
export UI_YELLOW='\033[1;33m'
export UI_BLUE='\033[0;34m'
export UI_MAGENTA='\033[0;35m'
export UI_CYAN='\033[0;36m'
export UI_WHITE='\033[0;37m'
export UI_NC='\033[0m'  # No Color

# Text formatting
export UI_BOLD='\033[1m'
export UI_DIM='\033[2m'
export UI_UNDERLINE='\033[4m'
export UI_RESET='\033[0m'

# ============================================================================
# Box Drawing Functions
# ============================================================================

# Draw a box with optional title
# Usage: draw_box "Title" [width]
draw_box() {
    local title="$1"
    local width="${2:-60}"

    echo -e "${UI_CYAN}"
    printf '┌'
    printf '─%.0s' $(seq 1 $((width - 2)))
    printf '┐\n'

    if [ -n "$title" ]; then
        local padding=$(( (width - ${#title} - 4) / 2 ))
        printf '│'
        printf ' %.0s' $(seq 1 $padding)
        printf ' %s ' "$title"
        printf ' %.0s' $(seq 1 $padding)
        # Adjust for odd widths
        if [ $(( (width - ${#title}) % 2 )) -eq 0 ]; then
            printf ' '
        fi
        printf '│\n'

        printf '├'
        printf '─%.0s' $(seq 1 $((width - 2)))
        printf '┤\n'
    fi

    echo -e "${UI_NC}"
}

# Close a box
# Usage: close_box [width]
close_box() {
    local width="${1:-60}"
    echo -e "${UI_CYAN}"
    printf '└'
    printf '─%.0s' $(seq 1 $((width - 2)))
    printf '┘\n'
    echo -e "${UI_NC}"
}

# Print a line inside a box
# Usage: box_line "Text" [width]
box_line() {
    local text="$1"
    local width="${2:-60}"
    local text_length=${#text}
    local padding=$((width - text_length - 4))

    echo -e "${UI_CYAN}│${UI_NC} $text$(printf ' %.0s' $(seq 1 $padding))${UI_CYAN}│${UI_NC}"
}

# Section header with horizontal lines
# Usage: section "Section Title"
section() {
    local title="$1"
    echo ""
    echo -e "${UI_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${UI_NC}"
    echo -e "${UI_CYAN}${title}${UI_NC}"
    echo -e "${UI_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${UI_NC}"
    echo ""
}

# Simple separator line
# Usage: separator [character] [length]
separator() {
    local char="${1:--}"
    local length="${2:-60}"
    printf '%*s\n' "$length" '' | tr ' ' "$char"
}

# ============================================================================
# Progress Indicators
# ============================================================================

# Progress bar
# Usage: progress_bar current total [width]
progress_bar() {
    local current=$1
    local total=$2
    local width="${3:-40}"
    local percent=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))

    echo -n "["
    echo -ne "${UI_GREEN}"
    printf '▓%.0s' $(seq 1 $filled)
    echo -ne "${UI_NC}"
    printf '░%.0s' $(seq 1 $empty)
    printf "] %3d%% (%d/%d)" "$percent" "$current" "$total"
}

# Spinner (for long-running tasks)
# Usage: start_spinner "Message" & SPINNER_PID=$!
#        [do work]
#        stop_spinner $SPINNER_PID
_spinner_chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"

start_spinner() {
    local message="${1:-Working...}"
    local pid=$2
    local delay=0.1
    local i=0

    tput civis  # Hide cursor

    while kill -0 "$pid" 2>/dev/null; do
        local char="${_spinner_chars:i++%${#_spinner_chars}:1}"
        printf "\r%s %s" "$char" "$message"
        sleep $delay
    done

    printf "\r%*s\r" $((${#message} + 2)) ""  # Clear line
    tput cnorm  # Show cursor
}

# ============================================================================
# Interactive Functions
# ============================================================================

# Menu selection
# Usage: choice=$(menu "Choose option:" "Option 1" "Option 2" "Option 3")
menu() {
    local title="$1"
    shift
    local options=("$@")

    draw_box "$title"

    for i in "${!options[@]}"; do
        box_line "  [$((i + 1))] ${options[$i]}"
    done

    close_box

    local choice
    while true; do
        echo -n "Choose [1-${#options[@]}]: "
        read -r choice

        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#options[@]}" ]; then
            echo "$choice"
            return 0
        else
            error "Invalid choice. Please enter a number between 1 and ${#options[@]}"
        fi
    done
}

# Yes/No confirmation prompt
# Usage: if confirm "Continue?"; then ... fi
#        if confirm "Delete files?" "N"; then ... fi  # Default No
confirm() {
    local prompt="$1"
    local default="${2:-Y}"
    local reply

    if [ "$default" = "Y" ] || [ "$default" = "y" ]; then
        echo -ne "${UI_YELLOW}${prompt} [Y/n] ${UI_NC}"
        read -r reply
        reply=${reply:-Y}
    else
        echo -ne "${UI_YELLOW}${prompt} [y/N] ${UI_NC}"
        read -r reply
        reply=${reply:-N}
    fi

    if [[ $reply =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Input prompt with validation
# Usage: email=$(input "Enter email:" "email")
#        name=$(input "Enter name:" ".*" "John Doe")  # With default
input() {
    local prompt="$1"
    local pattern="${2:-.*}"
    local default="$3"
    local value

    while true; do
        if [ -n "$default" ]; then
            echo -ne "${UI_BLUE}${prompt} [${default}] ${UI_NC}"
        else
            echo -ne "${UI_BLUE}${prompt} ${UI_NC}"
        fi

        read -r value
        value=${value:-$default}

        if [ -z "$value" ]; then
            error "Value cannot be empty"
            continue
        fi

        if [[ $value =~ $pattern ]]; then
            echo "$value"
            return 0
        else
            error "Invalid format. Please try again."
        fi
    done
}

# ============================================================================
# Message Functions
# ============================================================================

# Success message
# Usage: success "Operation completed"
success() {
    echo -e "${UI_GREEN}✓ $1${UI_NC}"
}

# Error message
# Usage: error "Something went wrong"
error() {
    echo -e "${UI_RED}✗ $1${UI_NC}" >&2
}

# Warning message
# Usage: warning "This might cause issues"
warning() {
    echo -e "${UI_YELLOW}⚠️  $1${UI_NC}"
}

# Info message
# Usage: info "Additional information"
info() {
    echo -e "${UI_BLUE}ℹ️  $1${UI_NC}"
}

# Debug message (only shown if DEBUG=1)
# Usage: debug "Debug info"
debug() {
    if [ "${DEBUG:-0}" = "1" ]; then
        echo -e "${UI_DIM}[DEBUG] $1${UI_NC}" >&2
    fi
}

# ============================================================================
# Formatting Helpers
# ============================================================================

# Bold text
# Usage: echo "$(bold "Important text")"
bold() {
    echo -e "${UI_BOLD}$1${UI_RESET}"
}

# Dim text
# Usage: echo "$(dim "Less important")"
dim() {
    echo -e "${UI_DIM}$1${UI_RESET}"
}

# Underlined text
# Usage: echo "$(underline "Emphasized")"
underline() {
    echo -e "${UI_UNDERLINE}$1${UI_RESET}"
}

# Colored text
# Usage: echo "$(colored "red" "Error message")"
colored() {
    local color="$1"
    local text="$2"

    case "$color" in
        red)     echo -e "${UI_RED}${text}${UI_NC}" ;;
        green)   echo -e "${UI_GREEN}${text}${UI_NC}" ;;
        yellow)  echo -e "${UI_YELLOW}${text}${UI_NC}" ;;
        blue)    echo -e "${UI_BLUE}${text}${UI_NC}" ;;
        magenta) echo -e "${UI_MAGENTA}${text}${UI_NC}" ;;
        cyan)    echo -e "${UI_CYAN}${text}${UI_NC}" ;;
        *)       echo "$text" ;;
    esac
}

# ============================================================================
# Utility Functions
# ============================================================================

# Print a list with bullets
# Usage: bullet_list "Item 1" "Item 2" "Item 3"
bullet_list() {
    for item in "$@"; do
        echo "  • $item"
    done
}

# Print a numbered list
# Usage: numbered_list "First" "Second" "Third"
numbered_list() {
    local i=1
    for item in "$@"; do
        echo "  $i. $item"
        ((i++))
    done
}

# Print key-value pairs
# Usage: key_value "Name" "John Doe" "Email" "john@example.com"
key_value() {
    local max_key_length=0
    local keys=()
    local values=()

    # Collect keys and values
    while [ $# -gt 0 ]; do
        keys+=("$1")
        values+=("$2")
        if [ ${#1} -gt "$max_key_length" ]; then
            max_key_length=${#1}
        fi
        shift 2
    done

    # Print formatted pairs
    for i in "${!keys[@]}"; do
        printf "  %-${max_key_length}s : %s\n" "${keys[$i]}" "${values[$i]}"
    done
}

# ============================================================================
# Status Indicators
# ============================================================================

# Show a status check (✓ or ✗)
# Usage: status_check "Item name" 0  # Success (exit code 0)
#        status_check "Item name" 1  # Failure (non-zero)
status_check() {
    local name="$1"
    local status=$2

    if [ "$status" -eq 0 ]; then
        echo -e "${UI_GREEN}✓${UI_NC} $name"
    else
        echo -e "${UI_RED}✗${UI_NC} $name"
    fi
}

# Show a loading line
# Usage: loading "Installing packages..."
#        [do work]
#        done_loading
loading() {
    echo -ne "${UI_BLUE}⏳${UI_NC} $1..."
}

done_loading() {
    echo -e " ${UI_GREEN}✓${UI_NC}"
}

# ============================================================================
# Examples (commented out)
# ============================================================================

# Uncomment to run examples
# if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
#     echo "=== UI Helper Library Examples ==="
#     echo ""
#
#     section "Messages"
#     success "This is a success message"
#     error "This is an error message"
#     warning "This is a warning"
#     info "This is an info message"
#
#     echo ""
#     section "Box Drawing"
#     draw_box "Sample Box"
#     box_line "Line 1: Hello World"
#     box_line "Line 2: With padding"
#     close_box
#
#     echo ""
#     section "Progress"
#     for i in {0..10}; do
#         echo -ne "\r$(progress_bar $i 10)"
#         sleep 0.1
#     done
#     echo ""
#
#     echo ""
#     section "Lists"
#     bullet_list "First item" "Second item" "Third item"
#     echo ""
#     numbered_list "First step" "Second step" "Third step"
#
#     echo ""
#     section "Key-Value Pairs"
#     key_value "Name" "AWS Bootstrap" "Version" "1.4.0" "Status" "Active"
# fi