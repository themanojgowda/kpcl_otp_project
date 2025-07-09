#!/bin/bash

# KPCL Automation - Custom Domain Deployment Script
# This script deploys the KPCL automation system to AWS with your custom domain

set -e

echo "🚀 KPCL Automation - Custom Domain Deployment"
echo "=============================================="

# Configuration
read -p "Enter your domain name (e.g., kpcl.yourdomain.com): " DOMAIN_NAME
read -p "Enter your ACM Certificate ARN (optional): " CERTIFICATE_ARN
read -p "Enter AWS Region [ap-south-1]: " AWS_REGION
AWS_REGION=${AWS_REGION:-ap-south-1}

read -p "Enter S3 bucket name for deployment [kpcl-automation-deployment]: " S3_BUCKET
S3_BUCKET=${S3_BUCKET:-kpcl-automation-deployment}

echo ""
echo "📋 Deployment Configuration:"
echo "   Domain: $DOMAIN_NAME"
echo "   Certificate: ${CERTIFICATE_ARN:-Not provided}"
echo "   Region: $AWS_REGION"
echo "   S3 Bucket: $S3_BUCKET"
echo ""

read -p "Continue with deployment? (y/N): " CONFIRM
if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

echo ""
echo "🔧 Step 1: Preparing deployment package..."

# Create deployment directory
rm -rf deployment
mkdir -p deployment
cd deployment

# Copy application files
cp -r ../templates ./ 2>/dev/null || echo "No templates directory found"
cp -r ../static ./ 2>/dev/null || echo "No static directory found"
cp ../*.py ./
cp ../requirements.txt ./
cp ../users.json.example ./users.json

# Install dependencies for Lambda
echo "Installing Python dependencies..."
pip install -r requirements.txt -t ./
pip install serverless-wsgi -t ./

# Create optimized Lambda handler
cat > lambda_handler.py << 'EOF'
import json
import os
import asyncio
import logging
from datetime import datetime
import boto3
from botocore.exceptions import ClientError

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """AWS Lambda handler for KPCL OTP Automation"""
    
    # Handle scheduled CloudWatch event
    if event.get('source') == 'aws.events':
        return handle_scheduled_task(event, context)
    
    # Handle web requests via API Gateway
    return handle_web_request(event, context)

def handle_scheduled_task(event, context):
    """Handle scheduled form submission at 6:59:59 AM IST"""
    try:
        logger.info("Starting scheduled KPCL form submission...")
        
        # Load user configuration from AWS Secrets Manager
        users = load_user_config()
        if not users:
            logger.error("No user configuration found")
            return {'statusCode': 500, 'body': json.dumps({'error': 'No user configuration'})}
        
        # Import and run the scheduler task
        from scheduler import post_gatepass
        
        results = []
        for user in users:
            try:
                logger.info(f"Processing user: {user.get('username', 'unknown')}")
                result = asyncio.run(post_gatepass(user))
                results.append({'username': user.get('username'), 'success': True, 'result': result})
                logger.info(f"Successfully processed user: {user.get('username')}")
            except Exception as e:
                error_msg = str(e)
                logger.error(f"Failed to process user {user.get('username', 'unknown')}: {error_msg}")
                results.append({'username': user.get('username'), 'success': False, 'error': error_msg})
        
        # Send notification
        send_notification(results)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Scheduled task completed',
                'timestamp': datetime.now().isoformat(),
                'results': results
            })
        }
        
    except Exception as e:
        logger.error(f"Scheduled task failed: {str(e)}")
        send_error_notification(str(e))
        return {'statusCode': 500, 'body': json.dumps({'error': str(e)})}

def handle_web_request(event, context):
    """Handle web requests through API Gateway"""
    try:
        # Use serverless-wsgi for Flask integration
        import serverless_wsgi
        from app import app
        
        # Configure Flask for Lambda
        app.config['SECRET_KEY'] = os.environ.get('FLASK_SECRET_KEY', 'lambda-secret-key')
        
        return serverless_wsgi.handle_request(app, event, context)
        
    except ImportError:
        # Fallback without serverless-wsgi
        path = event.get('path', '/')
        
        if path == '/' or path == '/index.html':
            return serve_index_page()
        elif path == '/status':
            return serve_status_page()
        else:
            return {'statusCode': 404, 'body': 'Not Found'}

def serve_index_page():
    """Serve the main login page"""
    try:
        with open('templates/index.html', 'r') as f:
            html_content = f.read()
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'text/html', 'Cache-Control': 'no-cache'},
            'body': html_content
        }
    except FileNotFoundError:
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'text/html'},
            'body': '''<!DOCTYPE html>
<html><head><title>KPCL Login</title></head>
<body><h1>🚀 KPCL OTP Automation</h1>
<p>System is running on AWS Lambda!</p>
<p><a href="/status">Check Status</a></p></body></html>'''
        }

def serve_status_page():
    """Serve the status endpoint"""
    return {
        'statusCode': 200,
        'headers': {'Content-Type': 'application/json'},
        'body': json.dumps({
            'status': 'healthy',
            'service': 'KPCL OTP Automation',
            'version': '1.0.0',
            'environment': 'AWS Lambda',
            'timestamp': datetime.now().isoformat(),
            'next_run': 'Daily at 6:59:59 AM IST'
        })
    }

def load_user_config():
    """Load user configuration from AWS Secrets Manager"""
    try:
        secrets_client = boto3.client('secretsmanager')
        secret_name = os.environ.get('USER_CONFIG_SECRET')
        if not secret_name:
            return None
        response = secrets_client.get_secret_value(SecretId=secret_name)
        return json.loads(response['SecretString'])
    except Exception as e:
        logger.error(f"Failed to load user configuration: {str(e)}")
        return None

def send_notification(results):
    """Send notification about task execution"""
    try:
        sns_topic_arn = os.environ.get('SNS_TOPIC_ARN')
        if not sns_topic_arn:
            return
        sns_client = boto3.client('sns')
        success_count = sum(1 for r in results if r.get('success'))
        sns_client.publish(
            TopicArn=sns_topic_arn,
            Subject=f"KPCL Automation Report - {success_count}/{len(results)} successful",
            Message=f"Execution Time: {datetime.now().isoformat()}\n\nResults:\n{json.dumps(results, indent=2)}"
        )
    except Exception as e:
        logger.error(f"Failed to send notification: {str(e)}")

def send_error_notification(error_msg):
    """Send error notification"""
    try:
        sns_topic_arn = os.environ.get('SNS_TOPIC_ARN')
        if not sns_topic_arn:
            return
        sns_client = boto3.client('sns')
        sns_client.publish(
            TopicArn=sns_topic_arn,
            Subject="KPCL Automation - ERROR",
            Message=f"Error: {error_msg}\nTime: {datetime.now().isoformat()}"
        )
    except Exception as e:
        logger.error(f"Failed to send error notification: {str(e)}")
EOF

# Create deployment package
echo "Creating deployment package..."
zip -r ../kpcl-automation.zip . -x "*.git*" "*.pyc" "__pycache__/*"

cd ..

echo ""
echo "☁️ Step 2: Uploading to AWS..."

# Create S3 bucket if it doesn't exist
echo "Creating S3 bucket: $S3_BUCKET"
aws s3 mb s3://$S3_BUCKET --region $AWS_REGION 2>/dev/null || echo "Bucket already exists"

# Upload deployment package
echo "Uploading deployment package..."
aws s3 cp kpcl-automation.zip s3://$S3_BUCKET/kpcl-automation.zip

echo ""
echo "🏗️ Step 3: Deploying CloudFormation stack..."

# Build CloudFormation parameters
CF_PARAMS="LambdaCodeBucket=$S3_BUCKET LambdaCodeKey=kpcl-automation.zip"

if [[ -n "$DOMAIN_NAME" ]]; then
    CF_PARAMS="$CF_PARAMS DomainName=$DOMAIN_NAME"
fi

if [[ -n "$CERTIFICATE_ARN" ]]; then
    CF_PARAMS="$CF_PARAMS CertificateArn=$CERTIFICATE_ARN"
fi

# Deploy CloudFormation stack
aws cloudformation deploy \
    --template-file aws/cloudformation.yml \
    --stack-name kpcl-automation \
    --parameter-overrides $CF_PARAMS \
    --capabilities CAPABILITY_IAM \
    --region $AWS_REGION

echo ""
echo "📋 Step 4: Getting deployment information..."

# Get stack outputs
API_URL=$(aws cloudformation describe-stacks \
    --stack-name kpcl-automation \
    --region $AWS_REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`ApiGatewayUrl`].OutputValue' \
    --output text)

CLOUDFRONT_URL=$(aws cloudformation describe-stacks \
    --stack-name kpcl-automation \
    --region $AWS_REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`CloudFrontDomainName`].OutputValue' \
    --output text 2>/dev/null || echo "Not configured")

echo ""
echo "✅ Deployment completed successfully!"
echo "=================================="
echo ""
echo "🌐 Your KPCL Automation System is now live:"
echo ""

if [[ -n "$DOMAIN_NAME" ]]; then
    echo "   🏠 Primary URL: https://$DOMAIN_NAME"
    echo "   📡 API Gateway: $API_URL"
    echo "   🚀 CloudFront: https://$CLOUDFRONT_URL"
else
    echo "   📡 API Gateway URL: $API_URL"
fi

echo ""
echo "⏰ Scheduled Execution: Daily at 6:59:59 AM IST"
echo "🕕 User Login Window: 6:45-6:55 AM IST"
echo ""
echo "📋 Next Steps:"
echo "   1. Update your DNS to point $DOMAIN_NAME to CloudFront"
echo "   2. Update users.json in AWS Secrets Manager with real session data"
echo "   3. Test the login flow between 6:45-6:55 AM"
echo "   4. Monitor execution in CloudWatch Logs"
echo ""
echo "📊 Monitoring:"
echo "   - CloudWatch Logs: https://console.aws.amazon.com/cloudwatch/home?region=$AWS_REGION"
echo "   - Lambda Function: https://console.aws.amazon.com/lambda/home?region=$AWS_REGION"
echo ""

# Test the deployment
echo "🧪 Testing deployment..."
curl -f "$API_URL/status" > /dev/null 2>&1 && echo "✅ Health check passed" || echo "❌ Health check failed"

echo ""
echo "🎉 Deployment complete! Your KPCL automation system is ready!"

# Cleanup
rm -rf deployment kpcl-automation.zip
