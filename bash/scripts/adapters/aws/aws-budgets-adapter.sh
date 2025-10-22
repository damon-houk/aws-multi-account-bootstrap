#!/usr/bin/env bash

# ============================================================================
# AWS Budgets/CloudWatch Adapter
# ============================================================================
#
# Implements cloud-provider-port.sh functions for AWS Budgets and CloudWatch.
# Handles budget creation, billing alarms, and SNS notification setup.
#
# Features:
#   - AWS Budget creation with email notifications
#   - CloudWatch billing alarms
#   - SNS topic creation and email subscriptions
#
# Requirements:
#   - AWS CLI installed and configured
#   - Permissions to manage Budgets, CloudWatch, and SNS
#   - jq for JSON parsing
#
# Usage:
#   source scripts/ports/cloud-provider-port.sh
#   source scripts/adapters/aws/aws-budgets-adapter.sh
#   cloud_provider_create_budget "$account_id" "MonthlyBudget" "100" "user@example.com"
#
# ============================================================================

# Source the port to ensure we implement all required functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/ports/cloud-provider-port.sh
source "$SCRIPT_DIR/../../ports/cloud-provider-port.sh"

# ============================================================================
# Cost Management
# ============================================================================

cloud_provider_create_budget() {
    local account_id=$1
    local budget_name=$2
    local amount=$3
    local email=$4
    local alert_threshold_percentage=${5:-80}

    if [ -z "$account_id" ] || [ -z "$budget_name" ] || [ -z "$amount" ] || [ -z "$email" ]; then
        echo "ERROR: Missing required parameters" >&2
        echo "Usage: cloud_provider_create_budget <account_id> <budget_name> <amount> <email> [alert_threshold_percentage]" >&2
        return 1
    fi

    # Create temporary budget definition file
    local budget_file="/tmp/budget-${account_id}-$(date +%s).json"
    cat > "$budget_file" <<EOF
{
  "BudgetName": "${budget_name}",
  "BudgetType": "COST",
  "TimeUnit": "MONTHLY",
  "BudgetLimit": {
    "Amount": "${amount}",
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

    # Create notifications file
    local notifications_file="/tmp/notifications-${account_id}-$(date +%s).json"
    cat > "$notifications_file" <<EOF
[
  {
    "Notification": {
      "NotificationType": "ACTUAL",
      "ComparisonOperator": "GREATER_THAN",
      "Threshold": ${alert_threshold_percentage}.0,
      "ThresholdType": "PERCENTAGE"
    },
    "Subscribers": [
      {
        "SubscriptionType": "EMAIL",
        "Address": "${email}"
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
        "Address": "${email}"
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
        "Address": "${email}"
      }
    ]
  }
]
EOF

    # Create the budget
    if aws budgets create-budget \
        --account-id "$account_id" \
        --budget "file://${budget_file}" \
        --notifications-with-subscribers "file://${notifications_file}" 2>/dev/null; then
        rm -f "$budget_file" "$notifications_file"
        echo "Budget '${budget_name}' created successfully" >&2
        return 0
    else
        # Budget might already exist
        rm -f "$budget_file" "$notifications_file"
        echo "Budget '${budget_name}' already exists or creation failed (this is usually OK)" >&2
        return 0  # Don't fail if budget already exists
    fi
}

cloud_provider_create_billing_alarm() {
    local account_id=$1
    local alarm_name=$2
    local threshold=$3
    local sns_topic_arn=$4
    local region=${5:-us-east-1}

    if [ -z "$account_id" ] || [ -z "$alarm_name" ] || [ -z "$threshold" ] || [ -z "$sns_topic_arn" ]; then
        echo "ERROR: Missing required parameters" >&2
        echo "Usage: cloud_provider_create_billing_alarm <account_id> <alarm_name> <threshold> <sns_topic_arn> [region]" >&2
        return 1
    fi

    # Billing metrics are only available in us-east-1
    export AWS_DEFAULT_REGION="us-east-1"

    if aws cloudwatch put-metric-alarm \
        --alarm-name "$alarm_name" \
        --alarm-description "Billing alert when charges exceed \$${threshold}" \
        --metric-name EstimatedCharges \
        --namespace AWS/Billing \
        --statistic Maximum \
        --period 21600 \
        --evaluation-periods 1 \
        --threshold "$threshold" \
        --comparison-operator GreaterThanThreshold \
        --dimensions Name=Currency,Value=USD \
        --alarm-actions "$sns_topic_arn" \
        --treat-missing-data notBreaching 2>/dev/null; then
        echo "Billing alarm '${alarm_name}' created successfully" >&2
        return 0
    else
        echo "Billing alarm creation failed (billing metrics may not be enabled)" >&2
        return 1
    fi
}

# ============================================================================
# Notification Services
# ============================================================================

cloud_provider_create_sns_topic() {
    local account_id=$1
    local topic_name=$2
    local region=${3:-us-east-1}

    if [ -z "$account_id" ] || [ -z "$topic_name" ]; then
        echo "ERROR: Missing required parameters" >&2
        echo "Usage: cloud_provider_create_sns_topic <account_id> <topic_name> [region]" >&2
        return 1
    fi

    # Try to create the topic
    local topic_arn
    if topic_arn=$(aws sns create-topic \
        --name "$topic_name" \
        --region "$region" \
        --output text \
        --query 'TopicArn' 2>&1); then
        echo "$topic_arn"
        return 0
    fi

    # If creation failed, topic might already exist - try to find it
    if topic_arn=$(aws sns list-topics \
        --region "$region" \
        --query "Topics[?contains(TopicArn, '${topic_name}')].TopicArn" \
        --output text 2>/dev/null); then
        if [ -n "$topic_arn" ]; then
            echo "$topic_arn"
            return 0
        fi
    fi

    echo "ERROR: Failed to create or find SNS topic: $topic_name" >&2
    return 1
}

cloud_provider_subscribe_email_to_topic() {
    local account_id=$1
    local topic_arn=$2
    local email=$3
    local region=${4:-us-east-1}

    if [ -z "$account_id" ] || [ -z "$topic_arn" ] || [ -z "$email" ]; then
        echo "ERROR: Missing required parameters" >&2
        echo "Usage: cloud_provider_subscribe_email_to_topic <account_id> <topic_arn> <email> [region]" >&2
        return 1
    fi

    # Subscribe email to topic
    local subscription_arn
    if subscription_arn=$(aws sns subscribe \
        --topic-arn "$topic_arn" \
        --protocol email \
        --notification-endpoint "$email" \
        --region "$region" \
        --output text \
        --query 'SubscriptionArn' 2>&1); then
        echo "Email subscription created: $subscription_arn (check $email for confirmation)" >&2
        return 0
    else
        # Subscription might already exist
        echo "Email subscription creation failed or already exists" >&2
        return 0  # Don't fail if subscription already exists
    fi
}

# ============================================================================
# Export Functions
# ============================================================================

export -f cloud_provider_create_budget
export -f cloud_provider_create_billing_alarm
export -f cloud_provider_create_sns_topic
export -f cloud_provider_subscribe_email_to_topic
