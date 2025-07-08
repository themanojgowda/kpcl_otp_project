# Deployment Guide - AWS

This guide covers deploying the KPCL OTP Automation System on AWS with scheduled execution.

## 🏗️ Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   CloudFront    │    │   Application   │    │  CloudWatch     │
│   (Optional)    │───▶│  Load Balancer  │───▶│   Events        │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │                       │
                                ▼                       ▼
                       ┌─────────────────┐    ┌─────────────────┐
                       │   EC2/Lambda    │    │   Scheduler     │
                       │   Web App       │    │ (6:59:59 AM)    │
                       └─────────────────┘    └─────────────────┘
                                │                       │
                                ▼                       ▼
                       ┌─────────────────┐    ┌─────────────────┐
                       │   RDS/DynamoDB  │    │   SNS Alerts    │
                       │  (User Config)  │    │  (Notifications)│
                       └─────────────────┘    └─────────────────┘
```

## 🚀 Deployment Options

### Option 1: Lambda + API Gateway (Recommended)
**Best for**: Cost-effective, serverless, automatic scaling

**Pros**:
- Pay only for usage
- Automatic scaling
- No server management
- Built-in monitoring

**Cons**:
- 15-minute execution limit
- Cold start latency

### Option 2: EC2 + Application Load Balancer
**Best for**: Always-on web interface, complex requirements

**Pros**:
- Full control
- Always available
- No execution time limits

**Cons**:
- Higher costs
- Server management required

## 📦 Option 1: Lambda Deployment

### Step 1: Prepare Lambda Package

```bash
# Create deployment package
pip install -r requirements.txt -t lambda_package/
cp *.py lambda_package/
cp -r templates/ lambda_package/
cp users.json lambda_package/

# Create ZIP
cd lambda_package
zip -r ../kpcl-automation.zip .
```

### Step 2: Lambda Function

```python
# lambda_handler.py
import json
import os
from app import app
from scheduler import schedule_task
import asyncio

def lambda_handler(event, context):
    """AWS Lambda handler"""
    
    # Check if this is a scheduled event (from CloudWatch)
    if event.get('source') == 'aws.events':
        # This is the scheduled task
        try:
            asyncio.run(schedule_task())
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'Scheduled task completed successfully'
                })
            }
        except Exception as e:
            return {
                'statusCode': 500,
                'body': json.dumps({
                    'error': str(e)
                })
            }
    
    # This is a web request
    try:
        # Use serverless_wsgi to handle Flask app
        import serverless_wsgi
        return serverless_wsgi.handle_request(app, event, context)
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e)
            })
        }
```

### Step 3: CloudFormation Template

```yaml
# aws/cloudformation.yml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'KPCL OTP Automation System'

Parameters:
  LambdaCodeBucket:
    Type: String
    Description: S3 bucket containing Lambda code
  LambdaCodeKey:
    Type: String
    Description: S3 key for Lambda code ZIP

Resources:
  # Lambda Execution Role
  LambdaExecutionRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: lambda.amazonaws.com
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
        - arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole

  # Lambda Function
  KPCLAutomationFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: kpcl-otp-automation
      Runtime: python3.9
      Handler: lambda_handler.lambda_handler
      Code:
        S3Bucket: !Ref LambdaCodeBucket
        S3Key: !Ref LambdaCodeKey
      Role: !GetAtt LambdaExecutionRole.Arn
      Timeout: 300
      MemorySize: 512
      Environment:
        Variables:
          FLASK_ENV: production

  # API Gateway
  ApiGateway:
    Type: AWS::ApiGateway::RestApi
    Properties:
      Name: kpcl-automation-api
      Description: KPCL OTP Automation API

  ApiGatewayResource:
    Type: AWS::ApiGateway::Resource
    Properties:
      RestApiId: !Ref ApiGateway
      ParentId: !GetAtt ApiGateway.RootResourceId
      PathPart: '{proxy+}'

  ApiGatewayMethod:
    Type: AWS::ApiGateway::Method
    Properties:
      RestApiId: !Ref ApiGateway
      ResourceId: !Ref ApiGatewayResource
      HttpMethod: ANY
      AuthorizationType: NONE
      Integration:
        Type: AWS_PROXY
        IntegrationHttpMethod: POST
        Uri: !Sub 'arn:aws:apigateway:${AWS::Region}:lambda:path/2015-03-31/functions/${KPCLAutomationFunction.Arn}/invocations'

  # Lambda Permission for API Gateway
  ApiGatewayInvokePermission:
    Type: AWS::Lambda::Permission
    Properties:
      FunctionName: !Ref KPCLAutomationFunction
      Action: lambda:InvokeFunction
      Principal: apigateway.amazonaws.com
      SourceArn: !Sub '${ApiGateway}/*/*'

  # CloudWatch Event Rule for Scheduling
  ScheduleRule:
    Type: AWS::Events::Rule
    Properties:
      Description: 'Trigger KPCL automation at 6:59:59 AM IST daily'
      ScheduleExpression: 'cron(29 1 * * ? *)'  # 6:59:59 AM IST = 1:29:59 AM UTC
      State: ENABLED
      Targets:
        - Arn: !GetAtt KPCLAutomationFunction.Arn
          Id: KPCLScheduleTarget

  # Permission for CloudWatch Events
  SchedulePermission:
    Type: AWS::Lambda::Permission
    Properties:
      FunctionName: !Ref KPCLAutomationFunction
      Action: lambda:InvokeFunction
      Principal: events.amazonaws.com
      SourceArn: !GetAtt ScheduleRule.Arn

  # API Gateway Deployment
  ApiDeployment:
    Type: AWS::ApiGateway::Deployment
    DependsOn:
      - ApiGatewayMethod
    Properties:
      RestApiId: !Ref ApiGateway
      StageName: prod

  # CloudWatch Log Group
  LogGroup:
    Type: AWS::Logs::LogGroup
    Properties:
      LogGroupName: !Sub '/aws/lambda/${KPCLAutomationFunction}'
      RetentionInDays: 30

Outputs:
  ApiGatewayUrl:
    Description: 'API Gateway URL'
    Value: !Sub 'https://${ApiGateway}.execute-api.${AWS::Region}.amazonaws.com/prod'
    Export:
      Name: !Sub '${AWS::StackName}-ApiUrl'

  LambdaFunctionArn:
    Description: 'Lambda Function ARN'
    Value: !GetAtt KPCLAutomationFunction.Arn
    Export:
      Name: !Sub '${AWS::StackName}-LambdaArn'
```

### Step 4: Deployment Script

```bash
#!/bin/bash
# aws/deploy.sh

set -e

# Configuration
STACK_NAME="kpcl-automation"
REGION="ap-south-1"  # Mumbai region for India
S3_BUCKET="kpcl-automation-code-bucket"

echo "🚀 Deploying KPCL Automation to AWS..."

# Create S3 bucket if it doesn't exist
aws s3 mb s3://$S3_BUCKET --region $REGION 2>/dev/null || echo "Bucket already exists"

# Prepare Lambda package
echo "📦 Preparing Lambda package..."
rm -rf lambda_package kpcl-automation.zip
mkdir lambda_package

# Install dependencies
pip install -r requirements.txt -t lambda_package/

# Copy application files
cp *.py lambda_package/
cp -r templates/ lambda_package/ 2>/dev/null || echo "No templates directory"
cp users.json.example lambda_package/users.json

# Create Lambda handler
cat > lambda_package/lambda_handler.py << 'EOF'
import json
import os
import sys
import asyncio
from app import app
from scheduler import schedule_task

def lambda_handler(event, context):
    """AWS Lambda handler"""
    
    # Check if this is a scheduled event
    if event.get('source') == 'aws.events':
        try:
            # Run the scheduled task
            asyncio.run(schedule_task())
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'Scheduled task completed successfully',
                    'timestamp': context.aws_request_id
                })
            }
        except Exception as e:
            print(f"Error in scheduled task: {str(e)}")
            return {
                'statusCode': 500,
                'body': json.dumps({
                    'error': str(e),
                    'timestamp': context.aws_request_id
                })
            }
    
    # Handle web requests
    try:
        import serverless_wsgi
        return serverless_wsgi.handle_request(app, event, context)
    except ImportError:
        # Fallback for basic requests
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'text/html'},
            'body': '<h1>KPCL Automation System</h1><p>System is running!</p>'
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
EOF

# Add serverless_wsgi to requirements
echo "serverless_wsgi" >> lambda_package/requirements.txt

# Create ZIP package
cd lambda_package
zip -r ../kpcl-automation.zip .
cd ..

# Upload to S3
echo "📤 Uploading to S3..."
aws s3 cp kpcl-automation.zip s3://$S3_BUCKET/kpcl-automation.zip --region $REGION

# Deploy CloudFormation stack
echo "🏗️ Deploying CloudFormation stack..."
aws cloudformation deploy \
    --template-file aws/cloudformation.yml \
    --stack-name $STACK_NAME \
    --parameter-overrides \
        LambdaCodeBucket=$S3_BUCKET \
        LambdaCodeKey=kpcl-automation.zip \
    --capabilities CAPABILITY_IAM \
    --region $REGION

# Get outputs
echo "📋 Getting deployment information..."
API_URL=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`ApiGatewayUrl`].OutputValue' \
    --output text)

echo "✅ Deployment completed!"
echo "🌐 Web Interface: $API_URL"
echo "⏰ Scheduled for: 6:59:59 AM IST daily"
echo "📊 Monitor at: https://console.aws.amazon.com/lambda/home?region=$REGION#/functions/kpcl-otp-automation"

# Cleanup
rm -rf lambda_package kpcl-automation.zip
```

## 📊 Option 2: EC2 Deployment

### Step 1: EC2 User Data Script

```bash
#!/bin/bash
# ec2-user-data.sh

# Update system
yum update -y
yum install -y python3 python3-pip git nginx

# Create application user
useradd -m kpcl
cd /home/kpcl

# Clone repository
git clone https://github.com/yourusername/kpcl-otp-automation.git
cd kpcl-otp-automation

# Setup Python environment
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
pip install gunicorn

# Create systemd service for web app
cat > /etc/systemd/system/kpcl-web.service << 'EOF'
[Unit]
Description=KPCL OTP Automation Web App
After=network.target

[Service]
User=kpcl
Group=kpcl
WorkingDirectory=/home/kpcl/kpcl-otp-automation
Environment=PATH=/home/kpcl/kpcl-otp-automation/venv/bin
ExecStart=/home/kpcl/kpcl-otp-automation/venv/bin/gunicorn --workers 3 --bind 127.0.0.1:5000 app:app
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Create systemd service for scheduler
cat > /etc/systemd/system/kpcl-scheduler.service << 'EOF'
[Unit]
Description=KPCL OTP Automation Scheduler
After=network.target

[Service]
User=kpcl
Group=kpcl
WorkingDirectory=/home/kpcl/kpcl-otp-automation
Environment=PATH=/home/kpcl/kpcl-otp-automation/venv/bin
ExecStart=/home/kpcl/kpcl-otp-automation/venv/bin/python scheduler.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Configure Nginx
cat > /etc/nginx/conf.d/kpcl.conf << 'EOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Set permissions
chown -R kpcl:kpcl /home/kpcl/kpcl-otp-automation

# Enable and start services
systemctl enable nginx kpcl-web kpcl-scheduler
systemctl start nginx kpcl-web kpcl-scheduler
```

## 🔧 Configuration Management

### Environment Variables

```bash
# .env file for production
FLASK_ENV=production
FLASK_DEBUG=False
SECRET_KEY=your-secret-key-here
AWS_REGION=ap-south-1
LOG_LEVEL=INFO
```

### Secrets Management

```bash
# Store sensitive data in AWS Secrets Manager
aws secretsmanager create-secret \
    --name "kpcl-automation/users" \
    --description "User configuration for KPCL automation" \
    --secret-string file://users.json
```

## 📊 Monitoring & Alerts

### CloudWatch Alarms

```bash
# Create alarm for Lambda errors
aws cloudwatch put-metric-alarm \
    --alarm-name "KPCL-Lambda-Errors" \
    --alarm-description "KPCL Lambda function errors" \
    --metric-name Errors \
    --namespace AWS/Lambda \
    --statistic Sum \
    --period 300 \
    --threshold 1 \
    --comparison-operator GreaterThanOrEqualToThreshold \
    --dimensions Name=FunctionName,Value=kpcl-otp-automation \
    --evaluation-periods 1
```

### SNS Notifications

```bash
# Create SNS topic for alerts
aws sns create-topic --name kpcl-automation-alerts

# Subscribe to email notifications
aws sns subscribe \
    --topic-arn arn:aws:sns:ap-south-1:123456789012:kpcl-automation-alerts \
    --protocol email \
    --notification-endpoint your-email@example.com
```

## 🔐 Security Best Practices

1. **IAM Roles**: Use least privilege principle
2. **VPC**: Deploy in private subnets
3. **HTTPS**: Use SSL/TLS certificates
4. **Secrets**: Store credentials in AWS Secrets Manager
5. **Logging**: Enable CloudTrail and CloudWatch logging

## 💰 Cost Optimization

### Lambda Pricing (Estimated)
- Daily execution: ~$0.01/month
- Web requests: ~$0.10/month (100 requests/day)
- **Total**: ~$0.11/month

### EC2 Pricing (Estimated)
- t3.micro instance: ~$8.50/month
- Data transfer: ~$1.00/month
- **Total**: ~$9.50/month

## 🚀 Deployment Commands

```bash
# Quick deployment
chmod +x aws/deploy.sh
./aws/deploy.sh

# Manual CloudFormation
aws cloudformation create-stack \
    --stack-name kpcl-automation \
    --template-body file://aws/cloudformation.yml \
    --capabilities CAPABILITY_IAM
```

## 🔄 CI/CD Pipeline

See `.github/workflows/deploy.yml` for automated deployments via GitHub Actions.

---

**Next**: [API Documentation](API.md) | [Troubleshooting](TROUBLESHOOTING.md)
