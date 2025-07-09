# 🚀 KPCL Automation - Complete Setup Guide

## Overview
This guide will help you deploy the KPCL OTP Automation system with your custom domain on AWS, providing:
- **Web Interface**: Users can login between 6:45-6:55 AM to refresh their session
- **Automated Submission**: System automatically submits forms at exactly 6:59:59 AM IST
- **Custom Domain**: Your website accessible via your own domain
- **AWS Deployment**: Scalable, serverless infrastructure

## Prerequisites

### 1. AWS Account Setup
- AWS Account with appropriate permissions
- AWS CLI installed and configured
- Domain name purchased and managed

### 2. SSL Certificate (Required for Custom Domain)
```bash
# Request ACM certificate for your domain
aws acm request-certificate \
  --domain-name "kpcl.yourdomain.com" \
  --subject-alternative-names "*.yourdomain.com" \
  --validation-method DNS \
  --region us-east-1
```
**Note**: SSL certificates for CloudFront must be in `us-east-1` region.

### 3. Domain Configuration
- Access to your domain's DNS settings
- Ability to create CNAME records

## 🎯 Deployment Options

### Option 1: Automated Deployment (Recommended)

#### For Windows:
```cmd
# Navigate to project directory
cd c:\Users\Manu\Downloads\KPCL\kpcl_otp_project

# Run deployment script
deploy_custom_domain.bat
```

#### For Linux/Mac:
```bash
# Navigate to project directory
cd /path/to/kpcl_otp_project

# Make script executable and run
chmod +x deploy_custom_domain.sh
./deploy_custom_domain.sh
```

The script will prompt you for:
- **Domain Name**: e.g., `kpcl.yourdomain.com`
- **Certificate ARN**: Your ACM certificate ARN
- **AWS Region**: Default is `ap-south-1`
- **S3 Bucket**: For deployment artifacts

### Option 2: GitHub Actions Deployment

1. **Push to GitHub**:
```bash
git add .
git commit -m "Deploy KPCL automation with custom domain"
git push origin main
```

2. **Manual Trigger with Custom Domain**:
- Go to GitHub Actions in your repository
- Click "Deploy KPCL Automation"
- Click "Run workflow"
- Enter your domain name and certificate ARN
- Click "Run workflow"

### Option 3: Manual AWS CLI Deployment

```bash
# 1. Create deployment package
mkdir deployment && cd deployment
cp -r ../templates ../static ../*.py ../requirements.txt ./
pip install -r requirements.txt -t ./
zip -r ../kpcl-automation.zip .
cd .. && rm -rf deployment

# 2. Upload to S3
aws s3 mb s3://your-deployment-bucket
aws s3 cp kpcl-automation.zip s3://your-deployment-bucket/

# 3. Deploy CloudFormation
aws cloudformation deploy \
  --template-file aws/cloudformation.yml \
  --stack-name kpcl-automation \
  --parameter-overrides \
    LambdaCodeBucket=your-deployment-bucket \
    LambdaCodeKey=kpcl-automation.zip \
    DomainName=kpcl.yourdomain.com \
    CertificateArn=arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012 \
  --capabilities CAPABILITY_IAM \
  --region ap-south-1
```

## 🌐 DNS Configuration

After deployment, you'll need to configure your DNS:

### 1. Get CloudFront Distribution Domain
```bash
aws cloudformation describe-stacks \
  --stack-name kpcl-automation \
  --query 'Stacks[0].Outputs[?OutputKey==`CloudFrontDomainName`].OutputValue' \
  --output text
```

### 2. Create DNS Records
In your domain provider's DNS settings:

```
Type: CNAME
Name: kpcl (or your subdomain)
Value: d123456789abcdef.cloudfront.net (your CloudFront domain)
TTL: 300
```

### 3. Verify DNS Propagation
```bash
nslookup kpcl.yourdomain.com
# Should return the CloudFront IP addresses
```

## 🔒 Security Configuration

### 1. Update User Configuration in AWS Secrets Manager

```bash
# Get the secret ARN
SECRET_ARN=$(aws cloudformation describe-stacks \
  --stack-name kpcl-automation \
  --query 'Stacks[0].Outputs[?OutputKey==`UserConfigSecretArn`].OutputValue' \
  --output text)

# Update with your real configuration
aws secretsmanager update-secret \
  --secret-id $SECRET_ARN \
  --secret-string '[
    {
      "username": "your_actual_username",
      "cookies": {
        "PHPSESSID": "update_with_real_session_after_login"
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
  ]'
```

### 2. Test the Configuration
```bash
# Test the Lambda function
aws lambda invoke \
  --function-name kpcl-automation-function \
  --payload '{"source": "manual_test"}' \
  response.json

cat response.json
```

## 📱 Daily Usage Workflow

### For Users (Daily at 6:45-6:55 AM IST):

1. **Visit Your Website**: 
   - Go to `https://kpcl.yourdomain.com`
   - System will show login interface

2. **Login Process**:
   - Username is pre-filled (1901981)
   - Enter your password
   - Click "Get OTP"
   - Enter the 6-digit OTP received on mobile
   - Click "Login & Activate Session"

3. **Session Activation**:
   - System will confirm successful login
   - Fresh session cookie is automatically stored
   - No further action required

4. **Automated Submission**:
   - At exactly 6:59:59 AM IST, system automatically submits your form
   - You'll receive notification if configured

## 📊 Monitoring & Troubleshooting

### 1. CloudWatch Logs
```bash
# View recent logs
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/kpcl-automation"

# Follow live logs
aws logs tail /aws/lambda/kpcl-automation-function --follow
```

### 2. Check System Status
```bash
curl https://kpcl.yourdomain.com/status
```

### 3. Manual Testing
```bash
# Test the scheduled function
aws lambda invoke \
  --function-name kpcl-automation-function \
  --payload '{"source": "aws.events"}' \
  test-response.json
```

### 4. Common Issues

**Issue**: SSL Certificate not working
**Solution**: Ensure certificate is in `us-east-1` region and validated

**Issue**: DNS not resolving
**Solution**: Check CNAME record and wait for propagation (up to 48 hours)

**Issue**: Login fails
**Solution**: Verify KPCL website is accessible and credentials are correct

**Issue**: Automated submission fails
**Solution**: Check CloudWatch logs and update session cookie

## 🔄 Updating Configuration

### Update Users Configuration:
```bash
# Edit users.json locally, then update secret
aws secretsmanager update-secret \
  --secret-id $(aws cloudformation describe-stacks --stack-name kpcl-automation --query 'Stacks[0].Outputs[?OutputKey==`UserConfigSecretArn`].OutputValue' --output text) \
  --secret-string file://users.json
```

### Update Application Code:
1. Make changes to your code
2. Commit and push to GitHub
3. GitHub Actions will automatically redeploy

## 🎉 Success Verification

Your deployment is successful when:

1. ✅ **Domain resolves**: `nslookup kpcl.yourdomain.com` returns CloudFront IPs
2. ✅ **Website loads**: Visit `https://kpcl.yourdomain.com` shows login page
3. ✅ **Status endpoint works**: `https://kpcl.yourdomain.com/status` returns JSON
4. ✅ **CloudWatch schedule exists**: Check CloudWatch Events rules
5. ✅ **Secrets Manager configured**: User configuration stored securely

## 📞 Support

### AWS Resources Created:
- **Lambda Function**: `kpcl-automation-function`
- **API Gateway**: REST API with custom domain
- **CloudFront Distribution**: CDN for your domain
- **CloudWatch Event Rule**: Daily schedule at 6:59:59 AM IST
- **Secrets Manager Secret**: User configuration storage
- **SNS Topic**: Optional notifications

### Monitoring URLs:
- **Lambda Console**: `https://console.aws.amazon.com/lambda/home?region=ap-south-1#/functions/kpcl-automation-function`
- **CloudWatch Logs**: `https://console.aws.amazon.com/cloudwatch/home?region=ap-south-1#logsV2:log-groups`
- **API Gateway**: `https://console.aws.amazon.com/apigateway/home?region=ap-south-1`

---

🎯 **Your KPCL automation system is now live on your custom domain with precise 6:59:59 AM scheduling!**
