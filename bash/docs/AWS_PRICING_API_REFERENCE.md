# AWS Bulk Pricing API Reference

## Overview
AWS provides a public, credential-free API for accessing current pricing data.

## API Endpoint Structure
```
https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/{SERVICE}/current/index.json
```

### Service Names (examples)
- `AmazonCloudWatch`
- `AWSCloudTrail`
- `AWSConfig`
- `AmazonEC2`
- `AmazonS3`
- `awslambda`

## JSON Structure

### Root Object
```json
{
  "formatVersion": "v1.0",
  "disclaimer": "...",
  "offerCode": "AmazonCloudWatch",
  "version": "20241219000000",
  "publicationDate": "2024-12-19T00:00:00Z",
  "products": { ... },
  "terms": { ... }
}
```

### Products Section
Maps SKU (unique identifier) to product details:

```json
"products": {
  "SKU123": {
    "sku": "SKU123",
    "productFamily": "Alarm",
    "attributes": {
      "servicecode": "AmazonCloudWatch",
      "location": "US East (N. Virginia)",
      "locationType": "AWS Region",
      "usagetype": "CW:AlarmMonitorUsage",
      "regionCode": "us-east-1",
      "servicename": "AmazonCloudWatch"
    }
  }
}
```

**Key Attributes:**
- `productFamily`: Type of service (Alarm, Data Payload, API Request, etc.)
- `regionCode`: AWS region identifier (us-east-1, eu-west-1, etc.)
- `usagetype`: Specific usage pattern
- `location`: Human-readable region name

### Terms Section
Contains pricing information mapped by SKU:

```json
"terms": {
  "OnDemand": {
    "SKU123": {
      "SKU123.JRTCKXETXF": {
        "offerTermCode": "JRTCKXETXF",
        "sku": "SKU123",
        "effectiveDate": "2025-09-01T00:00:00Z",
        "priceDimensions": {
          "SKU123.JRTCKXETXF.6YS6EN2CT7": {
            "rateCode": "SKU123.JRTCKXETXF.6YS6EN2CT7",
            "description": "$0.10 per alarm per month",
            "beginRange": "0",
            "endRange": "Inf",
            "unit": "Alarms",
            "pricePerUnit": {
              "USD": "0.1000000000"
            }
          }
        }
      }
    }
  }
}
```

## Extracting Prices - Step by Step

1. **Find Product SKU**
   ```bash
   # Find SKU for CloudWatch alarms in us-east-1
   jq '.products | to_entries[] |
       select(.value.productFamily == "Alarm" and
              .value.attributes.regionCode == "us-east-1") |
       .key' pricing.json
   ```

2. **Lookup Price Using SKU**
   ```bash
   # Get price for specific SKU
   jq '.terms.OnDemand["SKU123"] |
       to_entries[0].value.priceDimensions |
       to_entries[0].value.pricePerUnit.USD' pricing.json
   ```

3. **Combined Query**
   ```bash
   # Find product and price together
   SKU=$(jq -r '.products | to_entries[] |
                select(.value.productFamily == "Alarm" and
                       .value.attributes.regionCode == "us-east-1") |
                .key' pricing.json | head -1)

   jq -r --arg sku "$SKU" '
     .terms.OnDemand[$sku] |
     to_entries[0].value.priceDimensions |
     to_entries[0].value.pricePerUnit.USD' pricing.json
   ```

## Common Patterns

### Filter by Product Family
- `"Alarm"` - CloudWatch alarms
- `"API Request"` - API calls
- `"Data Payload"` - Data transfer/storage
- `"Management Tools - AWS Config Rules"` - Config rules

### Filter by Region
- Use `.attributes.regionCode` for programmatic access
- Common codes: `us-east-1`, `us-west-2`, `eu-west-1`, `ap-southeast-1`

### Price Units
- `"Alarms"` - Per alarm per month
- `"Events"` - Per number of events
- `"GB"` - Per gigabyte
- `"Requests"` - Per API request
- `"ConfigurationItemRecorded"` - Per config item

## Implementation Example

```bash
#!/bin/bash

# Function to get price for a service/region/product type
get_aws_price() {
    local service=$1
    local region=$2
    local product_family=$3

    # Download pricing
    local url="https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/${service}/current/index.json"
    local pricing=$(curl -s "$url")

    # Find SKU
    local sku=$(echo "$pricing" | jq -r --arg region "$region" --arg family "$product_family" '
        .products | to_entries[] |
        select(.value.productFamily == $family and
               .value.attributes.regionCode == $region) |
        .key' | head -1)

    # Get price
    echo "$pricing" | jq -r --arg sku "$sku" '
        .terms.OnDemand[$sku] |
        to_entries[0].value.priceDimensions |
        to_entries[0].value.pricePerUnit.USD'
}

# Usage
ALARM_PRICE=$(get_aws_price "AmazonCloudWatch" "us-east-1" "Alarm")
echo "CloudWatch Alarm: \$${ALARM_PRICE}/month"
```

## Caching Strategy
- Cache responses locally (JSON files can be 3-50MB)
- Refresh daily or weekly (prices change infrequently)
- Store by service and timestamp

## Notes
- No authentication required (public API)
- Always returns current prices
- Large responses (use streaming/chunking for production)
- Terms may have multiple entries; typically use first OnDemand entry
- Prices are strings, not numbers (e.g., "0.1000000000")