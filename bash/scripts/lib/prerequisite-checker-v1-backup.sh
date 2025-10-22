#!/bin/bash

# Prerequisite Checker for AWS Multi-Account Bootstrap
# Interactive helper to check prerequisites and provide installation guidance
#
# Usage:
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/prerequisite-checker.sh"
#   check_prerequisites
#
# Or run standalone:
#   ./scripts/lib/prerequisite-checker.sh

# Source UI helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/ui-helpers.sh
source "$SCRIPT_DIR/ui-helpers.sh"

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

# ============================================================================
# Installation Guides (Informational Only)
# ============================================================================

show_git_guide() {
    section "Git Installation Guide"

    local platform
    platform=$(detect_platform)

    info "Git is required for version control"
    echo ""

    case "$platform" in
        macos)
            bold "macOS Installation:"
            echo ""
            numbered_list \
                "Install Xcode Command Line Tools: xcode-select --install" \
                "Or install via Homebrew: brew install git"
            ;;

        linux-ubuntu|linux-debian)
            bold "Ubuntu/Debian Installation:"
            echo ""
            echo "  sudo apt-get update"
            echo "  sudo apt-get install git"
            ;;

        linux-fedora|linux-rhel|linux-centos)
            bold "Fedora/RHEL/CentOS Installation:"
            echo ""
            echo "  sudo dnf install git"
            ;;

        windows)
            bold "Windows Installation:"
            echo ""
            numbered_list \
                "Download from: https://git-scm.com/download/win" \
                "Or use winget: winget install Git.Git"
            ;;

        *)
            bold "Installation:"
            echo ""
            echo "  Visit: https://git-scm.com/downloads"
            ;;
    esac

    echo ""
    info "Official documentation: https://git-scm.com/book/en/v2/Getting-Started-Installing-Git"
}

show_node_guide() {
    section "Node.js Installation Guide"

    local platform
    platform=$(detect_platform)

    info "AWS CDK requires Node.js 20.0.0 or later (Node 18 reached EOL April 2025)"
    info "Recommended: Node.js 22 LTS (active until April 2027)"
    echo ""

    case "$platform" in
        macos)
            bold "macOS Installation:"
            echo ""
            numbered_list \
                "Using Homebrew: brew install node" \
                "Or download installer from: https://nodejs.org"
            echo ""
            bold "Upgrade existing installation:"
            echo "  brew upgrade node"
            ;;

        linux-ubuntu|linux-debian)
            bold "Ubuntu/Debian Installation (Node 20 LTS):"
            echo ""
            echo "  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -"
            echo "  sudo apt-get install -y nodejs"
            echo ""
            bold "Or use nvm (Node Version Manager):"
            echo "  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash"
            echo "  nvm install 20"
            ;;

        linux-fedora|linux-rhel|linux-centos)
            bold "Fedora/RHEL/CentOS Installation:"
            echo ""
            echo "  curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -"
            echo "  sudo dnf install -y nodejs"
            ;;

        windows)
            bold "Windows Installation:"
            echo ""
            numbered_list \
                "Download installer from: https://nodejs.org" \
                "Or use winget: winget install OpenJS.NodeJS.LTS"
            echo ""
            bold "Upgrade existing installation:"
            echo "  winget upgrade OpenJS.NodeJS.LTS"
            ;;

        *)
            bold "Installation:"
            echo ""
            info "Visit: https://nodejs.org"
            echo ""
            bold "Recommended: Use nvm (Node Version Manager)"
            echo "  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash"
            echo "  nvm install 20"
            ;;
    esac

    echo ""
    info "Official documentation: https://nodejs.org/en/download/"
    info "nvm (recommended): https://github.com/nvm-sh/nvm"
}

show_aws_cli_guide() {
    section "AWS CLI Installation Guide"

    local platform
    platform=$(detect_platform)

    info "AWS CLI is required for AWS account management"
    echo ""

    case "$platform" in
        macos)
            bold "macOS Installation:"
            echo ""
            numbered_list \
                "Download the installer: curl \"https://awscli.amazonaws.com/AWSCLIV2.pkg\" -o \"AWSCLIV2.pkg\"" \
                "Run the installer: sudo installer -pkg AWSCLIV2.pkg -target /"
            echo ""
            bold "Upgrade existing installation:"
            echo "  Re-download and install the latest version using the same commands"
            ;;

        linux-ubuntu|linux-debian)
            bold "Ubuntu/Debian Installation:"
            echo ""
            echo "  curl \"https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip\" -o \"awscliv2.zip\""
            echo "  unzip awscliv2.zip"
            echo "  sudo ./aws/install"
            echo ""
            bold "Upgrade existing installation:"
            echo "  sudo ./aws/install --update"
            ;;

        linux*)
            bold "Linux Installation:"
            echo ""
            echo "  curl \"https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip\" -o \"awscliv2.zip\""
            echo "  unzip awscliv2.zip"
            echo "  sudo ./aws/install"
            echo ""
            bold "Upgrade existing installation:"
            echo "  sudo ./aws/install --update"
            ;;

        windows)
            bold "Windows Installation:"
            echo ""
            numbered_list \
                "Download MSI installer from: https://awscli.amazonaws.com/AWSCLIV2.msi" \
                "Or use winget: winget install Amazon.AWSCLI"
            echo ""
            bold "Upgrade existing installation:"
            echo "  winget upgrade Amazon.AWSCLI"
            ;;

        *)
            bold "Installation:"
            echo ""
            echo "  Visit: https://aws.amazon.com/cli/"
            ;;
    esac

    echo ""
    info "Official documentation: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
}

show_github_cli_guide() {
    section "GitHub CLI Installation Guide"

    local platform
    platform=$(detect_platform)

    info "GitHub CLI is required for repository setup"
    echo ""

    case "$platform" in
        macos)
            bold "macOS Installation:"
            echo ""
            if command -v brew &> /dev/null; then
                success "Homebrew detected"
                echo ""
                echo "  brew install gh"
                echo ""
                bold "Upgrade existing installation:"
                echo "  brew upgrade gh"
            else
                warning "Homebrew not found"
                echo ""
                numbered_list \
                    "Install Homebrew first: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"" \
                    "Then install GitHub CLI: brew install gh"
                echo ""
                info "Or download from: https://cli.github.com"
            fi
            ;;

        linux-ubuntu|linux-debian)
            bold "Ubuntu/Debian Installation:"
            echo ""
            echo "  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg"
            echo "  sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg"
            echo "  echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main\" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null"
            echo "  sudo apt update"
            echo "  sudo apt install gh"
            echo ""
            bold "Upgrade existing installation:"
            echo "  sudo apt update && sudo apt upgrade gh"
            ;;

        linux-fedora|linux-rhel|linux-centos)
            bold "Fedora/RHEL/CentOS Installation:"
            echo ""
            echo "  sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo"
            echo "  sudo dnf install gh"
            echo ""
            bold "Upgrade existing installation:"
            echo "  sudo dnf upgrade gh"
            ;;

        linux*)
            bold "Linux Installation:"
            echo ""
            echo "  Visit: https://github.com/cli/cli/blob/trunk/docs/install_linux.md"
            ;;

        windows)
            bold "Windows Installation:"
            echo ""
            echo "  winget install --id GitHub.cli"
            echo ""
            bold "Upgrade existing installation:"
            echo "  winget upgrade --id GitHub.cli"
            echo ""
            info "Or download from: https://cli.github.com"
            ;;

        *)
            bold "Installation:"
            echo ""
            echo "  Visit: https://cli.github.com"
            ;;
    esac

    echo ""
    info "Official documentation: https://cli.github.com/manual/"
}

show_jq_guide() {
    section "jq Installation Guide"

    local platform
    platform=$(detect_platform)

    info "jq is a lightweight JSON processor"
    echo ""

    case "$platform" in
        macos)
            bold "macOS Installation:"
            echo ""
            echo "  brew install jq"
            echo ""
            bold "Upgrade existing installation:"
            echo "  brew upgrade jq"
            ;;

        linux-ubuntu|linux-debian)
            bold "Ubuntu/Debian Installation:"
            echo ""
            echo "  sudo apt-get update"
            echo "  sudo apt-get install jq"
            echo ""
            bold "Upgrade existing installation:"
            echo "  sudo apt-get update && sudo apt-get upgrade jq"
            ;;

        linux-fedora|linux-rhel|linux-centos)
            bold "Fedora/RHEL/CentOS Installation:"
            echo ""
            echo "  sudo dnf install jq"
            echo ""
            bold "Upgrade existing installation:"
            echo "  sudo dnf upgrade jq"
            ;;

        windows)
            bold "Windows Installation:"
            echo ""
            echo "  winget install jqlang.jq"
            echo ""
            bold "Upgrade existing installation:"
            echo "  winget upgrade jqlang.jq"
            echo ""
            info "Or download from: https://stedolan.github.io/jq/download/"
            ;;

        *)
            bold "Installation:"
            echo ""
            echo "  Visit: https://stedolan.github.io/jq/download/"
            ;;
    esac

    echo ""
    info "Official documentation: https://stedolan.github.io/jq/"
}

show_aws_cdk_guide() {
    section "AWS CDK Installation Guide"

    if ! command -v npm &> /dev/null; then
        error "npm not found - install Node.js first"
        echo ""
        warning "AWS CDK requires Node.js and npm to be installed"
        info "Please install Node.js first, then return to install AWS CDK"
        return 1
    fi

    info "AWS CDK will be installed globally using npm"
    echo ""

    bold "Installation command:"
    echo "  npm install -g aws-cdk"
    echo ""

    bold "Upgrade existing installation:"
    echo "  npm update -g aws-cdk"
    echo ""

    info "Official documentation: https://docs.aws.amazon.com/cdk/v2/guide/getting_started.html"
}

# ============================================================================
# Main Function
# ============================================================================

check_prerequisites() {
    clear

    draw_box "AWS Multi-Account Bootstrap - Prerequisite Checker"
    box_line ""
    box_line "This guide will help you install missing prerequisites."
    box_line ""
    close_box

    echo ""
    section "Checking Prerequisites"

    # Dependency order: Git -> Node.js -> AWS CLI -> GitHub CLI -> jq -> AWS CDK
    local missing=()
    local missing_names=()

    echo "Checking installed dependencies..."
    echo ""

    # 1. Git
    if command -v git &> /dev/null; then
        status_check "Git" 0
        success "  Installed: $(git --version | cut -d' ' -f3)"
        info "  Required:  ≥2.23.0 (for modern workflows)"
    else
        status_check "Git" 1
        missing+=("git")
        missing_names+=("Git")
    fi

    # 2. Node.js (with version check)
    if command -v node &> /dev/null; then
        local node_version
        node_version=$(node --version)
        local major_version
        major_version=${node_version%%.*}
        major_version=${major_version#v}

        # Check minimum version (AWS CDK requires Node 20+ as of Oct 2025)
        if [ "$major_version" -lt 20 ]; then
            status_check "Node.js" 1
            error "  Installed: $node_version (too old)"
            info "  Required:  ≥20.0.0"
            error "  Node 18 reached end-of-life on April 30, 2025"
            missing+=("node")
            missing_names+=("Node.js (upgrade required)")
        elif [ "$major_version" -eq 20 ]; then
            status_check "Node.js" 0
            warning "  Installed: $node_version (minimum)"
            info "  Required:  ≥20.0.0"
            info "  Recommended: Node 22 LTS (active until April 2027)"
        else
            # Node 22+
            status_check "Node.js" 0
            success "  Installed: $node_version (excellent)"
            info "  Required:  ≥20.0.0"
        fi
    else
        status_check "Node.js" 1
        missing+=("node")
        missing_names+=("Node.js")
    fi

    # 3. AWS CLI
    if command -v aws &> /dev/null; then
        status_check "AWS CLI" 0
        success "  Installed: $(aws --version | cut -d' ' -f1 | cut -d'/' -f2)"
        info "  Required:  ≥2.0.0 (v2 API compatibility)"
    else
        status_check "AWS CLI" 1
        missing+=("aws-cli")
        missing_names+=("AWS CLI")
    fi

    # 4. GitHub CLI
    if command -v gh &> /dev/null; then
        status_check "GitHub CLI" 0
        success "  Installed: $(gh --version | head -1 | awk '{print $3}')"
        info "  Required:  ≥2.0.0 (OIDC support)"
    else
        status_check "GitHub CLI" 1
        missing+=("github-cli")
        missing_names+=("GitHub CLI")
    fi

    # 5. jq
    if command -v jq &> /dev/null; then
        status_check "jq" 0
        success "  Installed: $(jq --version | cut -d'-' -f2)"
        info "  Required:  ≥1.6 (security fixes)"
    else
        status_check "jq" 1
        missing+=("jq")
        missing_names+=("jq")
    fi

    # 6. AWS CDK (depends on Node.js)
    if command -v cdk &> /dev/null; then
        status_check "AWS CDK" 0
        success "  Installed: $(cdk --version | awk '{print $1}')"
        info "  Required:  ≥2.0.0 (CDK v2)"
    else
        status_check "AWS CDK" 1
        missing+=("aws-cdk")
        missing_names+=("AWS CDK")
    fi

    echo ""

    if [ ${#missing[@]} -eq 0 ]; then
        draw_box "All Prerequisites Installed!"
        box_line ""
        box_line "✓ All required dependencies are installed."
        box_line "  You're ready to run the setup!"
        box_line ""
        close_box
        return 0
    fi

    warning "Missing dependencies: ${missing_names[*]}"
    echo ""

    if ! confirm "Would you like installation guidance?"; then
        info "You can install them manually and run this again"
        return 1
    fi

    # Show installation guides for missing dependencies (in order)
    for dep in "${missing[@]}"; do
        echo ""
        echo ""
        case $dep in
            git)
                show_git_guide
                ;;
            node)
                show_node_guide
                ;;
            aws-cli)
                show_aws_cli_guide
                ;;
            github-cli)
                show_github_cli_guide
                ;;
            jq)
                show_jq_guide
                ;;
            aws-cdk)
                show_aws_cdk_guide
                ;;
        esac

        echo ""
        echo "─────────────────────────────────────────────────────────────"
        if ! confirm "Have you installed this dependency?"; then
            info "You can continue installing the remaining dependencies"
        fi
    done

    # Re-check all dependencies
    echo ""
    echo ""
    section "Verifying Installation"
    echo ""

    local still_missing=()
    local still_missing_names=()

    for dep in "${missing[@]}"; do
        case $dep in
            git)
                if command -v git &> /dev/null; then
                    status_check "Git" 0
                else
                    status_check "Git" 1
                    still_missing+=("git")
                    still_missing_names+=("Git")
                fi
                ;;
            node)
                if command -v node &> /dev/null; then
                    local node_version
                    node_version=$(node --version)
                    local major_version
                    major_version=${node_version%%.*}
                    major_version=${major_version#v}

                    if [ "$major_version" -ge 20 ]; then
                        status_check "Node.js" 0
                        info "  Version: $node_version"
                    else
                        status_check "Node.js" 1
                        still_missing+=("node")
                        still_missing_names+=("Node.js (upgrade required)")
                    fi
                else
                    status_check "Node.js" 1
                    still_missing+=("node")
                    still_missing_names+=("Node.js")
                fi
                ;;
            aws-cli)
                if command -v aws &> /dev/null; then
                    status_check "AWS CLI" 0
                else
                    status_check "AWS CLI" 1
                    still_missing+=("aws-cli")
                    still_missing_names+=("AWS CLI")
                fi
                ;;
            github-cli)
                if command -v gh &> /dev/null; then
                    status_check "GitHub CLI" 0
                else
                    status_check "GitHub CLI" 1
                    still_missing+=("github-cli")
                    still_missing_names+=("GitHub CLI")
                fi
                ;;
            jq)
                if command -v jq &> /dev/null; then
                    status_check "jq" 0
                else
                    status_check "jq" 1
                    still_missing+=("jq")
                    still_missing_names+=("jq")
                fi
                ;;
            aws-cdk)
                if command -v cdk &> /dev/null; then
                    status_check "AWS CDK" 0
                else
                    status_check "AWS CDK" 1
                    still_missing+=("aws-cdk")
                    still_missing_names+=("AWS CDK")
                fi
                ;;
        esac
    done

    echo ""

    if [ ${#still_missing[@]} -eq 0 ]; then
        draw_box "Installation Complete!"
        box_line ""
        box_line "✓ All dependencies installed successfully!"
        box_line "  You're ready to run the setup."
        box_line ""
        close_box
        return 0
    else
        draw_box "Some Dependencies Still Missing"
        box_line ""
        box_line "Still missing: ${still_missing_names[*]}"
        box_line ""
        box_line "Please install them and run this checker again."
        box_line ""
        close_box
        return 1
    fi
}

# ============================================================================
# Run if executed directly
# ============================================================================

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    check_prerequisites
fi