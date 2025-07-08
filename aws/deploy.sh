#!/bin/bash
# AWS Deployment Script for KPCL Automation

set -e

# Configuration
STACK_NAME="kpcl-automation"
REGION="ap-south-1"  # Mumbai region for India
S3_BUCKET="kpcl-automation-code-$(date +%s)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Deploying KPCL Automation to AWS...${NC}"

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ AWS CLI not found. Please install AWS CLI first.${NC}"
    exit 1
fi

# Check if AWS is configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}❌ AWS CLI not configured. Please run 'aws configure' first.${NC}"
    exit 1
fi

# Create S3 bucket for code
echo -e "${YELLOW}📦 Creating S3 bucket for deployment...${NC}"
aws s3 mb s3://$S3_BUCKET --region $REGION 2>/dev/null || echo "Bucket creation skipped"

# Prepare Lambda package
echo -e "${YELLOW}📦 Preparing Lambda deployment package...${NC}"
rm -rf lambda_package kpcl-automation.zip
mkdir lambda_package

# Install dependencies
echo -e "${YELLOW}   Installing Python dependencies...${NC}"
pip install -r requirements.txt -t lambda_package/ --quiet

# Copy application files
echo -e "${YELLOW}   Copying application files...${NC}"
cp *.py lambda_package/
cp -r templates/ lambda_package/ 2>/dev/null || echo "   No templates directory found"
cp users.json.example lambda_package/users.json

# Create optimized Lambda handler
cat > lambda_package/lambda_handler.py << 'EOF'
import json
import os
import sys
import asyncio
import boto3
from botocore.exceptions import ClientError

# Import application modules
try:
    from app import app
    from scheduler import schedule_task
    from form_fetcher import fetch_form_data_sync, KPCLFormFetcher
except ImportError as e:
    print(f"Import error: {e}")
    app = None

def get_user_config():
    """Get user configuration from AWS Secrets Manager"""
    try:
        secret_name = os.environ.get('USER_CONFIG_SECRET')
        if not secret_name:
            # Fallback to local file
            import json
            with open('users.json', 'r') as f:
                return json.load(f)
        
        client = boto3.client('secretsmanager')
        response = client.get_secret_value(SecretId=secret_name)
        return json.loads(response['SecretString'])
    except Exception as e:
        print(f"Error getting user config: {e}")
        return []

def lambda_handler(event, context):
    """AWS Lambda handler"""
    
    # Add current directory to path
    sys.path.insert(0, os.path.dirname(__file__))
    
    print(f"Event: {json.dumps(event, default=str)}")
    
    # Check if this is a scheduled event from CloudWatch
    if event.get('source') == 'aws.events':
        try:
            print("🕐 Executing scheduled task...")
            
            # Get user configuration
            users = get_user_config()
            if not users:
                return {
                    'statusCode': 500,
                    'body': json.dumps({'error': 'No user configuration found'})
                }
            
            # Run the scheduled task
            import asyncio
            from scheduler import post_all_users
            
            # Override global USERS variable
            import scheduler
            scheduler.USERS = users
            
            # Execute the task
            asyncio.run(post_all_users())
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'Scheduled task completed successfully',
                    'timestamp': context.aws_request_id,
                    'users_processed': len(users)
                })
            }
        except Exception as e:
            print(f"Error in scheduled task: {str(e)}")
            import traceback
            traceback.print_exc()
            return {
                'statusCode': 500,
                'body': json.dumps({
                    'error': str(e),
                    'timestamp': context.aws_request_id
                })
            }
    
    # Handle web requests
    try:
        if not app:
            return {
                'statusCode': 200,
                'headers': {'Content-Type': 'text/html'},
                'body': '''
                <html>
                <head><title>KPCL Automation System</title></head>
                <body style="font-family: Arial, sans-serif; text-align: center; margin: 50px;">
                    <h1>🚀 KPCL Automation System</h1>
                    <p>System is running on AWS Lambda!</p>
                    <p>Scheduled execution: <strong>6:59:59 AM IST daily</strong></p>
                    <p>Status: <span style="color: green;">✅ Active</span></p>
                </body>
                </html>
                '''
            }
        
        # Try to use serverless_wsgi for full Flask support
        try:
            import serverless_wsgi
            return serverless_wsgi.handle_request(app, event, context)
        except ImportError:
            # Fallback to basic routing
            path = event.get('path', '/')
            method = event.get('httpMethod', 'GET')
            
            if path == '/status':
                return {
                    'statusCode': 200,
                    'headers': {'Content-Type': 'application/json'},
                    'body': json.dumps({
                        'status': 'healthy',
                        'service': 'KPCL Automation',
                        'timestamp': context.aws_request_id
                    })
                }
            
            # Default response
            return {
                'statusCode': 200,
                'headers': {'Content-Type': 'text/html'},
                'body': '''
                <html>
                <head><title>KPCL Automation</title></head>
                <body style="font-family: Arial, sans-serif; margin: 20px;">
                    <h1>KPCL Automation System</h1>
                    <p>Welcome to the KPCL OTP Automation System!</p>
                    <p><strong>Scheduled execution:</strong> 6:59:59 AM IST daily</p>
                    <p><strong>Login window:</strong> 6:45-6:55 AM IST</p>
                    <p><a href="/status">Check Status</a></p>
                </body>
                </html>
                '''
            }
            
    except Exception as e:
        print(f"Error handling web request: {str(e)}")
        import traceback
        traceback.print_exc()
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': str(e)})
        }
EOF

# Add serverless dependencies
echo "serverless_wsgi" >> lambda_package/requirements.txt
echo "boto3" >> lambda_package/requirements.txt

# Create ZIP package
echo -e "${YELLOW}   Creating deployment package...${NC}"
cd lambda_package
zip -r ../kpcl-automation.zip . --quiet
cd ..

# Upload to S3
echo -e "${YELLOW}📤 Uploading deployment package to S3...${NC}"
aws s3 cp kpcl-automation.zip s3://$S3_BUCKET/kpcl-automation.zip --region $REGION

# Check if CloudFormation template exists
if [ ! -f "aws/cloudformation.yml" ]; then
    echo -e "${RED}❌ CloudFormation template not found at aws/cloudformation.yml${NC}"
    exit 1
fi

# Deploy CloudFormation stack
echo -e "${YELLOW}🏗️ Deploying CloudFormation stack...${NC}"
aws cloudformation deploy \
    --template-file aws/cloudformation.yml \
    --stack-name $STACK_NAME \
    --parameter-overrides \
        LambdaCodeBucket=$S3_BUCKET \
        LambdaCodeKey=kpcl-automation.zip \
    --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
    --region $REGION

# Check deployment status
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ CloudFormation deployment successful!${NC}"
else
    echo -e "${RED}❌ CloudFormation deployment failed!${NC}"
    exit 1
fi

# Get deployment outputs
echo -e "${YELLOW}📋 Getting deployment information...${NC}"
API_URL=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`ApiGatewayUrl`].OutputValue' \
    --output text 2>/dev/null)

LAMBDA_ARN=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`LambdaFunctionArn`].OutputValue' \
    --output text 2>/dev/null)

SECRET_ARN=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`UserConfigSecret`].OutputValue' \
    --output text 2>/dev/null)

# Test the deployment
echo -e "${YELLOW}🧪 Testing deployment...${NC}"
if [ ! -z "$API_URL" ]; then
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/status" || echo "000")
    if [ "$HTTP_STATUS" = "200" ]; then
        echo -e "${GREEN}✅ API Gateway health check passed${NC}"
    else
        echo -e "${YELLOW}⚠️ API Gateway returned status: $HTTP_STATUS${NC}"
    fi
fi

# Display deployment summary
echo ""
echo -e "${GREEN}🎉 Deployment completed successfully!${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}📊 Deployment Summary:${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "🌐 ${YELLOW}Web Interface:${NC} $API_URL"
echo -e "⏰ ${YELLOW}Schedule:${NC} 6:59:59 AM IST daily (1:29:59 AM UTC)"
echo -e "👥 ${YELLOW}Login Window:${NC} 6:45-6:55 AM IST"
echo -e "🔧 ${YELLOW}Lambda Function:${NC} $LAMBDA_ARN"
echo -e "🔐 ${YELLOW}User Config Secret:${NC} $SECRET_ARN"
echo ""
echo -e "${BLUE}📝 Next Steps:${NC}"
echo -e "1. Update user configuration in AWS Secrets Manager:"
echo -e "   ${YELLOW}aws secretsmanager update-secret --secret-id '$SECRET_ARN' --secret-string file://users.json${NC}"
echo ""
echo -e "2. Monitor execution in CloudWatch:"
echo -e "   ${YELLOW}https://console.aws.amazon.com/lambda/home?region=$REGION#/functions/kpcl-automation-function${NC}"
echo ""
echo -e "3. Set up SNS notifications (optional):"
echo -e "   ${YELLOW}aws sns subscribe --topic-arn [SNS-TOPIC-ARN] --protocol email --notification-endpoint your-email@example.com${NC}"
echo ""
echo -e "${GREEN}🎯 Your KPCL automation system is now live and scheduled!${NC}"

# Cleanup
echo -e "${YELLOW}🧹 Cleaning up temporary files...${NC}"
rm -rf lambda_package kpcl-automation.zip

echo -e "${GREEN}✨ Deployment complete!${NC}"
