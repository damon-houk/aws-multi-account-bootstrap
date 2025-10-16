# E2E - Therapy Practice Management Application

## Project Structure

```
.
├── infrastructure/     # AWS CDK infrastructure code
│   ├── bin/           # CDK app entry point
│   ├── lib/           # CDK stacks and constructs
│   └── test/          # Infrastructure tests
├── src/
│   ├── frontend/      # React/Next.js application
│   ├── backend/       # Lambda functions and APIs
│   └── shared/        # Shared types and utilities
├── .github/
│   └── workflows/     # GitHub Actions CI/CD
└── docs/              # Documentation

```

## Prerequisites

- Node.js 20+
- AWS CLI configured
- AWS CDK installed (`npm install -g aws-cdk`)

## Getting Started

1. **Install dependencies:**
   ```bash
   npm install
   ```

2. **Deploy to dev:**
   ```bash
   export ENV=dev
   npm run cdk deploy -- --all
   ```

## Development Workflow

- **Feature branch** → Create PR → Auto-validate
- **Merge to `develop`** → Auto-deploy to dev
- **Merge to `main`** → Auto-deploy to staging
- **Manual trigger** → Deploy to prod (requires approval)

## Account IDs

See `CICD_SETUP_SUMMARY.md` for account details.

## Commands

```bash
npm run build          # Compile TypeScript
npm run test           # Run tests
npm run cdk synth      # Synthesize CloudFormation
npm run cdk diff       # Compare deployed stack with current state
npm run cdk deploy     # Deploy stack to AWS
```

## Documentation

See `docs/` directory for detailed documentation.
