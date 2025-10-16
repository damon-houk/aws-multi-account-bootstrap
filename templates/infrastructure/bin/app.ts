#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';

const app = new cdk.App();

const projectCode = app.node.tryGetContext('projectCode') || 'E2E';
const env = process.env.ENV || 'dev';

// TODO: Import and instantiate your stacks here
// Example:
// import { InfrastructureStack } from '../lib/infrastructure-stack';
// new InfrastructureStack(app, `${projectCode}-${env}-Infrastructure`, {
//   env: {
//     account: process.env.CDK_DEFAULT_ACCOUNT,
//     region: process.env.CDK_DEFAULT_REGION || 'us-east-1',
//   },
//   tags: {
//     Project: projectCode,
//     Environment: env,
//   },
// });

app.synth();
