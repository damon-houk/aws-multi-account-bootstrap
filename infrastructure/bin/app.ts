#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { ExampleStack } from '../lib/example-stack';

const app = new cdk.App();

// Get environment from ENV variable (set by Makefile/GitHub Actions)
const env = process.env.ENV || 'dev';
const projectCode = process.env.PROJECT_CODE || 'DEMO';

// Example stack - demonstrates the pattern users will follow
new ExampleStack(app, `${projectCode}-${env}-ExampleStack`, {
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT,
    region: process.env.CDK_DEFAULT_REGION || 'us-east-1',
  },
  tags: {
    Project: projectCode,
    Environment: env,
    ManagedBy: 'CDK',
  },
});

app.synth();
