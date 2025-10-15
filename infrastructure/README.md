# Sample CDK Infrastructure

This directory contains **example CDK infrastructure** used for:

1. **CI/CD Testing**: The `cdk synth` command validates TypeScript compilation and CDK construct validity without deploying actual AWS resources
2. **Documentation**: Demonstrates the patterns and structure users should follow when building their infrastructure
3. **Cost-Free Validation**: Runs in GitHub Actions on every PR/push to catch errors early

## Structure

```
infrastructure/
├── bin/
│   └── app.ts           # CDK app entry point
└── lib/
    └── example-stack.ts # Sample stack with S3 bucket and IAM role
```

## Usage

### Local Testing
```bash
# Synthesize CloudFormation templates
npm install
export ENV=dev PROJECT_CODE=DEMO
npx cdk synth

# View generated templates
ls -la cdk.out/*.template.json
```

### CI/CD
This infrastructure is automatically validated in the `cdk-synth` job of `.github/workflows/ci.yml`.

## What Gets Validated

- ✅ TypeScript compilation
- ✅ CDK construct syntax
- ✅ IAM policy validity
- ✅ Resource naming and tagging
- ✅ CloudFormation template generation

## For Users

When you run `make setup-all`, this tool generates a similar structure in your project with additional customization based on your requirements. This example serves as a template for what gets generated.