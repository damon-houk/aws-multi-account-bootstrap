#!/usr/bin/env bash

# Prerequisite Checker v2 - Enhanced UX
# AWS Multi-Account Bootstrap
#
# Design Philosophy:
# - Respect user's time (Quick Mode for power users)
# - Provide guidance without overwhelming (Progressive disclosure)
# - Make the happy path delightful (Positive messaging)
# - Allow graceful exits (Resume capability)
#
# Requirements: Bash 4.0+ (for modern UX features)

# Check bash version first
if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Enhanced Prerequisite Checker Requires Bash 4+"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "You're running Bash ${BASH_VERSION} (from $(which bash))"
    echo ""
    echo "Why upgrade?"
    echo "  • Better interactive UX (Quick Install mode, progress bars)"
    echo "  • Modern shell features this tool uses for a great experience"
    echo ""
    echo "Why does macOS ship with old Bash?"
    echo "  • Apple stopped at Bash 3.2 (2007) due to GPLv3 licensing"
    echo "  • Newer Bash versions use a license Apple doesn't bundle"
    echo "  • This is a macOS-specific limitation, not a technical one"
    echo ""
    echo "Quick fix (2 minutes):"
    echo "  brew install bash"
    echo "  # Then rerun this tool - it will use the new bash automatically"
    echo ""
    echo "Alternative:"
    echo "  • Run setup with -y flag (uses basic fallback checker)"
    echo "  • Or manually install: Git, Node 20+, AWS CLI, GitHub CLI, jq, CDK"
    echo ""
    echo "Your choice - either path works fine!"
    echo ""
    exit 1
fi

# Source UI helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/ui-helpers.sh
source "$SCRIPT_DIR/ui-helpers.sh"

# ============================================================================
# Configuration
# ============================================================================

declare -A TOOL_INFO=(
    ["git"]="Git|git --version|2.23.0|Modern workflows"
    ["node"]="Node.js|node --version|20.0.0|CDK requirement (Node 18 EOL)"
    ["aws"]="AWS CLI|aws --version|2.0.0|v2 API compatibility"
    ["gh"]="GitHub CLI|gh --version|2.0.0|OIDC support"
    ["jq"]="jq|jq --version|1.6|Security fixes"
    ["cdk"]="AWS CDK|cdk --version|2.0.0|CDK v2 (requires Node.js)"
)

# Dependency order matters!
DEPENDENCY_ORDER=("git" "node" "aws" "gh" "jq" "cdk")

# ============================================================================
# Platform Detection
# ============================================================================

detect_platform() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/os-release ]; then
            # shellcheck disable=SC1091
            . /etc/os-release
            echo "linux-$ID"
        else
            echo "linux"
        fi
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
        echo "windows"
    else
        echo "unknown"
    fi
}

detect_package_manager() {
    local platform
    platform=$(detect_platform)

    case "$platform" in
        macos)
            if command -v brew &> /dev/null; then
                echo "brew"
            else
                echo "none"
            fi
            ;;
        linux-ubuntu|linux-debian)
            echo "apt"
            ;;
        linux-fedora|linux-rhel|linux-centos)
            echo "dnf"
            ;;
        windows)
            if command -v winget &> /dev/null; then
                echo "winget"
            else
                echo "none"
            fi
            ;;
        *)
            echo "none"
            ;;
    esac
}

# ============================================================================
# Dependency Checking
# ============================================================================

get_installed_version() {
    local cmd=$1

    case $cmd in
        git)
            git --version 2>/dev/null | awk '{print $3}'
            ;;
        node)
            node --version 2>/dev/null
            ;;
        aws)
            aws --version 2>/dev/null | cut -d' ' -f1 | cut -d'/' -f2
            ;;
        gh)
            gh --version 2>/dev/null | head -1 | awk '{print $3}'
            ;;
        jq)
            jq --version 2>/dev/null | cut -d'-' -f2
            ;;
        cdk)
            cdk --version 2>/dev/null | awk '{print $1}'
            ;;
    esac
}

check_dependency() {
    local cmd=$1

    if command -v "$cmd" &> /dev/null; then
        echo "installed"
    else
        echo "missing"
    fi
}

get_node_quality_message() {
    local version=$1
    local major=${version%%.*}
    major=${major#v}

    if [ "$major" -lt 20 ]; then
        echo "⚠️  upgrade needed (Node 18 reached EOL April 2025)"
    elif [ "$major" -eq 20 ]; then
        echo "✓ meets requirements (consider Node 22 LTS for longer support)"
    elif [ "$major" -eq 22 ]; then
        echo "✨ excellent (LTS active until April 2027)"
    else
        echo "✨ cutting edge (latest version)"
    fi
}

# ============================================================================
# Check All Dependencies
# ============================================================================

check_all_dependencies() {
    local -n missing_ref=$1
    local -n installed_ref=$2

    missing_ref=()
    installed_ref=()

    for cmd in "${DEPENDENCY_ORDER[@]}"; do
        if [ "$(check_dependency "$cmd")" = "installed" ]; then
            installed_ref+=("$cmd")
        else
            missing_ref+=("$cmd")
        fi
    done
}

# ============================================================================
# Display Functions
# ============================================================================

show_check_results() {
    local -n missing_ref=$1
    local -n installed_ref=$2
    local total=${#DEPENDENCY_ORDER[@]}
    local checked=0

    echo ""
    info "Checking prerequisites..."
    echo ""

    for cmd in "${DEPENDENCY_ORDER[@]}"; do
        ((checked++))
        local version quality_msg
        IFS='|' read -r name _ min_ver reason <<< "${TOOL_INFO[$cmd]}"

        # Progress indicator
        local progress_bar=""
        for ((i=0; i<total; i++)); do
            if [ $i -lt $checked ]; then
                progress_bar+="●"
            else
                progress_bar+="○"
            fi
        done

        printf "\r[%s] %d/%d " "$progress_bar" "$checked" "$total"
        sleep 0.1  # Slight delay for visual effect

        if [ "$(check_dependency "$cmd")" = "installed" ]; then
            version=$(get_installed_version "$cmd")

            # Special handling for Node.js quality message
            if [ "$cmd" = "node" ]; then
                quality_msg=$(get_node_quality_message "$version")
                echo ""
                success "✓ $name"
                success "  Version: $version $quality_msg"
            else
                echo ""
                success "✓ $name"
                success "  Version: $version"
            fi
        else
            echo ""
            error "✗ $name"
            info "  Required: ≥$min_ver ($reason)"

            # Special message for CDK if Node is available
            if [ "$cmd" = "cdk" ] && command -v npm &> /dev/null; then
                info "  → Can install via: npm install -g aws-cdk"
            fi
        fi
    done

    echo ""
}

# ============================================================================
# Quick Mode
# ============================================================================

show_quick_install() {
    local -n missing_ref=$1
    local platform pkg_mgr
    platform=$(detect_platform)
    pkg_mgr=$(detect_package_manager)

    clear
    section "Quick Install Mode"
    echo ""

    info "Platform detected: $(bold "$platform")"
    if [ "$pkg_mgr" != "none" ]; then
        success "Package manager: $(bold "$pkg_mgr")"
    else
        warning "No package manager detected"
    fi
    echo ""

    draw_box "Copy-Paste Installation"
    box_line ""

    case "$pkg_mgr" in
        brew)
            box_line "Run this command in your terminal:"
            box_line ""
            close_box
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            bold "# Install all missing dependencies"
            local brew_pkgs=()
            for cmd in "${missing_ref[@]}"; do
                case $cmd in
                    git) brew_pkgs+=("git") ;;
                    node) brew_pkgs+=("node") ;;
                    aws) info "# AWS CLI requires manual download (Homebrew version may be outdated)" ;;
                    gh) brew_pkgs+=("gh") ;;
                    jq) brew_pkgs+=("jq") ;;
                    cdk) ;;  # Installed via npm
                esac
            done

            if [ ${#brew_pkgs[@]} -gt 0 ]; then
                echo "brew install ${brew_pkgs[*]}"
            fi

            if [[ " ${missing_ref[*]} " =~ " aws " ]]; then
                echo ""
                echo "# AWS CLI (recommended method):"
                echo "curl \"https://awscli.amazonaws.com/AWSCLIV2.pkg\" -o \"AWSCLIV2.pkg\""
                echo "sudo installer -pkg AWSCLIV2.pkg -target /"
            fi

            if [[ " ${missing_ref[*]} " =~ " cdk " ]]; then
                echo ""
                echo "# AWS CDK (requires Node.js):"
                if command -v node &> /dev/null; then
                    echo "npm install -g aws-cdk"
                else
                    warning "# Install Node.js first, then run: npm install -g aws-cdk"
                fi
            fi
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            ;;

        apt)
            box_line "Run these commands in your terminal:"
            box_line ""
            close_box
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "sudo apt-get update"

            for cmd in "${missing_ref[@]}"; do
                case $cmd in
                    git)
                        echo "sudo apt-get install -y git"
                        ;;
                    node)
                        echo ""
                        echo "# Node.js 20 LTS"
                        echo "curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -"
                        echo "sudo apt-get install -y nodejs"
                        ;;
                    aws)
                        echo ""
                        echo "# AWS CLI v2"
                        echo "curl \"https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip\" -o \"awscliv2.zip\""
                        echo "unzip awscliv2.zip"
                        echo "sudo ./aws/install"
                        ;;
                    gh)
                        echo ""
                        echo "# GitHub CLI"
                        echo "curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg"
                        echo "sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg"
                        echo "echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main\" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null"
                        echo "sudo apt-get update"
                        echo "sudo apt-get install -y gh"
                        ;;
                    jq)
                        echo "sudo apt-get install -y jq"
                        ;;
                    cdk)
                        if command -v node &> /dev/null; then
                            echo ""
                            echo "# AWS CDK"
                            echo "npm install -g aws-cdk"
                        fi
                        ;;
                esac
            done
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            ;;

        dnf)
            box_line "Run these commands in your terminal:"
            box_line ""
            close_box
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            for cmd in "${missing_ref[@]}"; do
                case $cmd in
                    git) echo "sudo dnf install -y git" ;;
                    node)
                        echo "curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -"
                        echo "sudo dnf install -y nodejs"
                        ;;
                    aws)
                        echo ""
                        echo "# AWS CLI v2"
                        echo "curl \"https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip\" -o \"awscliv2.zip\""
                        echo "unzip awscliv2.zip"
                        echo "sudo ./aws/install"
                        ;;
                    gh) echo "sudo dnf install -y gh" ;;
                    jq) echo "sudo dnf install -y jq" ;;
                    cdk)
                        if command -v node &> /dev/null; then
                            echo "npm install -g aws-cdk"
                        fi
                        ;;
                esac
            done
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            ;;

        winget)
            box_line "Run these commands in PowerShell (Admin):"
            box_line ""
            close_box
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            for cmd in "${missing_ref[@]}"; do
                case $cmd in
                    git) echo "winget install Git.Git" ;;
                    node) echo "winget install OpenJS.NodeJS.LTS" ;;
                    aws) echo "winget install Amazon.AWSCLI" ;;
                    gh) echo "winget install --id GitHub.cli" ;;
                    jq) echo "winget install jqlang.jq" ;;
                    cdk)
                        if command -v node &> /dev/null; then
                            echo "npm install -g aws-cdk"
                        fi
                        ;;
                esac
            done
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            ;;

        *)
            box_line "Manual installation required"
            box_line ""
            close_box
            echo ""
            warning "No automatic package manager detected"
            echo ""
            info "Please install manually:"
            for cmd in "${missing_ref[@]}"; do
                IFS='|' read -r name _ _ _ <<< "${TOOL_INFO[$cmd]}"
                case $cmd in
                    git) echo "  • Git: https://git-scm.com/downloads" ;;
                    node) echo "  • Node.js: https://nodejs.org" ;;
                    aws) echo "  • AWS CLI: https://aws.amazon.com/cli/" ;;
                    gh) echo "  • GitHub CLI: https://cli.github.com" ;;
                    jq) echo "  • jq: https://stedolan.github.io/jq/download/" ;;
                    cdk) echo "  • AWS CDK: npm install -g aws-cdk (requires Node.js)" ;;
                esac
            done
            ;;
    esac

    echo ""
    echo ""
    if ! confirm "Have you installed the dependencies?"; then
        return 1
    fi

    # Re-check
    verify_installation "${missing_ref[@]}"
}

# ============================================================================
# Interactive Mode
# ============================================================================

show_interactive_guide() {
    local -n missing_ref=$1
    local total=${#missing_ref[@]}
    local current=0

    clear
    section "Interactive Installation Guide"
    echo ""

    info "We'll install each dependency one at a time"
    info "You can skip any dependency and resume later"
    echo ""

    for cmd in "${missing_ref[@]}"; do
        ((current++))

        clear
        IFS='|' read -r name _ min_ver reason <<< "${TOOL_INFO[$cmd]}"

        draw_box "Installing: $name [$current/$total]"
        box_line ""
        box_line "Required: ≥$min_ver"
        box_line "Reason: $reason"
        box_line ""
        close_box

        echo ""

        # Show installation guide for this specific dependency
        show_single_dependency_guide "$cmd"

        echo ""
        echo "─────────────────────────────────────────────────────────────"
        echo ""

        # Ask what to do
        echo "What would you like to do?"
        echo ""
        echo "  [C] Continue - I've installed it"
        echo "  [S] Skip - I'll install this later"
        echo "  [R] Re-check - Verify if it's installed now"
        echo "  [E] Exit - I'll finish this later"
        echo ""

        while true; do
            read -rp "Your choice [C/S/R/E]: " choice
            case ${choice,,} in
                c)
                    # Check if actually installed
                    if [ "$(check_dependency "$cmd")" = "installed" ]; then
                        success "✓ $name is now installed!"
                        sleep 1
                        break
                    else
                        error "✗ $name is still not detected"
                        info "Make sure it's in your PATH and try 'Re-check'"
                    fi
                    ;;
                s)
                    info "Skipping $name for now"
                    sleep 1
                    break
                    ;;
                r)
                    if [ "$(check_dependency "$cmd")" = "installed" ]; then
                        success "✓ $name is installed!"
                        sleep 1
                        break
                    else
                        error "✗ $name is still not detected"
                        info "Make sure it's installed and in your PATH"
                    fi
                    ;;
                e)
                    info "Exiting... You can run this checker again later"
                    return 1
                    ;;
                *)
                    warning "Invalid choice. Please enter C, S, R, or E"
                    ;;
            esac
        done
    done

    # Final verification
    verify_installation "${missing_ref[@]}"
}

show_single_dependency_guide() {
    local cmd=$1
    local platform
    platform=$(detect_platform)

    case $cmd in
        git)
            case $platform in
                macos)
                    bold "macOS - Installation options:"
                    echo ""
                    numbered_list \
                        "Install Xcode Command Line Tools: xcode-select --install" \
                        "Or install via Homebrew: brew install git"
                    ;;
                linux-ubuntu|linux-debian)
                    bold "Ubuntu/Debian - Installation:"
                    echo ""
                    echo "  sudo apt-get update && sudo apt-get install -y git"
                    ;;
                linux-fedora|linux-rhel|linux-centos)
                    bold "Fedora/RHEL/CentOS - Installation:"
                    echo ""
                    echo "  sudo dnf install -y git"
                    ;;
                windows)
                    bold "Windows - Installation:"
                    echo ""
                    echo "  winget install Git.Git"
                    echo ""
                    info "Or download from: https://git-scm.com/download/win"
                    ;;
                *)
                    echo "Visit: https://git-scm.com/downloads"
                    ;;
            esac
            ;;

        node)
            case $platform in
                macos)
                    bold "macOS - Installation options:"
                    echo ""
                    numbered_list \
                        "Via Homebrew: brew install node" \
                        "Or download from: https://nodejs.org (Node 22 LTS recommended)"
                    ;;
                linux-ubuntu|linux-debian)
                    bold "Ubuntu/Debian - Installation (Node 20 LTS):"
                    echo ""
                    echo "  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -"
                    echo "  sudo apt-get install -y nodejs"
                    ;;
                linux-fedora|linux-rhel|linux-centos)
                    bold "Fedora/RHEL/CentOS - Installation:"
                    echo ""
                    echo "  curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -"
                    echo "  sudo dnf install -y nodejs"
                    ;;
                windows)
                    bold "Windows - Installation:"
                    echo ""
                    echo "  winget install OpenJS.NodeJS.LTS"
                    echo ""
                    info "Or download from: https://nodejs.org"
                    ;;
                *)
                    echo "Visit: https://nodejs.org (Node 22 LTS recommended)"
                    ;;
            esac
            ;;

        aws)
            case $platform in
                macos)
                    bold "macOS - Installation:"
                    echo ""
                    echo "  curl \"https://awscli.amazonaws.com/AWSCLIV2.pkg\" -o \"AWSCLIV2.pkg\""
                    echo "  sudo installer -pkg AWSCLIV2.pkg -target /"
                    ;;
                linux*)
                    bold "Linux - Installation:"
                    echo ""
                    echo "  curl \"https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip\" -o \"awscliv2.zip\""
                    echo "  unzip awscliv2.zip"
                    echo "  sudo ./aws/install"
                    ;;
                windows)
                    bold "Windows - Installation:"
                    echo ""
                    echo "  winget install Amazon.AWSCLI"
                    ;;
                *)
                    echo "Visit: https://aws.amazon.com/cli/"
                    ;;
            esac
            ;;

        gh)
            case $platform in
                macos)
                    bold "macOS - Installation:"
                    echo ""
                    echo "  brew install gh"
                    ;;
                linux-ubuntu|linux-debian)
                    bold "Ubuntu/Debian - Installation:"
                    echo ""
                    echo "  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg"
                    echo "  sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg"
                    echo "  echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main\" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null"
                    echo "  sudo apt-get update && sudo apt-get install -y gh"
                    ;;
                linux-fedora|linux-rhel|linux-centos)
                    bold "Fedora/RHEL/CentOS - Installation:"
                    echo ""
                    echo "  sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo"
                    echo "  sudo dnf install -y gh"
                    ;;
                windows)
                    bold "Windows - Installation:"
                    echo ""
                    echo "  winget install --id GitHub.cli"
                    ;;
                *)
                    echo "Visit: https://cli.github.com"
                    ;;
            esac
            ;;

        jq)
            case $platform in
                macos)
                    bold "macOS - Installation:"
                    echo ""
                    echo "  brew install jq"
                    ;;
                linux-ubuntu|linux-debian)
                    bold "Ubuntu/Debian - Installation:"
                    echo ""
                    echo "  sudo apt-get install -y jq"
                    ;;
                linux-fedora|linux-rhel|linux-centos)
                    bold "Fedora/RHEL/CentOS - Installation:"
                    echo ""
                    echo "  sudo dnf install -y jq"
                    ;;
                windows)
                    bold "Windows - Installation:"
                    echo ""
                    echo "  winget install jqlang.jq"
                    ;;
                *)
                    echo "Visit: https://stedolan.github.io/jq/download/"
                    ;;
            esac
            ;;

        cdk)
            if ! command -v npm &> /dev/null; then
                error "AWS CDK requires Node.js to be installed first"
                info "Please install Node.js, then you can install CDK with:"
                echo "  npm install -g aws-cdk"
            else
                bold "AWS CDK - Installation:"
                echo ""
                echo "  npm install -g aws-cdk"
            fi
            ;;
    esac
}

# ============================================================================
# Manual Mode
# ============================================================================

show_manual_links() {
    local -n missing_ref=$1

    clear
    section "Manual Installation"
    echo ""

    info "Official documentation links for missing dependencies:"
    echo ""

    for cmd in "${missing_ref[@]}"; do
        IFS='|' read -r name _ _ _ <<< "${TOOL_INFO[$cmd]}"
        bold "• $name"
        case $cmd in
            git) echo "  https://git-scm.com/downloads" ;;
            node) echo "  https://nodejs.org (Node 22 LTS recommended)" ;;
            aws) echo "  https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html" ;;
            gh) echo "  https://cli.github.com" ;;
            jq) echo "  https://stedolan.github.io/jq/download/" ;;
            cdk) echo "  https://docs.aws.amazon.com/cdk/v2/guide/getting_started.html" ;;
        esac
        echo ""
    done

    if ! confirm "Have you installed the dependencies?"; then
        return 1
    fi

    verify_installation "${missing_ref[@]}"
}

# ============================================================================
# Verification
# ============================================================================

verify_installation() {
    local deps_to_check=("$@")

    echo ""
    section "Verifying Installation"
    echo ""

    local still_missing=()
    local newly_installed=()

    for cmd in "${deps_to_check[@]}"; do
        IFS='|' read -r name _ _ _ <<< "${TOOL_INFO[$cmd]}"

        if [ "$(check_dependency "$cmd")" = "installed" ]; then
            version=$(get_installed_version "$cmd")
            status_check "$name" 0
            success "  Version: $version"
            newly_installed+=("$name")
        else
            status_check "$name" 1
            still_missing+=("$name")
        fi
    done

    echo ""

    if [ ${#still_missing[@]} -eq 0 ]; then
        draw_box "All Dependencies Installed!"
        box_line ""
        box_line "✨ Success! All prerequisites are now installed."
        box_line ""
        box_line "You're ready to run the setup!"
        box_line ""
        close_box
        return 0
    else
        draw_box "Some Dependencies Still Missing"
        box_line ""
        box_line "Still needed: ${still_missing[*]}"
        box_line ""
        box_line "You can run this checker again after installation."
        box_line ""
        close_box

        if [ ${#newly_installed[@]} -gt 0 ]; then
            echo ""
            success "Installed: ${newly_installed[*]}"
        fi

        return 1
    fi
}

# ============================================================================
# Main Flow
# ============================================================================

check_prerequisites() {
    local missing installed

    clear

    draw_box "AWS Multi-Account Bootstrap - Prerequisite Checker"
    box_line ""
    box_line "Making sure you have everything you need..."
    box_line ""
    close_box

    # Check all dependencies
    check_all_dependencies missing installed

    # Show results
    show_check_results missing installed

    # If everything is installed, we're done!
    if [ ${#missing[@]} -eq 0 ]; then
        draw_box "All Prerequisites Installed!"
        box_line ""
        box_line "✨ You're all set!"
        box_line ""
        box_line "All required dependencies are installed."
        box_line "You're ready to run the setup!"
        box_line ""
        close_box
        return 0
    fi

    # Show missing summary
    echo "─────────────────────────────────────────────────────────────"
    echo ""
    warning "Missing dependencies detected"
    echo ""

    # Build missing list for display
    local missing_names=()
    for cmd in "${missing[@]}"; do
        IFS='|' read -r name _ _ _ <<< "${TOOL_INFO[$cmd]}"
        missing_names+=("$name")
    done

    info "Missing: $(bold "${missing_names[*]}")"
    echo ""

    # Show installation options
    echo "What would you like to do?"
    echo ""
    echo "  $(bold "[Q]") Quick Install - One command to rule them all"
    echo "      → Copy-paste a single command for your platform"
    echo "      → Fastest path $(success "(recommended for most users)")"
    echo ""
    echo "  $(bold "[I]") Interactive Guide - Step-by-step assistance"
    echo "      → Install one dependency at a time"
    echo "      → Detailed explanations and verification"
    echo ""
    echo "  $(bold "[M]") Manual Installation - Show me the links"
    echo "      → Official documentation links only"
    echo "      → I'll handle it myself"
    echo ""
    echo "  $(bold "[E]") Exit - I'll install them later"
    echo "      → No problem, run this checker again when ready"
    echo ""

    while true; do
        read -rp "Your choice [Q/I/M/E]: " choice
        case ${choice,,} in
            q)
                show_quick_install missing
                return $?
                ;;
            i)
                show_interactive_guide missing
                return $?
                ;;
            m)
                show_manual_links missing
                return $?
                ;;
            e)
                echo ""
                info "No problem! Run this checker again when you're ready."
                echo ""
                info "You can run: $(bold "./scripts/lib/prerequisite-checker.sh")"
                return 1
                ;;
            *)
                warning "Invalid choice. Please enter Q, I, M, or E"
                ;;
        esac
    done
}

# ============================================================================
# Run if executed directly
# ============================================================================

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    check_prerequisites
fi