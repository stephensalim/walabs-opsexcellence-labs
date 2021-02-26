#!/bin/bash

ENV_STACK_NAME=$1

# aws cloudformation create-stack --stack-name $ENV_STACK_NAME-VPC --template-body file://templates/base_vpc.yml --capabilities CAPABILITY_NAMED_IAM 
# aws cloudformation wait stack-create-complete --stack-name $ENV_STACK_NAME-VPC


cd app

BASE_STACK=$ENV_STACK_NAME-VPC
LABEL="v1"

ECR_REPONAME=$(aws cloudformation describe-stacks --stack-name $BASE_STACK --query 'Stacks[0].Outputs[?OutputKey==`OutputPattern1AppContainerRepository`].OutputValue |[0]' | sed 's/"//g')
STACK_ID=$(aws cloudformation describe-stacks --stack-name $BASE_STACK --query 'Stacks[0].StackId' | sed 's/"//g')

echo $ECR_REPONAME

IFS=':'
read -ra ADDR <<< "$STACK_ID" # str is read into an array as tokens separated by IFS

AWS_REGION=${ADDR[3]}
AWS_ACCOUNT=${ADDR[4]}
echo $AWS_REGION
echo $AWS_ACCOUNT

aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT.dkr.ecr.$AWS_REGION.amazonaws.com
docker build -t $ECR_REPONAME .
docker tag $ECR_REPONAME:latest $AWS_ACCOUNT.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPONAME:$LABEL
docker push $AWS_ACCOUNT.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPONAME:$LABEL

echo "==========================="
echo "Image URI:" $AWS_ACCOUNT.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPONAME:$LABEL

cd ..


aws cloudformation create-stack --stack-name $ENV_STACK_NAME-APPLICATION --template-body file://templates/base_app.yml --parameters ParameterKey=BaselineVpcStack,ParameterValue=$ENV_STACK_NAME-VPC ParameterKey=ECRImageURI,ParameterValue=$AWS_ACCOUNT.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPONAME:$LABEL --capabilities CAPABILITY_NAMED_IAM 
aws cloudformation wait stack-create-complete --stack-name $ENV_STACK_NAME-APPLICATION
