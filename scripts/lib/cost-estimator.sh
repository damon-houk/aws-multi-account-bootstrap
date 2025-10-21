#!/bin/bash

# Cost Estimator Wrapper - Chooses between public API and AWS CLI methods
# Default: Public API (no credentials required)
# Optional: AWS CLI API (more accurate, requires credentials)

# Colors for output (define before sourcing sub-scripts)
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Determine which method to use
COST_ESTIMATOR_METHOD="${COST_ESTIMATOR_METHOD:-public}"

# Check if AWS CLI is configured
check_aws_cli_configured() {
    if command -v aws >/dev/null 2>&1 && aws sts get-caller-identity >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

# Auto-detect best method if not explicitly set
if [ "$COST_ESTIMATOR_METHOD" = "auto" ]; then
    if check_aws_cli_configured; then
        COST_ESTIMATOR_METHOD="aws-cli"
    else
        COST_ESTIMATOR_METHOD="public"
    fi
fi

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the appropriate cost estimator
case "$COST_ESTIMATOR_METHOD" in
    aws-cli)
        if check_aws_cli_configured; then
            source "$SCRIPT_DIR/cost-estimator-aws-cli.sh"
            echo -e "${YELLOW}Using AWS CLI pricing (more accurate, requires credentials)${NC}" >&2
        else
            echo -e "${YELLOW}AWS CLI not configured, falling back to public pricing API${NC}" >&2
            source "$SCRIPT_DIR/cost-estimator-public.sh"
        fi
        ;;
    public|*)
        source "$SCRIPT_DIR/cost-estimator-public.sh"
        ;;
esac

# Export the method being used
export COST_ESTIMATOR_ACTIVE_METHOD="${COST_ESTIMATOR_METHOD}"