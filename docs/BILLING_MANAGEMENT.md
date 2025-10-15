# AWS Billing Management Guide

## 📊 Overview

This guide covers how to manage, monitor, and optimize costs across your multi-account AWS setup.

## 🔔 Current Alert Configuration

### Default Thresholds (Per Account)

| Metric | Value | When It Triggers |
|--------|-------|------------------|
| **Alert Threshold** | $15 | Email sent when charges reach $15 |
| **Budget Limit** | $25 | Email sent at 90% ($22.50) and 100% ($25) |
| **Forecast Alert** | $25 | Email sent when forecasted to exceed $25 |

### Alert Types

#### 1. CloudWatch Billing Alarm
- **Triggers at**: $15 actual charges
- **Check frequency**: Every 6 hours
- **Region**: us-east-1 only (billing metrics requirement)
- **Action**: Sends email via SNS

#### 2. AWS Budget Alerts
- **60% threshold**: Alert when spending reaches $15 (60% of $25)
- **90% threshold**: Alert when spending reaches $22.50
- **100% threshold**: Alert when spending reaches $25
- **Forecast alert**: Predicts month-end spending

---

## 🔧 Adjusting Alert Thresholds

### Method 1: Re-run Setup Script (Easiest)

**1. Edit the script:**
```bash
vim setup-billing-alerts.sh
```

**2. Find and modify these lines (around line 60):**
```bash
# Current values
ALERT_THRESHOLD[dev]=15
ALERT_THRESHOLD[staging]=15
ALERT_THRESHOLD[prod]=15
BUDGET_LIMIT[dev]=25
BUDGET_LIMIT[staging]=25
BUDGET_LIMIT[prod]=25
```

**3. Change to your desired values:**
```bash
# Example: Higher limits for prod
ALERT_THRESHOLD[dev]=15
ALERT_THRESHOLD[staging]=20
ALERT_THRESHOLD[prod]=50      # Alert at $50
BUDGET_LIMIT[dev]=25
BUDGET_LIMIT[staging]=35
BUDGET_LIMIT[prod]=100         # Budget limit $100
```

**4. Re-run the script:**
```bash
make setup-billing PROJECT_CODE=TPA EMAIL=your-email@example.com
# or
./setup-billing-alerts.sh TPA your-email@example.com
```

This will update all alarms and budgets with the new values.

---

### Method 2: AWS Console (Individual Changes)

#### Update CloudWatch Alarm:

**Step 1:** Log into the target account
- Use AWS Console
- Switch to **us-east-1** region (required for billing metrics)

**Step 2:** Navigate to CloudWatch
- Services → CloudWatch → Alarms

**Step 3:** Find and edit the alarm
- Look for: `TPA-dev-billing-alarm` (or staging/prod)
- Click the alarm name
- Click **Actions** → **Edit**

**Step 4:** Modify threshold
- Change "Threshold value" to your desired amount (e.g., `20`)
- Click **Update alarm**

#### Update AWS Budget:

**Step 1:** Log into the target account

**Step 2:** Navigate to Budgets
- Services → AWS Cost Management → Budgets
- Or go directly to: https://console.aws.amazon.com/billing/home#/budgets

**Step 3:** Select the budget
- Click on: `TPA-dev-monthly-budget` (or staging/prod)

**Step 4:** Edit budget
- Click **Edit** in the top right
- Modify:
    - **Budgeted amount**: Change monthly limit (e.g., `35`)
    - **Alert thresholds**: Adjust percentages or dollar amounts
    - **Email addresses**: Add/remove notification recipients
- Click **Save**

**Step 5:** Configure notifications
- You can set up to 5 different notification thresholds
- Each can be based on:
    - **Actual costs**: Real spending so far this month
    - **Forecasted costs**: Predicted end-of-month spending

---

### Method 3: AWS CLI (Scriptable)

#### Update CloudWatch Alarm:
```bash
# Set your account and threshold
ACCOUNT_ID="781234567890"
ENV="dev"
NEW_THRESHOLD="20"
PROJECT_CODE="TPA"

# Assume role into the account
CREDS=$(aws sts assume-role \
  --role-arn "arn:aws:iam::${ACCOUNT_ID}:role/OrganizationAccountAccessRole" \
  --role-session-name "billing-update")

export AWS_ACCESS_KEY_ID=$(echo $CREDS | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo $CREDS | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo $CREDS | jq -r '.Credentials.SessionToken')

# Update the alarm (must be us-east-1)
aws cloudwatch put-metric-alarm \
  --region us-east-1 \
  --alarm-name "${PROJECT_CODE}-${ENV}-billing-alarm" \
  --alarm-description "Alert when charges exceed \$${NEW_THRESHOLD}" \
  --metric-name EstimatedCharges \
  --namespace AWS/Billing \
  --statistic Maximum \
  --period 21600 \
  --evaluation-periods 1 \
  --threshold $NEW_THRESHOLD \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=Currency,Value=USD

# Clean up credentials
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN

echo "Alarm updated to \$$NEW_THRESHOLD"
```

#### Update AWS Budget:
```bash
# Set your parameters
ACCOUNT_ID="781234567890"
ENV="dev"
NEW_BUDGET="35"
NEW_ALERT="20"
PROJECT_CODE="TPA"
EMAIL="your-email@example.com"

# Create budget JSON
cat > /tmp/update-budget.json <<EOF
{
  "BudgetName": "${PROJECT_CODE}-${ENV}-monthly-budget",
  "BudgetType": "COST",
  "TimeUnit": "MONTHLY",
  "BudgetLimit": {
    "Amount": "${NEW_BUDGET}",
    "Unit": "USD"
  },
  "CostTypes": {
    "IncludeTax": true,
    "IncludeSubscription": true,
    "UseBlended": false
  }
}
EOF

# Delete old budget
aws budgets delete-budget \
  --account-id $ACCOUNT_ID \
  --budget-name "${PROJECT_CODE}-${ENV}-monthly-budget"

# Create new budget
aws budgets create-budget \
  --account-id $ACCOUNT_ID \
  --budget file:///tmp/update-budget.json \
  --notifications-with-subscribers "[
    {
      \"Notification\": {
        \"NotificationType\": \"ACTUAL\",
        \"ComparisonOperator\": \"GREATER_THAN\",
        \"Threshold\": $(awk "BEGIN {print ($NEW_ALERT/$NEW_BUDGET)*100}"),
        \"ThresholdType\": \"PERCENTAGE\"
      },
      \"Subscribers\": [{\"SubscriptionType\": \"EMAIL\", \"Address\": \"$EMAIL\"}]
    }
  ]"

rm /tmp/update-budget.json
echo "Budget updated to \$$NEW_BUDGET with alert at \$$NEW_ALERT"
```

---

## 📈 Monitoring Costs

### Quick Cost Check Commands

```bash
# Get account IDs
make account-info PROJECT_CODE=TPA

# Current month costs for dev account
aws ce get-cost-and-usage \
  --time-period Start=$(date -u +%Y-%m-01),End=$(date -u +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --profile tpa-dev

# Costs by service
aws ce get-cost-and-usage \
  --time-period Start=$(date -u +%Y-%m-01),End=$(date -u +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE \
  --profile tpa-dev | jq '.ResultsByTime[0].Groups[] | {Service: .Keys[0], Cost: .Metrics.BlendedCost.Amount}'

# Forecast for end of month
aws ce get-cost-forecast \
  --time-period Start=$(date -u +%Y-%m-%d),End=$(date -u -d "$(date +%Y-%m-01) +1 month -1 day" +%Y-%m-%d) \
  --metric BLENDED_COST \
  --granularity MONTHLY \
  --profile tpa-dev
```

### AWS Console Cost Explorer

**Access:** https://console.aws.amazon.com/cost-management/home#/cost-explorer

**Useful Views:**
1. **Daily costs** - Spot trends early
2. **Cost by service** - Identify expensive services
3. **Cost by tag** - Track costs by Project/Environment
4. **Cost forecast** - Predict month-end spending
5. **Reserved Instance recommendations** - Save money long-term

### Setting Up Cost Allocation Tags

**Step 1:** Tag all resources in your CDK code
```typescript
// In your CDK stacks
import * as cdk from 'aws-cdk-lib';

const stack = new cdk.Stack(app, 'MyStack', {
  tags: {
    Project: 'TPA',
    Environment: 'dev',
    ManagedBy: 'CDK',
    CostCenter: 'Engineering',
  },
});

// Or tag individual constructs
cdk.Tags.of(myBucket).add('Owner', 'TeamA');
```

**Step 2:** Activate tags in AWS
1. Go to **Billing** → **Cost Allocation Tags**
2. Find your tags (Project, Environment, ManagedBy)
3. Click **Activate**
4. Wait 24 hours for data to populate

**Step 3:** Filter costs by tag in Cost Explorer
- Group by: Tag → Project
- Filter by: Environment = "dev"

---

## 💰 Cost Optimization Tips

### 1. Development Environment Savings

**Shut down resources when not in use:**
```bash
# Example: Stop all EC2 instances in dev
aws ec2 stop-instances \
  --instance-ids $(aws ec2 describe-instances \
    --filters "Name=tag:Environment,Values=dev" "Name=instance-state-name,Values=running" \
    --query "Reservations[].Instances[].InstanceId" \
    --output text) \
  --profile tpa-dev

# Destroy dev stack when not developing
make destroy-dev
```

**Schedule on/off times:**
- Use AWS Instance Scheduler
- Lambda function to stop/start resources
- EventBridge rules for scheduled actions

### 2. Right-Size Resources

**Common oversizing:**
- Lambda with too much memory
- RDS instances larger than needed
- DynamoDB provisioned capacity too high

**Solutions:**
- Start small, scale up based on metrics
- Use AWS Compute Optimizer recommendations
- Monitor actual usage in CloudWatch

### 3. Use Free Tier Efficiently

**Free tier limits (monthly):**
- Lambda: 1M requests, 400K GB-seconds
- DynamoDB: 25 GB storage, 25 WCU, 25 RCU
- S3: 5 GB storage, 20K GET, 2K PUT requests
- CloudWatch: 10 custom metrics, 5 GB logs
- API Gateway: 1M REST API calls

**Strategy:**
- Stay within free tier for dev
- Use DynamoDB on-demand for low traffic
- Implement S3 lifecycle policies

### 4. Delete Unused Resources

**Common waste:**
- Old CloudFormation stacks
- Detached EBS volumes
- Unattached Elastic IPs
- Old S3 buckets with versioning
- Idle load balancers

**Find unused resources:**
```bash
# Unattached EBS volumes
aws ec2 describe-volumes \
  --filters "Name=status,Values=available" \
  --profile tpa-dev

# Unused Elastic IPs
aws ec2 describe-addresses \
  --filters "Name=instance-id,Values=''" \
  --profile tpa-dev

# Old CloudFormation stacks
aws cloudformation list-stacks \
  --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE \
  --profile tpa-dev
```

### 5. Optimize Data Transfer

**Expensive:**
- Data transfer OUT to internet
- Cross-region transfer
- NAT Gateway data processing

**Solutions:**
- Use CloudFront for static assets
- Keep resources in same region
- Use VPC endpoints for AWS services
- Compress data before transfer

### 6. Use Savings Plans / Reserved Instances

**When you have predictable workload:**
- 1-year or 3-year commitments
- Up to 72% savings vs on-demand
- Start with Compute Savings Plans (flexible)

**Not recommended for:**
- Dev environments (intermittent usage)
- New projects (uncertain usage patterns)
- First 6 months of operation

---

## 🚨 Cost Anomaly Detection

### Enable AWS Cost Anomaly Detection

**Step 1:** Go to Cost Anomaly Detection
- https://console.aws.amazon.com/cost-management/home#/anomaly-detection

**Step 2:** Create a monitor
- Click **Create monitor**
- Choose monitor type:
    - **AWS Services**: Detect anomalies by service
    - **Linked accounts**: Monitor specific accounts
    - **Cost allocation tags**: Monitor by tag (Project, Environment)

**Step 3:** Set alert threshold
- Anomaly detection uses ML
- Alert threshold: Dollar amount or percentage
- Recommendation: Start with $10 or 50%

**Step 4:** Add subscribers
- Email or SNS topic
- Receive alerts when anomalies detected

### What Triggers an Anomaly?

Cost Anomaly Detection looks for:
- Sudden spikes in spending
- New services being used
- Unusual usage patterns
- Spending significantly above forecast

**Example anomalies:**
- Lambda invocations spike 10x overnight
- New RDS instance left running
- S3 storage doubles in one day
- Forgotten EC2 instance running for weeks

---

## 📧 Email Notification Setup

### Confirming SNS Subscriptions

After running setup, you'll receive confirmation emails for each environment:

**Step 1:** Check your email
- Look for emails from: `AWS Notifications <no-reply@sns.amazonaws.com>`
- Subject: "AWS Notification - Subscription Confirmation"

**Step 2:** Click confirmation link
- Must confirm within 3 days
- One email per environment (dev, staging, prod)

**Step 3:** Verify subscriptions
```bash
# List SNS topics in an account
aws sns list-topics --profile tpa-dev

# List subscriptions for a topic
aws sns list-subscriptions-by-topic \
  --topic-arn arn:aws:sns:us-east-1:ACCOUNT_ID:TPA-dev-billing-alerts \
  --profile tpa-dev
```

### Adding Additional Email Recipients

**Via Console:**
1. Go to SNS → Topics
2. Select: `TPA-dev-billing-alerts`
3. Click **Create subscription**
4. Protocol: Email
5. Endpoint: additional-email@example.com
6. Click **Create subscription**
7. Confirm via email

**Via CLI:**
```bash
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:ACCOUNT_ID:TPA-dev-billing-alerts \
  --protocol email \
  --notification-endpoint additional-email@example.com \
  --profile tpa-dev
```

---

## 📋 Monthly Cost Review Checklist

### Week 1 of Month
- [ ] Review previous month's final costs
- [ ] Check if any budgets were exceeded
- [ ] Investigate any cost anomalies
- [ ] Delete unused resources from previous month

### Week 2 of Month
- [ ] Review current month's costs to date
- [ ] Check forecast for month-end spending
- [ ] Adjust budgets if needed for current month
- [ ] Review Cost Anomaly Detection alerts

### Week 3 of Month
- [ ] Identify top 5 cost drivers
- [ ] Look for optimization opportunities
- [ ] Check for untagged resources
- [ ] Review AWS Trusted Advisor recommendations

### Week 4 of Month
- [ ] Compare actual vs budgeted spending
- [ ] Plan budget adjustments for next month
- [ ] Document any cost-saving actions taken
- [ ] Update team on cost status

---

## 🛠️ Troubleshooting

### Not Receiving Alert Emails

**Check 1:** Confirm SNS subscriptions
```bash
aws sns list-subscriptions --profile tpa-dev
```
Status should be "Confirmed", not "PendingConfirmation"

**Check 2:** Check spam folder
- AWS emails sometimes flagged as spam
- Add `no-reply@sns.amazonaws.com` to contacts

**Check 3:** Verify email in budget
- AWS Console → Budgets → Your Budget → Notifications
- Check email address is correct

**Check 4:** Test SNS topic
```bash
aws sns publish \
  --topic-arn arn:aws:sns:us-east-1:ACCOUNT_ID:TPA-dev-billing-alerts \
  --message "Test alert" \
  --subject "Test" \
  --profile tpa-dev
```

### CloudWatch Alarm Not Triggering

**Check 1:** Billing metrics enabled
- AWS Console → Billing → Billing Preferences
- Check "Receive Billing Alerts" is enabled
- Can only be done from management (payer) account

**Check 2:** Alarm is in us-east-1
- Billing alarms MUST be in us-east-1 region
- Check region in AWS Console top-right

**Check 3:** Wait for data
- Billing metrics update every 6 hours
- Can take 24 hours for first data point

**Check 4:** Alarm state
```bash
aws cloudwatch describe-alarms \
  --alarm-names TPA-dev-billing-alarm \
  --region us-east-1 \
  --profile tpa-dev
```
State should be "OK" or "ALARM", not "INSUFFICIENT_DATA"

### Budget Not Showing Data

**Issue:** Budget created but shows $0

**Solution 1:** Wait 24 hours
- Budgets need 24 hours to populate
- First data appears next day

**Solution 2:** Check account has activity
- Budgets only show if account has charges
- Deploy some resources to generate costs

**Solution 3:** Verify permissions
- IAM role must have budgets:ViewBudget permission
- Check you're logged into correct account

---

## 📚 Additional Resources

### AWS Documentation
- [AWS Budgets Documentation](https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-managing-costs.html)
- [CloudWatch Billing Alarms](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/monitor_estimated_charges_with_cloudwatch.html)
- [Cost Anomaly Detection](https://docs.aws.amazon.com/cost-management/latest/userguide/manage-ad.html)
- [Cost Optimization Best Practices](https://aws.amazon.com/pricing/cost-optimization/)

### Tools
- [AWS Cost Explorer](https://aws.amazon.com/aws-cost-management/aws-cost-explorer/)
- [AWS Pricing Calculator](https://calculator.aws/)
- [AWS Trusted Advisor](https://aws.amazon.com/premiumsupport/technology/trusted-advisor/)
- [AWS Compute Optimizer](https://aws.amazon.com/compute-optimizer/)

### Third-Party Tools
- [CloudHealth](https://www.cloudhealthtech.com/)
- [CloudCheckr](https://cloudcheckr.com/)
- [Cloudability](https://www.cloudability.com/)

---

## 🎯 Summary

**Default Configuration:**
- Alert threshold: $15 per account
- Budget limit: $25 per account
- Notifications via email
- Monthly budget reset

**To Adjust:**
1. Edit `setup-billing-alerts.sh`
2. Run: `make setup-billing PROJECT_CODE=TPA`
3. Or use AWS Console/CLI

**Monitor:**
- Check email for alerts
- Review Cost Explorer weekly
- Enable Cost Anomaly Detection
- Tag all resources

**Optimize:**
- Shut down dev resources when not needed
- Right-size based on actual usage
- Delete unused resources monthly
- Use free tier efficiently

**Questions?** See BILLING_ALERTS_SUMMARY.md for your specific configuration.