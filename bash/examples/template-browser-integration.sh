#!/bin/bash

# AWS Template Browser Integration Examples
# Shows how to integrate the template browser with other tools

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source the template discovery library
source "$SCRIPT_DIR/scripts/lib/template-discovery.sh"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Initialize template cache
init_template_cache

echo -e "${BLUE}AWS Template Browser Integration Examples${NC}\n"

# Example 1: List available regions
echo -e "${YELLOW}Example 1: List Available Regions${NC}"
echo "Available AWS regions with templates:"
list_template_regions | while read -r region; do
    echo "  - $region"
done
echo ""

# Example 2: Search for specific templates
echo -e "${YELLOW}Example 2: Search for WordPress Templates${NC}"
echo "Searching for WordPress templates in us-east-1..."
results=$(search_templates "wordpress" "us-east-1")
count=$(echo "$results" | jq 'length')
echo "Found $count WordPress-related templates"
echo "$results" | jq -r '.[:3] | .[] | "  - \(.name)"'
echo ""

# Example 3: Get template categories
echo -e "${YELLOW}Example 3: Template Categories${NC}"
echo "Available template categories in us-east-1:"
get_template_categories "us-east-1" | while read -r category; do
    echo "  - $category"
done
echo ""

# Example 4: Download and analyze a template
echo -e "${YELLOW}Example 4: Analyze Template Resources${NC}"
template_name="WordPress_Single_Instance.template"
echo "Downloading and analyzing $template_name..."

# Download template
content=$(download_template "$template_name" "us-east-1" 2>/dev/null)

if [ -n "$content" ]; then
    # Analyze template
    analysis=$(analyze_template "$content")

    echo "Template Analysis:"
    echo "  Resource Count: $(echo "$analysis" | jq -r '.resource_count')"
    echo "  Has VPC: $(echo "$analysis" | jq -r '.has_vpc')"
    echo "  Has RDS: $(echo "$analysis" | jq -r '.has_rds')"
    echo "  Has Lambda: $(echo "$analysis" | jq -r '.has_lambda')"

    echo "  Services used:"
    echo "$analysis" | jq -r '.services[]' | while read -r service; do
        echo "    - $service"
    done
else
    echo "  Failed to download template"
fi
echo ""

# Example 5: Estimate template costs
echo -e "${YELLOW}Example 5: Estimate Template Costs${NC}"
if [ -n "$content" ]; then
    echo "Estimating costs for $template_name:"
    for level in minimal light moderate heavy; do
        cost=$(estimate_template_cost "$content" "$level")
        printf "  %-10s: \$%.2f/month\n" "$level" "$cost"
    done
fi
echo ""

# Example 6: Filter templates by category
echo -e "${YELLOW}Example 6: Database Templates${NC}"
echo "Fetching database templates..."
db_templates=$(filter_by_category "database" "us-east-1")
db_count=$(echo "$db_templates" | jq 'length')
echo "Found $db_count database templates"
echo "$db_templates" | jq -r '.[:5] | .[] | "  - \(.name)"'
echo ""

# Example 7: Integration with bootstrap script
echo -e "${YELLOW}Example 7: Bootstrap Integration${NC}"
cat << 'EOF'
# Add this to setup-complete-project.sh:

# Let user select from AWS templates
select_aws_template() {
    local region="${1:-us-east-1}"
    local category="${2:-all}"

    echo "Fetching AWS templates..."
    local templates
    templates=$(filter_by_category "$category" "$region")

    # Show template options
    echo "Available templates:"
    echo "$templates" | jq -r '.[] | "\(.name) - \(.category)"' | head -10

    read -p "Enter template name (or press Enter to skip): " template_name

    if [ -n "$template_name" ]; then
        # Download and deploy template
        local template_content
        template_content=$(download_template "$template_name" "$region")

        # Save to file or deploy directly
        echo "$template_content" > "infrastructure/template.json"
        echo "Template saved to infrastructure/template.json"
    fi
}
EOF
echo ""

# Example 8: Cost estimation integration
echo -e "${YELLOW}Example 8: Cost Estimator Integration${NC}"
cat << 'EOF'
# Add this to cost estimator:

# Estimate costs for an AWS template
estimate_aws_template() {
    local template_url="$1"
    local usage_level="${2:-moderate}"

    # Extract template name from URL
    local template_name="${template_url##*/}"

    # Download template
    local content
    content=$(download_template "$template_name" "$AWS_REGION")

    # Analyze resources
    local analysis
    analysis=$(analyze_template "$content")

    # Calculate base cost
    local base_cost
    base_cost=$(estimate_template_cost "$content" "$usage_level")

    echo "Template: $template_name"
    echo "Resources: $(echo "$analysis" | jq -r '.resource_count')"
    echo "Estimated Cost: \$$base_cost/month ($usage_level usage)"
}
EOF
echo ""

# Example 9: Quick Start templates
echo -e "${YELLOW}Example 9: AWS Quick Starts${NC}"
echo "Fetching AWS Quick Start templates from GitHub..."
quickstarts=$(fetch_quickstart_list 2>/dev/null || echo "[]")
qs_count=$(echo "$quickstarts" | jq 'length')

if [ "$qs_count" -gt 0 ]; then
    echo "Found $qs_count Quick Start repositories"
    echo "Popular Quick Starts:"
    echo "$quickstarts" | jq -r '.[:5] | .[] | "  - \(.name): \(.category)"'
else
    echo "Unable to fetch Quick Starts (may require internet connection)"
fi
echo ""

# Example 10: API Server usage
echo -e "${YELLOW}Example 10: API Server${NC}"
cat << 'EOF'
# Start the API server:
./scripts/template-api-server.sh --port 8080

# Then use curl or any HTTP client:
curl http://localhost:8080/api/regions
curl http://localhost:8080/api/templates?region=us-west-2
curl http://localhost:8080/api/search?q=wordpress
curl http://localhost:8080/api/templates/LAMP_Multi_AZ.template/analyze

# Or from JavaScript:
fetch('http://localhost:8080/api/templates')
    .then(r => r.json())
    .then(data => console.log(data));
EOF
echo ""

echo -e "${GREEN}✓ Integration examples complete!${NC}"
echo ""
echo "For more information, see:"
echo "  - docs/TEMPLATE_BROWSER.md"
echo "  - scripts/browse-templates.sh --help"
echo "  - scripts/lib/template-discovery.sh (source code)"