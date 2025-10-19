#!/bin/bash

# UI Helpers Demo Script
# Demonstrates all the UI helper functions

# Source the UI helpers library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/ui-helpers.sh"

clear

echo "$(bold '=== UI Helper Library Demo ===')"
echo ""
echo "This script demonstrates all the UI helper functions available."
echo ""

# ============================================================================
section "1. Message Functions"
# ============================================================================

success "This is a success message - use for completed tasks"
error "This is an error message - use for failures"
warning "This is a warning message - use for cautions"
info "This is an info message - use for helpful tips"
debug "This is a debug message (only shown if DEBUG=1)"

echo ""
echo "Export DEBUG=1 to see debug messages:"
DEBUG=1 debug "Now you can see debug output!"

# ============================================================================
section "2. Box Drawing"
# ============================================================================

draw_box "Welcome to AWS Bootstrap"
box_line "Project Code: MYP"
box_line "Environment: Development"
box_line "Region: us-east-1"
close_box

echo ""

draw_box "Simple Box Without Content"
close_box

# ============================================================================
section "3. Progress Indicators"
# ============================================================================

echo "Progress bar example:"
for i in {0..10}; do
    echo -ne "\r$(progress_bar $i 10)"
    sleep 0.2
done
echo ""
success "Progress complete!"

# ============================================================================
section "4. Lists"
# ============================================================================

echo "Bullet list:"
bullet_list \
    "AWS CLI installed" \
    "GitHub CLI authenticated" \
    "Node.js version 20+" \
    "AWS CDK bootstrapped"

echo ""
echo "Numbered list:"
numbered_list \
    "Create AWS accounts" \
    "Bootstrap CDK" \
    "Setup GitHub repository" \
    "Configure billing alerts"

# ============================================================================
section "5. Key-Value Pairs"
# ============================================================================

echo "Configuration summary:"
key_value \
    "Project Code" "MYP" \
    "Email" "user@example.com" \
    "GitHub Org" "my-org" \
    "Repository" "my-project" \
    "Accounts Created" "3"

# ============================================================================
section "6. Status Checks"
# ============================================================================

echo "Checking prerequisites:"
status_check "AWS CLI" 0
status_check "GitHub CLI" 0
status_check "Docker" 1
status_check "Kubernetes" 1

# ============================================================================
section "7. Text Formatting"
# ============================================================================

echo "$(bold 'Bold text') - for emphasis"
echo "$(dim 'Dimmed text') - for less important info"
echo "$(underline 'Underlined text') - for emphasis"
echo ""
echo "Colored text:"
echo "  $(colored "red" "Red text")"
echo "  $(colored "green" "Green text")"
echo "  $(colored "yellow" "Yellow text")"
echo "  $(colored "blue" "Blue text")"
echo "  $(colored "cyan" "Cyan text")"

# ============================================================================
section "8. Separators"
# ============================================================================

echo "Dash separator:"
separator "-" 60

echo ""
echo "Equal sign separator:"
separator "=" 60

echo ""
echo "Star separator:"
separator "*" 60

# ============================================================================
section "9. Loading Indicators"
# ============================================================================

loading "Installing packages"
sleep 1
done_loading

loading "Configuring AWS credentials"
sleep 1
done_loading

loading "Bootstrapping CDK"
sleep 1
done_loading

# ============================================================================
section "10. Interactive Functions (commented out)"
# ============================================================================

info "Interactive functions require user input, so they're commented out in the demo"
echo ""
echo "Available interactive functions:"
bullet_list \
    "confirm() - Yes/No prompts" \
    "menu() - Multi-choice selection" \
    "input() - Text input with validation"

echo ""
echo "Example usage:"
echo ""
echo '  # Confirmation'
echo '  if confirm "Continue with setup?"; then'
echo '      echo "User chose yes"'
echo '  fi'
echo ""
echo '  # Menu selection'
echo '  choice=$(menu "Choose environment:" "Dev" "Staging" "Prod")'
echo '  echo "User selected option $choice"'
echo ""
echo '  # Input with validation'
echo '  email=$(input "Enter email:" "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$")'
echo '  echo "Email: $email"'

# ============================================================================
section "11. Uncomment to try interactive features"
# ============================================================================

# Uncomment the sections below to test interactive features:

# echo ""
# if confirm "Would you like to try the menu function?"; then
#     choice=$(menu "Choose your favorite:" "Coffee" "Tea" "Water")
#     success "You selected option $choice"
# fi

# echo ""
# if confirm "Would you like to try the input function?"; then
#     name=$(input "Enter your name:" ".*" "Anonymous")
#     success "Hello, $name!"
# fi

# ============================================================================
section "Demo Complete!"
# ============================================================================

success "All UI helper functions demonstrated"
info "Source this library in your scripts with:"
echo ""
echo '  source "$(dirname "${BASH_SOURCE[0]}")/lib/ui-helpers.sh"'
echo ""
info "Then use any of the functions shown above"
echo ""