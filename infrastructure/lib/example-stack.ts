import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as iam from 'aws-cdk-lib/aws-iam';

/**
 * Example CDK Stack
 *
 * This is a sample stack to demonstrate the structure and patterns
 * users should follow when building their infrastructure.
 *
 * This stack is used for CI testing (cdk synth) to validate
 * the project structure without deploying actual resources.
 */
export class ExampleStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // Example: S3 bucket with standard security settings
    const bucket = new s3.Bucket(this, 'ExampleBucket', {
      encryption: s3.BucketEncryption.S3_MANAGED,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
      versioned: true,
    });

    // Example: IAM role for Lambda or other services
    const exampleRole = new iam.Role(this, 'ExampleRole', {
      assumedBy: new iam.ServicePrincipal('lambda.amazonaws.com'),
      description: 'Example role for demonstrating IAM patterns',
      managedPolicies: [
        iam.ManagedPolicy.fromAwsManagedPolicyName('service-role/AWSLambdaBasicExecutionRole'),
      ],
    });

    // Grant the role read access to the bucket
    bucket.grantRead(exampleRole);

    // Outputs
    new cdk.CfnOutput(this, 'BucketName', {
      value: bucket.bucketName,
      description: 'Name of the example S3 bucket',
    });

    new cdk.CfnOutput(this, 'RoleArn', {
      value: exampleRole.roleArn,
      description: 'ARN of the example IAM role',
    });
  }
}