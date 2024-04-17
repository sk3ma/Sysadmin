#!/bin/bash

# Set environment variables.
AWS_PROFILE="sandbox"
AWS_REGION="eu-west-1"

# Query EC2 instances.
echo "Listing EC2 instances:"
aws ec2 describe-instances --profile $AWS_PROFILE --region $AWS_REGION

# Query IAM users.
echo "Listing IAM users:"
aws iam list-users --profile $AWS_PROFILE

# List S3 buckets.
echo "Listing S3 buckets:"
aws s3 ls --profile $AWS_PROFILE

# Describe RDS instances.
echo "Describing RDS instances:"
aws rds describe-db-instances --profile $AWS_PROFILE --region $AWS_REGION

# Describe CloudWatch logs.
echo "Describing CloudWatch log groups:"
aws logs describe-log-groups --profile $AWS_PROFILE --region $AWS_REGION

# Describe CloudFormation stacks.
echo "Describing CloudFormation stacks:"
aws cloudformation describe-stacks --profile $AWS_PROFILE --region $AWS_REGION
