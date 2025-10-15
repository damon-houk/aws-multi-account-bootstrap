#!/bin/bash

# Script to set up billing alerts and budgets for all project accounts
# Usage: ./setup-billing-alerts.sh TPA your-email@example.com

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Check arguments
if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    echo -e "${RED}ERROR: Invalid arguments${NC}"
    echo ""
    echo "Usage: $0 <PROJECT_CODE> [EMAIL]"
    echo ""
    echo "Example:"
    echo "  $0 TPA"
    echo "  $0 TPA your-email@example.com"
    echo ""
    echo "If EMAIL is not provided, it will be fetched from AWS account"
    exit 1
fi

PROJECT_CODE=$1
EMAIL=${2:-""}

echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║         AWS Billing Alerts & Budget Setup                ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}ERROR: AWS CLI is not installed${NC}"
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${RED}ERROR: jq is not installed (brew install jq)${NC}"
    exit 1
fi

# Get email if not provided
if [ -z "$EMAIL" ]; then
    echo "Fetching account email..."
    CALLER_IDENTITY=$(aws sts get-caller-identity)
    ACCOUNT_ID=$(echo "$CALLER_IDENTITY" | jq -r '.Account')

    # Try to get email from account
    EMAIL=$(aws organizations describe-account --account-id "$ACCOUNT_ID" --query 'Account.Email' --output text 2>/dev/null || echo "")

    if [ -z "$EMAIL" ]; then
        echo -e "${RED}ERROR: Could not determine email address${NC}"
        echo "Please provide email as second argument"
        exit 1
    fi
fi

echo -e "${GREEN}Configuration${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Project Code:    $PROJECT_CODE"
echo "  Email:           $EMAIL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Budget thresholds per environment
declare -A ALERT_THRESHOLD
declare -A BUDGET_LIMIT
ALERT_THRESHOLD[dev]=15
ALERT_THRESHOLD[staging]=15
ALERT_THRESHOLD[prod]=15
BUDGET_LIMIT[dev]=25
BUDGET_LIMIT[staging]=25
BUDGET_LIMIT[prod]=25

echo -e "${BLUE}Budget Configuration:${NC}"
echo "  Dev:     Alert at \$${ALERT_THRESHOLD[dev]}, Budget limit \$${BUDGET_LIMIT[dev]}"
echo "  Staging: Alert at \$${ALERT_THRESHOLD[staging]}, Budget limit \$${BUDGET_LIMIT[staging]}"
echo "  Prod:    Alert at \$${ALERT_THRESHOLD[prod]}, Budget limit \$${BUDGET_LIMIT[prod]}"
echo ""

read -p "Continue with billing alert setup? [y/N] " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

# Get account IDs from CloudFormation
echo -e "${BLUE}Fetching account IDs...${NC}"

STACK_NAME="${PROJECT_CODE}-Accounts"
DEV_ACCOUNT_ID=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query "Stacks[0].Outputs[?OutputKey=='DevAccountId'].OutputValue" \
    --output text 2>/dev/null || echo "")

STAGING_ACCOUNT_ID=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query "Stacks[0].Outputs[?OutputKey=='StagingAccountId'].OutputValue" \
    --output text 2>/dev/null || echo "")

PROD_ACCOUNT_ID=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query "Stacks[0].Outputs[?OutputKey=='ProdAccountId'].OutputValue" \
    --output text 2>/dev/null || echo "")

if [ -z "$DEV_ACCOUNT_ID" ] || [ -z "$STAGING_ACCOUNT_ID" ] || [ -z "$PROD_ACCOUNT_ID" ]; then
    echo -e "${RED}ERROR: Could not fetch account IDs${NC}"
    echo "Make sure you've created the accounts first"
    exit 1
fi

declare -A ACCOUNT_IDS
ACCOUNT_IDS[dev]=$DEV_ACCOUNT_ID
ACCOUNT_IDS[staging]=$STAGING_ACCOUNT_ID
ACCOUNT_IDS[prod]=$PROD_ACCOUNT_ID

echo "  Dev:     $DEV_ACCOUNT_ID"
echo "  Staging: $STAGING_ACCOUNT_ID"
echo "  Prod:    $PROD_ACCOUNT_ID"
echo ""

# Function to create SNS topic and subscription
create_sns_topic() {
    local ENV=$1
    local ACCOUNT_ID=$2
    local TOPIC_NAME="${PROJECT_CODE}-${ENV}-billing-alerts"

    echo "  Creating SNS topic: $TOPIC_NAME"

    TOPIC_ARN=$(aws sns create-topic \
        --name "$TOPIC_NAME" \
        --output text \
        --query 'TopicArn' 2>/dev/null || echo "")

    if [ -z "$TOPIC_ARN" ]; then
        # Topic might already exist, try to get it
        TOPIC_ARN=$(aws sns list-topics --query "Topics[?contains(TopicArn, '$TOPIC_NAME')].TopicArn" --output text)
    fi

    if [ -n "$TOPIC_ARN" ]; then
        echo "    Topic ARN: $TOPIC_ARN"

        # Subscribe email to topic
        echo "    Subscribing $EMAIL to topic..."
        aws sns subscribe \
            --topic-arn "$TOPIC_ARN" \
            --protocol email \
            --notification-endpoint "$EMAIL" \
            --output text > /dev/null 2>&1 || true

        echo "    ✓ Email subscription created (check $EMAIL for confirmation)"
    fi

    echo "$TOPIC_ARN"
}

# Function to create CloudWatch billing alarm
create_billing_alarm() {
    local ENV=$1
    local ACCOUNT_ID=$2
    local THRESHOLD=$3
    local TOPIC_ARN=$4
    local ALARM_NAME="${PROJECT_CODE}-${ENV}-billing-alarm"

    echo "  Creating CloudWatch alarm: $ALARM_NAME (threshold: \$$THRESHOLD)"

    aws cloudwatch put-metric-alarm \
        --alarm-name "$ALARM_NAME" \
        --alarm-description "Billing alert for ${PROJECT_CODE} ${ENV} environment when charges exceed \$$THRESHOLD" \
        --metric-name EstimatedCharges \
        --namespace AWS/Billing \
        --statistic Maximum \
        --period 21600 \
        --evaluation-periods 1 \
        --threshold "$THRESHOLD" \
        --comparison-operator GreaterThanThreshold \
        --dimensions Name=Currency,Value=USD \
        --alarm-actions "$TOPIC_ARN" \
        --treat-missing-data notBreaching \
        2>/dev/null || echo "    Note: Alarm creation failed (billing metrics may not be enabled)"
}

# Function to create AWS Budget
create_budget() {
    local ENV=$1
    local ACCOUNT_ID=$2
    local BUDGET_AMOUNT=$3
    local ALERT_AMOUNT=$4
    local BUDGET_NAME="${PROJECT_CODE}-${ENV}-monthly-budget"

    echo "  Creating AWS Budget: $BUDGET_NAME (limit: \$$BUDGET_AMOUNT)"

    # Create budget JSON
    cat > /tmp/budget-${ENV}.json <<EOF
{
  "BudgetName": "$BUDGET_NAME",
  "BudgetType": "COST",
  "TimeUnit": "MONTHLY",
  "BudgetLimit": {
    "Amount": "$BUDGET_AMOUNT",
    "Unit": "USD"
  },
  "CostFilters": {},
  "CostTypes": {
    "IncludeTax": true,
    "IncludeSubscription": true,
    "UseBlended": false,
    "IncludeRefund": false,
    "IncludeCredit": false,
    "IncludeUpfront": true,
    "IncludeRecurring": true,
    "IncludeOtherSubscription": true,
    "IncludeSupport": true,
    "IncludeDiscount": true,
    "UseAmortized": false
  },
  "TimePeriod": {
    "Start": "$(date -u +%Y-%m-01T00:00:00Z)",
    "End": "2087-06-15T00:00:00Z"
  }
}
EOF

    # Create notifications JSON
    cat > /tmp/notifications-${ENV}.json <<EOF
[
  {
    "Notification": {
      "NotificationType": "ACTUAL",
      "ComparisonOperator": "GREATER_THAN",
      "Threshold": $(awk "BEGIN {print ($ALERT_AMOUNT/$BUDGET_AMOUNT)*100}"),
      "ThresholdType": "PERCENTAGE"
    },
    "Subscribers": [
      {
        "SubscriptionType": "EMAIL",
        "Address": "$EMAIL"
      }
    ]
  },
  {
    "Notification": {
      "NotificationType": "ACTUAL",
      "ComparisonOperator": "GREATER_THAN",
      "Threshold": 90.0,
      "ThresholdType": "PERCENTAGE"
    },
    "Subscribers": [
      {
        "SubscriptionType": "EMAIL",
        "Address": "$EMAIL"
      }
    ]
  },
  {
    "Notification": {
      "NotificationType": "FORECASTED",
      "ComparisonOperator": "GREATER_THAN",
      "Threshold": 100.0,
      "ThresholdType": "PERCENTAGE"
    },
    "Subscribers": [
      {
        "SubscriptionType": "EMAIL",
        "Address": "$EMAIL"
      }
    ]
  }
]
EOF

    # Create budget
    aws budgets create-budget \
        --account-id "$ACCOUNT_ID" \
        --budget file:///tmp/budget-${ENV}.json \
        --notifications-with-subscribers file:///tmp/notifications-${ENV}.json \
        2>/dev/null || echo "    Note: Budget may already exist or billing access needed"

    # Cleanup temp files
    rm -f /tmp/budget-${ENV}.json /tmp/notifications-${ENV}.json
}

# Setup billing alerts for each environment
for ENV in dev staging prod; do
    ACCOUNT_ID=${ACCOUNT_IDS[$ENV]}
    ALERT_THRESH=${ALERT_THRESHOLD[$ENV]}
    BUDGET_LIM=${BUDGET_LIMIT[$ENV]}

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Setting up billing alerts for ${ENV^^} ($ACCOUNT_ID)${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Assume role into the account
    ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/OrganizationAccountAccessRole"

    echo "  Assuming role: $ROLE_ARN"
    CREDENTIALS=$(aws sts assume-role \
        --role-arn "$ROLE_ARN" \
        --role-session-name "billing-setup-${ENV}" \
        --output json)

    export AWS_ACCESS_KEY_ID
    export AWS_SECRET_ACCESS_KEY
    export AWS_SESSION_TOKEN
    AWS_ACCESS_KEY_ID=$(echo "$CREDENTIALS" | jq -r '.Credentials.AccessKeyId')
    AWS_SECRET_ACCESS_KEY=$(echo "$CREDENTIALS" | jq -r '.Credentials.SecretAccessKey')
    AWS_SESSION_TOKEN=$(echo "$CREDENTIALS" | jq -r '.Credentials.SessionToken')

    # Create SNS topic for alerts
    TOPIC_ARN=$(create_sns_topic "$ENV" "$ACCOUNT_ID")

    # Create CloudWatch billing alarm (only works in us-east-1)
    if [ -n "$TOPIC_ARN" ]; then
        AWS_REGION=us-east-1 create_billing_alarm "$ENV" "$ACCOUNT_ID" "$ALERT_THRESH" "$TOPIC_ARN"
    fi

    # Create AWS Budget
    create_budget "$ENV" "$ACCOUNT_ID" "$BUDGET_LIM" "$ALERT_THRESH"

    # Clean up temp credentials
    unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN

    echo -e "${GREEN}  ✓ ${ENV} billing alerts configured${NC}"
done

# Create summary document
cat > BILLING_ALERTS_SUMMARY.md <<EOF
# Billing Alerts Configuration Summary

## Overview
Billing alerts have been configured for all ${PROJECT_CODE} environments.

## Current Configuration

| Environment | Alert Threshold | Budget Limit | Account ID |
|-------------|----------------|--------------|------------|
| Dev | \$${ALERT_THRESHOLD[dev]} | \$${BUDGET_LIMIT[dev]} | ${ACCOUNT_IDS[dev]} |
| Staging | \$${ALERT_THRESHOLD[staging]} | \$${BUDGET_LIMIT[staging]} | ${ACCOUNT_IDS[staging]} |
| Prod | \$${ALERT_THRESHOLD[prod]} | \$${BUDGET_LIMIT[prod]} | ${ACCOUNT_IDS[prod]} |

## Alert Types

### 1. CloudWatch Billing Alarms
- **Trigger**: When estimated charges exceed alert threshold
- **Frequency**: Checked every 6 hours
- **Notification**: Email to ${EMAIL}

### 2. AWS Budgets
- **Alert at**: When actual spending reaches alert threshold
- **Alert at 90%**: When actual spending reaches 90% of budget limit
- **Forecast Alert**: When forecasted spending will exceed budget limit
- **Monthly Reset**: Budget resets on the 1st of each month

## Email Notifications

You will receive emails at: **${EMAIL}**

**Important**: Check your email and confirm SNS topic subscriptions for each environment!

## Adjusting Thresholds

### Option 1: Re-run Setup Script with Custom Values

Edit the script \`setup-billing-alerts.sh\` and modify these lines:

\`\`\`bash
# Around line 60
ALERT_THRESHOLD[dev]=15      # Change to your desired alert threshold
ALERT_THRESHOLD[staging]=15
ALERT_THRESHOLD[prod]=15
BUDGET_LIMIT[dev]=25         # Change to your desired budget limit
BUDGET_LIMIT[staging]=25
BUDGET_LIMIT[prod]=25
\`\`\`

Then re-run:
\`\`\`bash
./setup-billing-alerts.sh ${PROJECT_CODE} ${EMAIL}
\`\`\`

### Option 2: Update via AWS Console

#### Update CloudWatch Alarms:
1. Log into the specific environment account
2. Go to **CloudWatch** → **Alarms** (must be in us-east-1 region)
3. Select the alarm (e.g., \`${PROJECT_CODE}-dev-billing-alarm\`)
4. Click **Actions** → **Edit**
5. Change the threshold value
6. Click **Update alarm**

#### Update AWS Budgets:
1. Log into the specific environment account
2. Go to **AWS Budgets** (or Billing → Budgets)
3. Select the budget (e.g., \`${PROJECT_CODE}-dev-monthly-budget\`)
4. Click **Edit**
5. Modify:
   - Budget amount (monthly limit)
   - Alert thresholds (when to notify)
   - Email addresses
6. Click **Save**

### Option 3: Update via AWS CLI

#### Update CloudWatch Alarm:
\`\`\`bash
# Assume role into target account
aws sts assume-role \\
  --role-arn arn:aws:iam::ACCOUNT_ID:role/OrganizationAccountAccessRole \\
  --role-session-name billing-update

# Set credentials from assume-role output
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_SESSION_TOKEN=...

# Update alarm (must be us-east-1)
aws cloudwatch put-metric-alarm \\
  --region us-east-1 \\
  --alarm-name ${PROJECT_CODE}-dev-billing-alarm \\
  --threshold 20 \\
  --alarm-description "Updated threshold to \$20"
\`\`\`

#### Update AWS Budget:
\`\`\`bash
# First, delete the old budget
aws budgets delete-budget \\
  --account-id ACCOUNT_ID \\
  --budget-name ${PROJECT_CODE}-dev-monthly-budget

# Then create new budget with updated values
# (See create_budget function in setup-billing-alerts.sh)
\`\`\`

## Monitoring Costs

### View Current Spending

#### AWS Console:
1. Log into each account
2. Go to **Billing** → **Cost Explorer**
3. View current month costs

#### AWS CLI:
\`\`\`bash
# Get current month costs for an account
aws ce get-cost-and-usage \\
  --time-period Start=\$(date -u +%Y-%m-01),End=\$(date -u +%Y-%m-%d) \\
  --granularity MONTHLY \\
  --metrics BlendedCost \\
  --group-by Type=DIMENSION,Key=SERVICE

# Get costs by tag (if resources are tagged)
aws ce get-cost-and-usage \\
  --time-period Start=\$(date -u +%Y-%m-01),End=\$(date -u +%Y-%m-%d) \\
  --granularity MONTHLY \\
  --metrics BlendedCost \\
  --group-by Type=TAG,Key=Project
\`\`\`

### Cost Anomaly Detection

Consider enabling AWS Cost Anomaly Detection:
1. Go to **Cost Management** → **Cost Anomaly Detection**
2. Click **Get started** or **Create monitor**
3. Configure anomaly detection rules
4. Set up notifications

## Best Practices

### 1. Tag All Resources
\`\`\`typescript
// In your CDK stacks
cdk.Tags.of(stack).add('Project', '${PROJECT_CODE}');
cdk.Tags.of(stack).add('Environment', env);
cdk.Tags.of(stack).add('ManagedBy', 'CDK');
\`\`\`

### 2. Review Costs Weekly
- Check Cost Explorer every Monday
- Look for unexpected spikes
- Identify unused resources

### 3. Set Up Cost Allocation Tags
1. Go to **Billing** → **Cost Allocation Tags**
2. Activate tags: Project, Environment, ManagedBy
3. Wait 24 hours for data to populate
4. Use tags to filter costs

### 4. Enable Cost Recommendations
- **AWS Compute Optimizer**: Right-size EC2, Lambda
- **Trusted Advisor**: Cost optimization checks
- **S3 Storage Lens**: S3 cost insights

### 5. Shut Down Dev Resources
\`\`\`bash
# Stop EC2 instances in dev overnight (if applicable)
# Delete unused CloudFormation stacks
make destroy-dev  # When not actively developing
\`\`\`

## Troubleshooting

### Not Receiving Emails?
1. Check spam folder
2. Confirm SNS subscriptions (check email)
3. Verify email address is correct in SNS topics

### Alarms Not Triggering?
1. Billing metrics must be enabled in account preferences
2. CloudWatch alarms only work in us-east-1
3. Wait up to 24 hours for first data point

### Budget Not Showing Data?
1. Budgets take 24 hours to populate
2. Ensure IAM permissions for billing access
3. Check that account has billing activity

## Useful Links

- [AWS Billing Console](https://console.aws.amazon.com/billing/)
- [AWS Cost Explorer](https://console.aws.amazon.com/cost-management/home#/cost-explorer)
- [AWS Budgets](https://console.aws.amazon.com/billing/home#/budgets)
- [CloudWatch Billing Alarms](https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#alarmsV2:)

## Next Steps

1. ✅ Confirm all SNS email subscriptions
2. ✅ Review billing dashboard for each account
3. ✅ Set up cost allocation tags
4. ✅ Schedule weekly cost review
5. ✅ Enable AWS Cost Anomaly Detection (optional)

---

**Created**: $(date)
**Project**: ${PROJECT_CODE}
**Email**: ${EMAIL}
EOF

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Billing Alerts Setup Complete!${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}IMPORTANT: Check your email (${EMAIL}) and confirm the SNS subscriptions!${NC}"
echo ""
echo "Summary written to: BILLING_ALERTS_SUMMARY.md"
echo ""
echo -e "${BLUE}Configuration:${NC}"
echo "  • CloudWatch alarms created (alert at \$15)"
echo "  • AWS Budgets created (limit \$25)"
echo "  • Email notifications to: ${EMAIL}"
echo "  • Monthly budget reset on 1st of month"
echo ""
echo -e "${BLUE}To adjust thresholds:${NC}"
echo "  • Edit setup-billing-alerts.sh and re-run, or"
echo "  • Use AWS Console (see BILLING_ALERTS_SUMMARY.md), or"
echo "  • See documentation in BILLING_ALERTS_SUMMARY.md"
echo ""
echo -e "${GREEN}Done! 💰${NC}"
echo ""