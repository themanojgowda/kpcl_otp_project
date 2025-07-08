# 🚀 Complete Deployment Guide

## Overview

This guide will help you deploy your KPCL OTP Automation System to:
1. **GitHub Repository** - Source code hosting
2. **GitHub Pages** - Live webpage for user access
3. **AWS Lambda + API Gateway** - Serverless backend with precise scheduling

## 📋 Prerequisites

1. **GitHub Account** - Create at https://github.com
2. **AWS Account** - Create at https://aws.amazon.com
3. **Git** - Install from https://git-scm.com
4. **AWS CLI** - Install from https://aws.amazon.com/cli
5. **Python 3.9+** - Install from https://python.org

## 🎯 Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   GitHub Pages  │    │   API Gateway   │    │   CloudWatch    │
│   (Live Site)   │───▶│   (Web API)     │───▶│   Events        │
│  User Interface │    │                 │    │ (6:59:59 AM)    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │                       │
                                ▼                       ▼
                       ┌─────────────────┐    ┌─────────────────┐
                       │   Lambda        │    │   Secrets       │
                       │   Function      │───▶│   Manager       │
                       │ (Flask App)     │    │ (User Config)   │
                       └─────────────────┘    └─────────────────┘
```

## 🚀 Quick Deployment

### Option 1: Automated Script (Recommended)

**Windows:**
```bash
deploy_complete.bat
```

**Linux/macOS:**
```bash
chmod +x deploy_complete.sh
./deploy_complete.sh
```

The script will:
- ✅ Setup Git repository
- ✅ Create GitHub project structure
- ✅ Deploy AWS infrastructure
- ✅ Configure secrets management
- ✅ Provide next steps

### Option 2: Manual Deployment

#### Step 1: GitHub Setup

1. **Create Repository**
   ```bash
   # On GitHub.com, create new repository: kpcl-otp-automation
   git init
   git remote add origin https://github.com/YOUR_USERNAME/kpcl-otp-automation.git
   ```

2. **Push Code**
   ```bash
   git add .
   git commit -m "Initial commit: KPCL OTP Automation System"
   git push -u origin main
   ```

3. **Enable GitHub Pages**
   - Go to repository Settings → Pages
   - Select "GitHub Actions" as source
   - The `.github/workflows/github-pages.yml` will deploy automatically

#### Step 2: AWS Deployment

1. **Configure AWS CLI**
   ```bash
   aws configure
   # Enter your AWS Access Key ID, Secret Key, Region (ap-south-1), Output format (json)
   ```

2. **Create S3 Bucket**
   ```bash
   aws s3 mb s3://your-bucket-name --region ap-south-1
   ```

3. **Package and Deploy**
   ```bash
   # Package Lambda function
   pip install -r requirements.txt -t lambda-package/
   cp *.py lambda-package/
   cp -r templates lambda-package/
   cd lambda-package && zip -r ../kpcl-automation-lambda.zip . && cd ..
   
   # Upload to S3
   aws s3 cp kpcl-automation-lambda.zip s3://your-bucket-name/lambda/
   
   # Deploy CloudFormation stack
   aws cloudformation deploy \
     --template-file aws/cloudformation.yml \
     --stack-name kpcl-automation-stack \
     --parameter-overrides LambdaCodeBucket=your-bucket-name LambdaCodeKey=lambda/kpcl-automation-lambda.zip \
     --capabilities CAPABILITY_IAM \
     --region ap-south-1
   ```

4. **Setup User Configuration**
   ```bash
   # Create AWS Secret with your configuration
   aws secretsmanager create-secret \
     --name kpcl-user-config \
     --description "KPCL user configuration" \
     --secret-string file://user-config.json \
     --region ap-south-1
   ```

## 🔧 Configuration

### User Configuration (AWS Secrets Manager)

Create `user-config.json`:
```json
{
  "users": [
    {
      "username": "your_kpcl_username",
      "cookies": {
        "PHPSESSID": "your_session_id"
      },
      "user_form_data": {
        "ash_utilization": "Ash_based_Products",
        "pickup_time": "07.00AM - 08.00AM",
        "tps": "BTPS",
        "vehi_type": "16",
        "qty_fly_ash": "36",
        "vehicle_no1": "KA36C5418",
        "driver_mob_no1": "9740856523"
      }
    }
  ]
}
```

### GitHub Repository Secrets

Add these secrets in GitHub repository settings:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION` (ap-south-1)

## 📱 Daily Usage Workflow

### Morning Routine (6:45-6:55 AM)

1. **Access Live Website**
   - GitHub Pages: `https://YOUR_USERNAME.github.io/kpcl-otp-automation`
   - AWS API: `https://YOUR_API_ID.execute-api.ap-south-1.amazonaws.com/prod`

2. **Login Process**
   - Enter your password (username pre-filled)
   - Request OTP
   - Enter OTP to complete login
   - System automatically saves fresh session

3. **Automated Execution**
   - At exactly 6:59:59 AM, AWS Lambda triggers
   - Uses your fresh session to submit the form
   - Real-time form data + your specific overrides

### Update Session Cookie (Alternative Method)

If you prefer manual session management:
```bash
# Update AWS Secret with fresh PHPSESSID
aws secretsmanager update-secret \
  --secret-id kpcl-user-config \
  --secret-string '{"users":[{"username":"your_username","cookies":{"PHPSESSID":"fresh_session_id"},"user_form_data":{...}}]}' \
  --region ap-south-1
```

## 🎯 Deployment Verification

### 1. Test Local Development
```bash
python app.py
# Visit http://localhost:5000
```

### 2. Test AWS Deployment
```bash
# Test health endpoint
curl https://YOUR_API_ID.execute-api.ap-south-1.amazonaws.com/prod/status

# Test manual Lambda invocation
aws lambda invoke \
  --function-name kpcl-automation-stack-function \
  --payload '{"test": true}' \
  --region ap-south-1 \
  response.json
```

### 3. Test Scheduled Execution
```bash
# Trigger a test execution
aws lambda invoke \
  --function-name kpcl-automation-stack-function \
  --payload '{"source": "aws.events", "detail-type": "Scheduled Event"}' \
  --region ap-south-1 \
  response.json
```

## 📊 Monitoring & Logs

### CloudWatch Logs
```bash
# View Lambda logs
aws logs describe-log-groups --log-group-name-prefix /aws/lambda/kpcl-automation

# Get recent logs
aws logs filter-log-events \
  --log-group-name /aws/lambda/kpcl-automation-stack-function \
  --start-time $(date -d '1 hour ago' +%s)000
```

### Health Monitoring
- **Status Endpoint**: `GET /status`
- **GitHub Pages Health**: Check deployment status
- **AWS Lambda Metrics**: CloudWatch dashboard

## 🚨 Troubleshooting

### Common Issues

1. **"Invalid Session" Errors**
   - Solution: Login via web interface to refresh PHPSESSID
   - Or manually update AWS Secret

2. **AWS Permission Errors**
   - Check IAM roles and policies
   - Verify AWS CLI configuration

3. **GitHub Pages Not Updating**
   - Check GitHub Actions workflow status
   - Verify Pages settings in repository

4. **Lambda Timeout Issues**
   - Increase timeout in CloudFormation template
   - Check network connectivity to KPCL website

### Support Commands

```bash
# Check AWS credentials
aws sts get-caller-identity

# Test AWS Secret access
aws secretsmanager get-secret-value --secret-id kpcl-user-config

# View CloudFormation stack status
aws cloudformation describe-stacks --stack-name kpcl-automation-stack

# Test GitHub Pages deployment
curl https://YOUR_USERNAME.github.io/kpcl-otp-automation
```

## 🔒 Security Best Practices

1. **Rotate Session Cookies Daily** - Use web interface login
2. **Limit AWS Permissions** - Use least privilege principle
3. **Monitor Access Logs** - Review CloudWatch logs regularly
4. **Secure Secrets** - Never commit sensitive data to Git
5. **Use HTTPS Only** - All endpoints use SSL/TLS

## 📈 Scaling & Optimization

### Performance Optimization
- Lambda memory: 512MB (adjustable)
- Timeout: 5 minutes
- Concurrent executions: Limited to prevent rate limiting

### Cost Optimization
- Lambda free tier: 1M requests/month
- API Gateway free tier: 1M requests/month
- CloudWatch Logs: Pay per GB ingested

## 🎉 Success Metrics

After deployment, you should have:
- ✅ Live website accessible 24/7
- ✅ Automated daily execution at 6:59:59 AM
- ✅ Fresh session management via web login
- ✅ Real-time form data fetching
- ✅ Error monitoring and alerting
- ✅ Secure configuration management

## 📞 Support

If you encounter issues:
1. Check the troubleshooting section
2. Review CloudWatch logs
3. Test individual components
4. Verify all prerequisites are met

---

**🎯 Goal Achieved**: Your KPCL automation now runs live on the web with precise AWS scheduling at 6:59:59.99 AM daily!
