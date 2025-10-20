#!/bin/bash

# Test script for cost estimator functionality
# This verifies that cost estimation functions work correctly

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Testing cost estimator functionality...${NC}"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source the cost estimator
source "$PROJECT_ROOT/scripts/lib/cost-estimator.sh"

# Test 1: Check if functions are available
echo -e "${BLUE}Test 1: Checking function availability${NC}"
if type calculate_monthly_cost >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} calculate_monthly_cost function exists"
else
    echo -e "${RED}✗${NC} calculate_monthly_cost function not found"
    exit 1
fi

if type display_cost_breakdown >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} display_cost_breakdown function exists"
else
    echo -e "${RED}✗${NC} display_cost_breakdown function not found"
    exit 1
fi
echo ""

# Test 2: Test cost calculations
echo -e "${BLUE}Test 2: Testing cost calculations${NC}"

# Test minimal usage
MINIMAL_COST=$(calculate_monthly_cost 3 "minimal")
if (( $(echo "$MINIMAL_COST > 0" | bc -l) )); then
    echo -e "${GREEN}✓${NC} Minimal cost calculation: \$$MINIMAL_COST"
else
    echo -e "${RED}✗${NC} Minimal cost calculation failed"
    exit 1
fi

# Test light usage
LIGHT_COST=$(calculate_monthly_cost 3 "light")
if (( $(echo "$LIGHT_COST > $MINIMAL_COST" | bc -l) )); then
    echo -e "${GREEN}✓${NC} Light cost calculation: \$$LIGHT_COST"
else
    echo -e "${RED}✗${NC} Light cost should be higher than minimal"
    exit 1
fi

# Test moderate usage
MODERATE_COST=$(calculate_monthly_cost 3 "moderate")
if (( $(echo "$MODERATE_COST > $LIGHT_COST" | bc -l) )); then
    echo -e "${GREEN}✓${NC} Moderate cost calculation: \$$MODERATE_COST"
else
    echo -e "${RED}✗${NC} Moderate cost should be higher than light"
    exit 1
fi
echo ""

# Test 3: Test currency formatting
echo -e "${BLUE}Test 3: Testing currency formatting${NC}"
FORMATTED=$(format_currency 12.345)
if [ "$FORMATTED" = "\$12.35" ]; then
    echo -e "${GREEN}✓${NC} Currency formatting works: $FORMATTED"
else
    echo -e "${RED}✗${NC} Currency formatting failed: expected \$12.35, got $FORMATTED"
    exit 1
fi
echo ""

# Test 4: Test inline cost display
echo -e "${BLUE}Test 4: Testing inline cost display${NC}"
OUTPUT=$(display_inline_cost 3 2>&1)
if echo "$OUTPUT" | grep -q "Estimated monthly cost"; then
    echo -e "${GREEN}✓${NC} Inline cost display works"
    echo "  Output: $OUTPUT"
else
    echo -e "${RED}✗${NC} Inline cost display failed"
    exit 1
fi
echo ""

# Test 5: Test dry-run cost display
echo -e "${BLUE}Test 5: Testing dry-run cost display${NC}"
OUTPUT=$(display_dry_run_costs 3 2>&1)
if echo "$OUTPUT" | grep -q "DRY RUN"; then
    echo -e "${GREEN}✓${NC} Dry-run cost display works"
else
    echo -e "${RED}✗${NC} Dry-run cost display failed"
    exit 1
fi
echo ""

# Test 6: Test cost breakdown display
echo -e "${BLUE}Test 6: Testing full cost breakdown display${NC}"
echo "Sample output:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
display_cost_breakdown 3 true
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✓${NC} Cost breakdown display completed"
echo ""

# Summary
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}All cost estimator tests passed!${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"