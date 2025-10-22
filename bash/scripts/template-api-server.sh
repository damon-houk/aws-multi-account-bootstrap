#!/bin/bash

# Template API Server
# Simple HTTP server for template discovery API
# Can be used for web frontends or remote CLI access

set -e

# Configuration
PORT="${TEMPLATE_API_PORT:-8080}"
HOST="${TEMPLATE_API_HOST:-127.0.0.1}"
CORS_ORIGIN="${TEMPLATE_API_CORS:-*}"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the API library
source "$SCRIPT_DIR/lib/template-api.sh"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Initialize service
init_template_service

# Parse command line
while [[ $# -gt 0 ]]; do
    case $1 in
        --port|-p)
            PORT="$2"
            shift 2
            ;;
        --host|-h)
            HOST="$2"
            shift 2
            ;;
        --cors)
            CORS_ORIGIN="$2"
            shift 2
            ;;
        --help)
            cat << EOF
Template API Server

Usage: $(basename "$0") [options]

Options:
    -p, --port PORT    Port to listen on (default: 8080)
    -h, --host HOST    Host to bind to (default: 127.0.0.1)
    --cors ORIGIN      CORS origin header (default: *)
    --help             Show this help message

API Endpoints:
    GET /api/info                           - Service information
    GET /api/regions                        - List available regions
    GET /api/templates                      - List templates
    GET /api/templates/:name                - Get template details
    GET /api/templates/:name/content        - Get template content
    GET /api/templates/:name/analyze        - Analyze template
    GET /api/templates/:name/estimate       - Estimate template costs
    GET /api/categories                     - List categories
    GET /api/quickstarts                    - List Quick Starts
    GET /api/search                         - Search templates

Query Parameters:
    region      - AWS region (default: us-east-1)
    category    - Filter by category
    page        - Page number for pagination
    per_page    - Items per page (default: 50)
    q           - Search query
    format      - Output format (raw, formatted, minified)

Examples:
    # Start server on default port
    $(basename "$0")

    # Start on custom port
    $(basename "$0") --port 3000

    # Allow external connections
    $(basename "$0") --host 0.0.0.0

EOF
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}Starting Template API Server${NC}"
echo -e "${GREEN}Listening on http://$HOST:$PORT${NC}"
echo -e "${YELLOW}CORS Origin: $CORS_ORIGIN${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
echo ""

# Handle HTTP requests using netcat (nc) or socat if available
if command -v socat >/dev/null 2>&1; then
    # Use socat for better HTTP handling
    while true; do
        socat TCP-LISTEN:$PORT,bind=$HOST,reuseaddr,fork EXEC:"$0 handle_request"
    done
elif command -v nc >/dev/null 2>&1; then
    # Fallback to netcat
    echo -e "${YELLOW}Note: Using netcat. For better performance, install socat.${NC}"

    # Create a simple HTTP handler
    handle_http_request() {
        local request
        read -r request

        # Parse request
        local method
        local path
        local version
        method=$(echo "$request" | cut -d' ' -f1)
        path=$(echo "$request" | cut -d' ' -f2)
        version=$(echo "$request" | cut -d' ' -f3)

        # Read headers
        while read -r header; do
            [ -z "$(echo "$header" | tr -d '\r\n')" ] && break
        done

        # Route request
        route_request "$method" "$path"
    }

    # Listen and handle requests
    while true; do
        { handle_http_request; } | nc -l -p "$PORT" -q 1
    done
else
    # Python fallback server
    echo -e "${YELLOW}Note: Using Python HTTP server. For better performance, install socat or netcat.${NC}"

    # Create a Python API server script
    cat > /tmp/template-api-server.py << 'PYTHON_EOF'
#!/usr/bin/env python3

import http.server
import json
import subprocess
import urllib.parse
from http import HTTPStatus

PORT = TEMPLATE_PORT
HOST = 'TEMPLATE_HOST'
SCRIPT_DIR = 'TEMPLATE_SCRIPT_DIR'

class TemplateAPIHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        # Parse URL and query parameters
        parsed_path = urllib.parse.urlparse(self.path)
        path = parsed_path.path
        query = urllib.parse.parse_qs(parsed_path.query)

        # Set CORS headers
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')

        # Route to appropriate handler
        try:
            if path == '/api/info':
                result = subprocess.run(
                    ['bash', '-c', f'source {SCRIPT_DIR}/lib/template-api.sh && api_info'],
                    capture_output=True, text=True
                )
                self.end_headers()
                self.wfile.write(result.stdout.encode())

            elif path == '/api/regions':
                result = subprocess.run(
                    ['bash', '-c', f'source {SCRIPT_DIR}/lib/template-api.sh && api_regions'],
                    capture_output=True, text=True
                )
                self.end_headers()
                self.wfile.write(result.stdout.encode())

            elif path == '/api/templates':
                region = query.get('region', ['us-east-1'])[0]
                category = query.get('category', ['all'])[0]
                page = query.get('page', ['1'])[0]
                per_page = query.get('per_page', ['50'])[0]

                result = subprocess.run(
                    ['bash', '-c',
                     f'source {SCRIPT_DIR}/lib/template-api.sh && api_templates "{region}" "{category}" "{page}" "{per_page}"'],
                    capture_output=True, text=True
                )
                self.end_headers()
                self.wfile.write(result.stdout.encode())

            elif path == '/api/categories':
                region = query.get('region', ['us-east-1'])[0]
                result = subprocess.run(
                    ['bash', '-c', f'source {SCRIPT_DIR}/lib/template-api.sh && api_categories "{region}"'],
                    capture_output=True, text=True
                )
                self.end_headers()
                self.wfile.write(result.stdout.encode())

            elif path == '/api/search':
                q = query.get('q', [''])[0]
                region = query.get('region', ['us-east-1'])[0]
                page = query.get('page', ['1'])[0]
                per_page = query.get('per_page', ['50'])[0]

                result = subprocess.run(
                    ['bash', '-c',
                     f'source {SCRIPT_DIR}/lib/template-api.sh && api_search "{q}" "{region}" "{page}" "{per_page}"'],
                    capture_output=True, text=True
                )
                self.end_headers()
                self.wfile.write(result.stdout.encode())

            else:
                self.send_error(HTTPStatus.NOT_FOUND)

        except Exception as e:
            self.send_error(HTTPStatus.INTERNAL_SERVER_ERROR, str(e))

if __name__ == '__main__':
    server = http.server.HTTPServer((HOST, PORT), TemplateAPIHandler)
    print(f"Server running on http://{HOST}:{PORT}")
    server.serve_forever()
PYTHON_EOF

    # Replace placeholders in Python script
    sed -i.bak "s/TEMPLATE_PORT/$PORT/g" /tmp/template-api-server.py
    sed -i.bak "s/TEMPLATE_HOST/$HOST/g" /tmp/template-api-server.py
    sed -i.bak "s|TEMPLATE_SCRIPT_DIR|$SCRIPT_DIR|g" /tmp/template-api-server.py
    rm /tmp/template-api-server.py.bak

    # Run Python server
    python3 /tmp/template-api-server.py
fi

# Route request based on path
route_request() {
    local method="$1"
    local path="$2"

    # Only handle GET requests
    if [ "$method" != "GET" ]; then
        send_error 405 "Method Not Allowed"
        return
    fi

    # Parse path and query string
    local base_path="${path%%\?*}"
    local query_string="${path#*\?}"

    # Parse query parameters
    local region="us-east-1"
    local category="all"
    local page="1"
    local per_page="50"
    local query=""
    local format="raw"

    if [ "$query_string" != "$path" ]; then
        # Parse query parameters (basic implementation)
        IFS='&' read -ra params <<< "$query_string"
        for param in "${params[@]}"; do
            key="${param%%=*}"
            value="${param#*=}"
            value=$(printf '%b' "${value//%/\\x}")  # URL decode

            case "$key" in
                region) region="$value" ;;
                category) category="$value" ;;
                page) page="$value" ;;
                per_page) per_page="$value" ;;
                q) query="$value" ;;
                format) format="$value" ;;
            esac
        done
    fi

    # Route to appropriate API function
    case "$base_path" in
        /api/info)
            send_json "$(api_info)"
            ;;
        /api/regions)
            send_json "$(api_regions)"
            ;;
        /api/templates)
            send_json "$(api_templates "$region" "$category" "$page" "$per_page")"
            ;;
        /api/categories)
            send_json "$(api_categories "$region")"
            ;;
        /api/quickstarts)
            send_json "$(api_quickstarts "$category" "$page" "$per_page")"
            ;;
        /api/search)
            if [ -n "$query" ]; then
                send_json "$(api_search "$query" "$region" "$page" "$per_page")"
            else
                send_error 400 "Search query required"
            fi
            ;;
        /api/templates/*)
            # Extract template name from path
            local template_name="${base_path#/api/templates/}"

            if [[ "$template_name" == */content ]]; then
                template_name="${template_name%/content}"
                local content
                content=$(api_template_content "$template_name" "$region" "$format")
                if [ "$format" = "raw" ] || [ "$format" = "formatted" ] || [ "$format" = "minified" ]; then
                    send_response "200 OK" "application/json" "$content"
                else
                    send_json "$content"
                fi
            elif [[ "$template_name" == */analyze ]]; then
                template_name="${template_name%/analyze}"
                send_json "$(api_template_analyze "$template_name" "$region")"
            elif [[ "$template_name" == */estimate ]]; then
                template_name="${template_name%/estimate}"
                send_json "$(api_template_estimate "$template_name" "$region")"
            else
                send_json "$(api_template_details "$template_name" "$region")"
            fi
            ;;
        /)
            send_html "<h1>Template API Server</h1><p>API endpoint: /api/</p>"
            ;;
        *)
            send_error 404 "Not Found"
            ;;
    esac
}

# Send HTTP response
send_response() {
    local status="$1"
    local content_type="$2"
    local body="$3"

    echo "HTTP/1.1 $status"
    echo "Content-Type: $content_type"
    echo "Content-Length: ${#body}"
    echo "Access-Control-Allow-Origin: $CORS_ORIGIN"
    echo ""
    echo "$body"
}

# Send JSON response
send_json() {
    local json="$1"
    send_response "200 OK" "application/json" "$json"
}

# Send HTML response
send_html() {
    local html="$1"
    send_response "200 OK" "text/html" "$html"
}

# Send error response
send_error() {
    local code="$1"
    local message="$2"

    local status
    case "$code" in
        400) status="400 Bad Request" ;;
        404) status="404 Not Found" ;;
        405) status="405 Method Not Allowed" ;;
        500) status="500 Internal Server Error" ;;
        *) status="$code" ;;
    esac

    local json
    json=$(jq -n --arg msg "$message" --argjson code "$code" '{error: $msg, code: $code}')

    echo "HTTP/1.1 $status"
    echo "Content-Type: application/json"
    echo "Content-Length: ${#json}"
    echo "Access-Control-Allow-Origin: $CORS_ORIGIN"
    echo ""
    echo "$json"
}

# Handle request when called by socat
if [ "$1" = "handle_request" ]; then
    handle_http_request
fi