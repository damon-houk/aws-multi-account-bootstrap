# AWS CloudFormation Template Browser

The AWS Template Browser is a fully decoupled system for discovering, browsing, and analyzing AWS CloudFormation templates from official AWS repositories. It provides multiple interfaces (CLI, API, library) to access AWS's extensive template collection.

## Overview

The template browser system consists of four main components:

1. **Template Discovery Library** (`scripts/lib/template-discovery.sh`) - Core functions for template operations
2. **Interactive CLI Tool** (`scripts/browse-templates.sh`) - User-friendly command-line interface
3. **API Service** (`scripts/lib/template-api.sh`) - RESTful API wrapper for programmatic access
4. **API Server** (`scripts/template-api-server.sh`) - HTTP server for web frontends

## Quick Start

### Interactive Browser

```bash
# Launch interactive template browser
./scripts/browse-templates.sh

# Search for specific templates
./scripts/browse-templates.sh --search wordpress

# Browse by category
./scripts/browse-templates.sh --category database

# List templates in JSON format
./scripts/browse-templates.sh --json
```

### Download Templates

```bash
# Download a specific template
./scripts/browse-templates.sh --download WordPress_Single_Instance.template

# Download and save to file
./scripts/browse-templates.sh --download LAMP_Multi_AZ.template > my-template.json
```

### Analyze Templates

```bash
# Analyze template for resource types
./scripts/browse-templates.sh --analyze WordPress_Single_Instance.template

# Estimate template costs
./scripts/browse-templates.sh --estimate RDS_MySQL_With_Read_Replica.template
```

## Component Documentation

### Template Discovery Library

The core library provides functions for template operations:

```bash
# Source the library in your scripts
source scripts/lib/template-discovery.sh

# Initialize cache directory
init_template_cache

# List available regions
list_template_regions

# Fetch templates from a region
fetch_template_list "us-east-1"

# Search templates
search_templates "wordpress" "us-east-1"

# Filter by category
filter_by_category "database" "us-east-1"

# Download template content
download_template "WordPress_Single_Instance.template" "us-east-1"

# Analyze template
analyze_template "$template_content"

# Estimate costs
estimate_template_cost "$template_content" "moderate"
```

### Interactive CLI Tool

The browse-templates.sh script provides an interactive interface:

#### Command Line Options

| Option | Description | Example |
|--------|-------------|---------|
| `--region, -r` | AWS region | `--region us-west-2` |
| `--category, -c` | Filter by category | `--category database` |
| `--search, -s` | Search templates | `--search wordpress` |
| `--format, -f` | Output format | `--format json` |
| `--download, -d` | Download template | `--download LAMP.template` |
| `--analyze, -a` | Analyze template | `--analyze RDS.template` |
| `--estimate, -e` | Estimate costs | `--estimate EC2.template` |
| `--quickstarts, -q` | Browse Quick Starts | `--quickstarts` |
| `--list-regions` | List all regions | `--list-regions` |
| `--list-categories` | List categories | `--list-categories` |
| `--json` | JSON output | `--json` |
| `--help, -h` | Show help | `--help` |

#### Interactive Mode Features

When launched without arguments, the tool enters interactive mode with these options:

1. **Change Region** - Select from available AWS regions
2. **Select Category** - Filter templates by category
3. **Search Templates** - Search by keyword
4. **List Templates** - Display current selection
5. **Download Template** - Download to local file
6. **Analyze Template** - Show resource analysis
7. **Browse Quick Starts** - View AWS Quick Start templates
8. **Clear Filters** - Reset all filters

### API Service

The template-api.sh library provides RESTful API endpoints:

```bash
# Source the API library
source scripts/lib/template-api.sh

# Initialize service
init_template_service

# API endpoints available:
api_info                                    # Service information
api_regions                                 # List regions
api_templates "$region" "$category"         # List templates
api_template_details "$name" "$region"      # Get template details
api_template_analyze "$name" "$region"      # Analyze template
api_template_estimate "$name" "$region"     # Estimate costs
api_categories "$region"                    # List categories
api_quickstarts "$category"                 # List Quick Starts
api_search "$query" "$region"              # Search templates
api_template_content "$name" "$region"      # Get template content
```

### API Server

The HTTP server provides web access to templates:

```bash
# Start API server on default port (8080)
./scripts/template-api-server.sh

# Start on custom port
./scripts/template-api-server.sh --port 3000

# Allow external connections
./scripts/template-api-server.sh --host 0.0.0.0

# Set CORS origin
./scripts/template-api-server.sh --cors https://myapp.com
```

#### API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/info` | GET | Service information |
| `/api/regions` | GET | List available regions |
| `/api/templates` | GET | List templates |
| `/api/templates/:name` | GET | Get template details |
| `/api/templates/:name/content` | GET | Get template content |
| `/api/templates/:name/analyze` | GET | Analyze template |
| `/api/templates/:name/estimate` | GET | Estimate template costs |
| `/api/categories` | GET | List categories |
| `/api/quickstarts` | GET | List Quick Starts |
| `/api/search` | GET | Search templates |

#### Query Parameters

- `region` - AWS region (default: us-east-1)
- `category` - Filter by category
- `page` - Page number for pagination
- `per_page` - Items per page (default: 50)
- `q` - Search query
- `format` - Output format (raw, formatted, minified)

#### Example API Requests

```bash
# Get service info
curl http://localhost:8080/api/info

# List regions
curl http://localhost:8080/api/regions

# List templates in us-west-2
curl http://localhost:8080/api/templates?region=us-west-2

# Search for WordPress templates
curl http://localhost:8080/api/search?q=wordpress

# Get template details
curl http://localhost:8080/api/templates/WordPress_Single_Instance.template

# Analyze template
curl http://localhost:8080/api/templates/LAMP_Multi_AZ.template/analyze

# Estimate costs
curl http://localhost:8080/api/templates/RDS_MySQL.template/estimate
```

## Template Categories

Templates are automatically categorized based on their content:

- **web** - Web applications (LAMP, WordPress, Drupal)
- **database** - Database templates (RDS, DynamoDB)
- **network** - Networking templates (VPC, ELB)
- **container** - Container services (ECS, Batch)
- **serverless** - Serverless templates (Lambda)
- **platform** - Platform services (Elastic Beanstalk)
- **windows** - Windows and Active Directory
- **analytics** - Big Data and Analytics (EMR, Kinesis)
- **other** - Other templates

## Caching

The template browser implements intelligent caching:

- **Cache Directory**: `~/.aws-bootstrap/template-cache/`
- **Cache TTL**: 24 hours (configurable via `TEMPLATE_CACHE_TTL`)
- **Cache Structure**:
  ```
  ~/.aws-bootstrap/template-cache/
  ├── metadata/           # Template lists and metadata
  ├── templates/          # Downloaded template content
  └── quickstarts/        # Quick Start information
  ```

## Integration Examples

### Integration with Bootstrap Tool

```bash
#!/bin/bash
# In setup-complete-project.sh

# Source template discovery
source "$SCRIPT_DIR/lib/template-discovery.sh"

# Let user select a template
echo "Would you like to use an AWS template? (y/n)"
read -r use_template

if [[ "$use_template" == "y" ]]; then
    # Show available templates
    templates=$(search_templates "web" "$AWS_REGION")
    echo "$templates" | jq -r '.[] | "\(.name) - \(.category)"'

    # Download selected template
    read -p "Enter template name: " template_name
    template_content=$(download_template "$template_name" "$AWS_REGION")

    # Deploy template
    aws cloudformation create-stack \
        --stack-name "$PROJECT_CODE-stack" \
        --template-body "$template_content"
fi
```

### Integration with Cost Estimator

```bash
#!/bin/bash
# In cost estimator

# Source template discovery
source "$SCRIPT_DIR/lib/template-discovery.sh"

# Analyze template for cost estimation
template_content=$(download_template "$TEMPLATE_NAME" "$REGION")
analysis=$(analyze_template "$template_content")

# Get resource types
resources=$(echo "$analysis" | jq -r '.resource_types[]')

# Estimate costs based on resources
for resource in $resources; do
    case $resource in
        AWS::EC2::Instance)
            add_ec2_costs
            ;;
        AWS::RDS::DBInstance)
            add_rds_costs
            ;;
        # ... more resource types
    esac
done
```

### Web Frontend Integration

```javascript
// JavaScript example for web frontend

// Fetch template list
fetch('http://localhost:8080/api/templates?region=us-east-1')
    .then(response => response.json())
    .then(data => {
        data.data.forEach(template => {
            console.log(`${template.name} - ${template.category}`);
        });
    });

// Search templates
fetch('http://localhost:8080/api/search?q=wordpress')
    .then(response => response.json())
    .then(data => {
        console.log(`Found ${data.pagination.total} templates`);
    });

// Analyze template
fetch('http://localhost:8080/api/templates/LAMP_Multi_AZ.template/analyze')
    .then(response => response.json())
    .then(analysis => {
        console.log(`Resources: ${analysis.resource_count}`);
        console.log(`Services: ${analysis.services.join(', ')}`);
    });
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `TEMPLATE_CACHE_DIR` | Cache directory | `~/.aws-bootstrap/template-cache` |
| `TEMPLATE_CACHE_TTL` | Cache TTL in seconds | `86400` (24 hours) |
| `TEMPLATE_API_TIMEOUT` | API timeout in seconds | `10` |
| `TEMPLATE_API_PORT` | API server port | `8080` |
| `TEMPLATE_API_HOST` | API server host | `127.0.0.1` |
| `TEMPLATE_API_CORS` | CORS origin header | `*` |

## AWS Resources

The template browser accesses AWS CloudFormation templates from:

1. **Public S3 Buckets** - Regional buckets containing sample templates
   - Format: `cloudformation-templates-{region}`
   - Example: `https://s3.amazonaws.com/cloudformation-templates-us-east-1/`

2. **AWS Quick Starts** - Production-ready reference deployments
   - GitHub: `https://github.com/aws-quickstart/`
   - 200+ reference architectures

3. **No Authentication Required** - All templates are publicly accessible

## Troubleshooting

### Common Issues

1. **Empty template list**
   - Check internet connectivity
   - Verify the region has templates available
   - Clear cache: `rm -rf ~/.aws-bootstrap/template-cache/`

2. **jq command not found**
   - Install jq: `brew install jq` (macOS) or `apt-get install jq` (Linux)
   - The tool will still work but with limited functionality

3. **Permission denied**
   - Ensure scripts are executable: `chmod +x scripts/*.sh`

4. **Slow performance**
   - Templates are cached after first fetch
   - Increase timeout: `export TEMPLATE_API_TIMEOUT=30`

### Debug Mode

Enable debug output:

```bash
# Enable bash debugging
set -x
./scripts/browse-templates.sh

# Check cache status
ls -la ~/.aws-bootstrap/template-cache/
```

## Future Enhancements

- [ ] Template validation before deployment
- [ ] Custom template repository support
- [ ] Template parameter extraction and prompting
- [ ] Multi-region template deployment
- [ ] Template versioning and change tracking
- [ ] GraphQL API endpoint
- [ ] WebSocket support for real-time updates
- [ ] Template composition and merging

## Contributing

When adding new features to the template browser:

1. Keep components decoupled
2. Add functions to `template-discovery.sh`
3. Update API endpoints in `template-api.sh`
4. Maintain backward compatibility
5. Update this documentation

## License

The template browser is part of the AWS Multi-Account Bootstrap project and follows the same license terms. AWS CloudFormation templates accessed through this tool are provided by AWS and subject to AWS's terms.