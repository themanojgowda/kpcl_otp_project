#!/bin/bash

# KPCL Automation - Complete GitHub Pages + AWS Deployment Script

set -e  # Exit on any error

echo "🚀 KPCL Automation - Complete Deployment Setup"
echo "=============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check prerequisites
echo ""
print_info "Checking prerequisites..."

# Check if git is installed
if ! command -v git &> /dev/null; then
    print_error "Git is not installed. Please install Git first."
    exit 1
fi

# Check if aws cli is installed
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed. Please install AWS CLI first."
    exit 1
fi

# Check if python is installed
if ! command -v python3 &> /dev/null && ! command -v python &> /dev/null; then
    print_error "Python is not installed. Please install Python 3.9+ first."
    exit 1
fi

print_status "Prerequisites check passed!"

# Get user inputs
echo ""
print_info "Configuration Setup"
read -p "Enter your GitHub username: " GITHUB_USERNAME
read -p "Enter repository name (default: kpcl-otp-automation): " REPO_NAME
REPO_NAME=${REPO_NAME:-kpcl-otp-automation}

read -p "Enter AWS region (default: ap-south-1): " AWS_REGION
AWS_REGION=${AWS_REGION:-ap-south-1}

read -p "Enter AWS S3 bucket for deployment (will be created if not exists): " S3_BUCKET

echo ""
print_info "Summary:"
echo "GitHub: https://github.com/$GITHUB_USERNAME/$REPO_NAME"
echo "AWS Region: $AWS_REGION"
echo "S3 Bucket: $S3_BUCKET"
echo ""

read -p "Continue with deployment? (y/N): " CONFIRM
if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

# Step 1: Setup Git repository
echo ""
print_info "Step 1: Setting up Git repository..."

if [ ! -d ".git" ]; then
    git init
    print_status "Git repository initialized"
else
    print_status "Git repository already exists"
fi

# Create/update .gitignore
cat > .gitignore << 'EOF'
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg
MANIFEST

# Virtual Environment
venv/
env/
ENV/

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# App specific
sessions/
*.log

# AWS
aws-exports.js

# Sensitive data
users.json
.env
EOF

print_status ".gitignore created"

# Step 2: Prepare project structure
echo ""
print_info "Step 2: Preparing project structure..."

# Create docs directory
mkdir -p docs
if [ -f "DEPLOYMENT.md" ]; then
    cp DEPLOYMENT.md docs/
fi
if [ -f "HYBRID_APPROACH.md" ]; then
    cp HYBRID_APPROACH.md docs/
fi
if [ -f "IMPLEMENTATION_SUMMARY.md" ]; then
    cp IMPLEMENTATION_SUMMARY.md docs/
fi

print_status "Documentation moved to docs/ directory"

# Create tests directory if it doesn't exist
mkdir -p tests

# Create basic test file
cat > tests/test_basic.py << 'EOF'
import unittest
import sys
import os

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app import app

class TestBasicFunctionality(unittest.TestCase):
    def setUp(self):
        self.app = app.test_client()
        self.app.testing = True

    def test_index_page(self):
        response = self.app.get('/')
        self.assertEqual(response.status_code, 200)

    def test_status_endpoint(self):
        response = self.app.get('/status')
        self.assertEqual(response.status_code, 200)
        self.assertIn(b'healthy', response.data)

if __name__ == '__main__':
    unittest.main()
EOF

print_status "Test structure created"

# Create LICENSE
cat > LICENSE << 'EOF'
MIT License

Copyright (c) 2025 KPCL OTP Automation

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF

print_status "LICENSE created"

# Step 3: AWS Setup
echo ""
print_info "Step 3: Setting up AWS resources..."

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    print_error "AWS credentials not configured. Please run 'aws configure' first."
    exit 1
fi

print_status "AWS credentials verified"

# Create S3 bucket if it doesn't exist
if ! aws s3 ls "s3://$S3_BUCKET" &> /dev/null; then
    print_info "Creating S3 bucket: $S3_BUCKET"
    aws s3 mb "s3://$S3_BUCKET" --region "$AWS_REGION"
    print_status "S3 bucket created"
else
    print_status "S3 bucket already exists"
fi

# Step 4: Package Lambda function
echo ""
print_info "Step 4: Packaging Lambda function..."

# Create deployment package
rm -rf lambda-package
mkdir lambda-package

# Install dependencies in package directory
pip install -r requirements.txt -t lambda-package/

# Copy application files
cp *.py lambda-package/
cp -r templates lambda-package/
cp -r static lambda-package/ 2>/dev/null || true
cp users.json.example lambda-package/users.json.example

# Create deployment package
cd lambda-package
zip -r ../kpcl-automation-lambda.zip . -x "*.pyc" "__pycache__/*"
cd ..

print_status "Lambda package created"

# Upload to S3
aws s3 cp kpcl-automation-lambda.zip "s3://$S3_BUCKET/lambda/kpcl-automation-lambda.zip"
print_status "Lambda package uploaded to S3"

# Step 5: Deploy CloudFormation stack
echo ""
print_info "Step 5: Deploying AWS infrastructure..."

STACK_NAME="kpcl-automation-stack"

# Update CloudFormation template with actual values
sed -i.bak "s/YOUR_S3_BUCKET/$S3_BUCKET/g" aws/cloudformation.yml

# Deploy stack
aws cloudformation deploy \
    --template-file aws/cloudformation.yml \
    --stack-name $STACK_NAME \
    --parameter-overrides \
        LambdaCodeBucket=$S3_BUCKET \
        LambdaCodeKey=lambda/kpcl-automation-lambda.zip \
    --capabilities CAPABILITY_IAM \
    --region $AWS_REGION

if [ $? -eq 0 ]; then
    print_status "CloudFormation stack deployed successfully"
else
    print_error "CloudFormation deployment failed"
    exit 1
fi

# Get API Gateway URL
API_URL=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $AWS_REGION \
    --query "Stacks[0].Outputs[?OutputKey=='ApiGatewayUrl'].OutputValue" \
    --output text)

print_status "API Gateway URL: $API_URL"

# Step 6: Setup GitHub repository
echo ""
print_info "Step 6: Setting up GitHub repository..."

# Add all files to git
git add .
git commit -m "Initial commit: KPCL OTP Automation System

Features:
- Web interface for daily login (6:45-6:55 AM)
- Automated form submission at 6:59:59.99 AM
- AWS Lambda + API Gateway deployment
- Dynamic form data fetching with user overrides
- GitHub Pages integration
"

# Add GitHub remote (if not already added)
if ! git remote get-url origin &> /dev/null; then
    git remote add origin "https://github.com/$GITHUB_USERNAME/$REPO_NAME.git"
    print_status "GitHub remote added"
fi

print_warning "Ready to push to GitHub. Please ensure the repository exists on GitHub first."
echo ""
print_info "Run these commands to complete GitHub setup:"
echo "git push -u origin main"
echo ""
print_info "Then enable GitHub Pages in repository settings:"
echo "1. Go to https://github.com/$GITHUB_USERNAME/$REPO_NAME/settings/pages"
echo "2. Select 'GitHub Actions' as source"
echo "3. The workflow will automatically deploy your site"

# Step 7: Update users configuration in AWS Secrets
echo ""
print_info "Step 7: Setting up AWS Secrets Manager..."

SECRET_NAME="kpcl-user-config"

# Create a template secret (you'll need to update this with real data)
TEMPLATE_SECRET='{
  "users": [
    {
      "username": "your_username",
      "cookies": {
        "PHPSESSID": "your_session_id_here"
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
}'

if ! aws secretsmanager describe-secret --secret-id $SECRET_NAME --region $AWS_REGION &> /dev/null; then
    aws secretsmanager create-secret \
        --name $SECRET_NAME \
        --description "KPCL user configuration and session data" \
        --secret-string "$TEMPLATE_SECRET" \
        --region $AWS_REGION
    print_status "AWS Secret created with template data"
else
    print_status "AWS Secret already exists"
fi

# Step 8: Final instructions
echo ""
echo "🎉 Deployment Complete!"
echo "======================"
echo ""
print_info "Your KPCL Automation System is now deployed:"
echo ""
echo "📱 Web Application: $API_URL"
echo "📚 GitHub Repository: https://github.com/$GITHUB_USERNAME/$REPO_NAME"
echo "🌐 GitHub Pages: https://$GITHUB_USERNAME.github.io/$REPO_NAME (will be available after first push)"
echo "☁️  AWS Stack: $STACK_NAME (region: $AWS_REGION)"
echo ""
print_warning "Next Steps:"
echo "1. Push to GitHub: git push -u origin main"
echo "2. Enable GitHub Pages in repository settings"
echo "3. Update AWS Secret with your real PHPSESSID:"
echo "   aws secretsmanager update-secret --secret-id $SECRET_NAME --secret-string '{your_real_config}'"
echo "4. Test the application: curl $API_URL/status"
echo ""
print_info "Daily Workflow:"
echo "🕕 6:45-6:55 AM: Login via web interface to refresh session"
echo "🕕 6:59:59 AM: Automated form submission (AWS Lambda)"
echo ""
print_warning "Important: Update your PHPSESSID in AWS Secrets Manager every morning after login!"

echo ""
echo "Happy automating! 🚀"
