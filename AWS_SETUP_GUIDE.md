# 🔐 AWS Credentials Setup Guide

## Quick Setup Steps

### 1. Get AWS Credentials
If you don't have AWS credentials yet:

```bash
# Install AWS CLI (if not already installed)
curl "https://awscli.amazonaws.com/awscli-exe-windows-x86_64.msi" -o "AWSCLIV2.msi"
msiexec /i AWSCLIV2.msi

# Configure AWS credentials
aws configure
```

Enter:
- **AWS Access Key ID**: Your AWS access key
- **AWS Secret Access Key**: Your secret key  
- **Default region**: `ap-south-1` (Mumbai)
- **Default output format**: `json`

### 2. Test AWS Connection
```bash
aws sts get-caller-identity
```

### 3. Setup GitHub Secrets

#### Option A: Via GitHub Web Interface
1. Go to: https://github.com/YOUR_USERNAME/YOUR_REPO/settings/secrets/actions
2. Click "New repository secret"
3. Add these secrets:
   - **Name**: `AWS_ACCESS_KEY_ID` | **Value**: Your AWS access key
   - **Name**: `AWS_SECRET_ACCESS_KEY` | **Value**: Your AWS secret key

#### Option B: Via GitHub CLI (if installed)
```bash
# Install GitHub CLI first
winget install GitHub.cli

# Login and set secrets
gh auth login
gh secret set AWS_ACCESS_KEY_ID --body "YOUR_ACCESS_KEY"
gh secret set AWS_SECRET_ACCESS_KEY --body "YOUR_SECRET_KEY"
```

## 4. Verify Setup

### Test Local Deployment
```bash
# Test if AWS credentials work locally
aws cloudformation list-stacks --region ap-south-1

# Test form fetcher
python test_form_fetcher.py

# Test full system
python validate_hybrid.py
```

### Test GitHub Actions
```bash
# Push to trigger deployment
git add .
git commit -m "feat: setup AWS credentials and test deployment"
git push origin main
```

## 5. Required AWS Permissions

Your AWS user needs these permissions:
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "cloudformation:*",
                "lambda:*",
                "apigateway:*",
                "s3:*",
                "iam:*",
                "secretsmanager:*",
                "events:*",
                "logs:*"
            ],
            "Resource": "*"
        }
    ]
}
```

## 6. Update Session Cookies

**CRITICAL**: Update `users.json` with valid session cookies:

1. **Login to KPCL AMS**: https://kpcl-ams.com
2. **Open Developer Tools** (F12)
3. **Go to Application/Storage → Cookies**
4. **Copy PHPSESSID value**
5. **Update users.json**:
   ```json
   {
     "cookies": {
       "PHPSESSID": "PASTE_REAL_SESSION_ID_HERE"
     }
   }
   ```

## 7. Deployment Commands

### Quick Deploy (Local)
```bash
# Deploy to AWS from local machine
./deploy_complete.sh

# Or on Windows
./deploy_complete.bat
```

### Custom Domain Deploy
```bash
# With your own domain
./deploy_custom_domain.sh

# Follow prompts for domain and SSL certificate
```

## 8. Monitor Deployment

After deployment, check:
- **Lambda Function**: AWS Console → Lambda → kpcl-automation-function
- **API Gateway**: Test the /status endpoint
- **CloudWatch Logs**: Monitor execution logs
- **Scheduled Events**: Verify 6:59 AM IST trigger

## 9. Troubleshooting

### Common Issues:
- **403 Forbidden**: Check AWS permissions
- **Invalid Session**: Update PHPSESSID in users.json
- **Timeout**: Check network connectivity
- **Build Failed**: Verify requirements.txt dependencies

### Debug Commands:
```bash
# Check AWS credentials
aws sts get-caller-identity

# Test form fetcher locally
python form_fetcher.py

# Validate configuration
python validate_hybrid.py

# Check GitHub Actions logs
gh run list
gh run view WORKFLOW_ID
```

## ✅ Ready to Deploy!

Once you have:
1. ✅ Valid AWS credentials in GitHub secrets
2. ✅ Updated PHPSESSID in users.json  
3. ✅ Tested form fetcher locally

Run: `git push origin main` to trigger automated deployment! 🚀
