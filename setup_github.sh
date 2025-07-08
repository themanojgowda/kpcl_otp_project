#!/bin/bash
# GitHub Setup and Deployment Script

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 KPCL Automation - GitHub Setup & AWS Deployment${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"

# Check prerequisites
echo -e "${YELLOW}🔍 Checking prerequisites...${NC}"

# Check Git
if ! command -v git &> /dev/null; then
    echo -e "${RED}❌ Git not found. Please install Git first.${NC}"
    exit 1
fi

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ AWS CLI not found. Please install AWS CLI first.${NC}"
    exit 1
fi

# Check Python
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ Python 3 not found. Please install Python 3 first.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Prerequisites check passed${NC}"

# Get user inputs
echo ""
echo -e "${YELLOW}📝 Configuration Setup${NC}"
read -p "Enter your GitHub username: " GITHUB_USERNAME
read -p "Enter repository name (default: kpcl-otp-automation): " REPO_NAME
REPO_NAME=${REPO_NAME:-kpcl-otp-automation}

read -p "Enter AWS region (default: ap-south-1): " AWS_REGION
AWS_REGION=${AWS_REGION:-ap-south-1}

echo ""
echo -e "${YELLOW}🔧 Setting up project structure...${NC}"

# Initialize Git repository if not already
if [ ! -d ".git" ]; then
    git init
    echo -e "${GREEN}✅ Git repository initialized${NC}"
fi

# Create GitHub repository structure
echo -e "${YELLOW}📁 Creating GitHub project structure...${NC}"

# Copy README for GitHub
cp README_GITHUB.md README.md

# Create additional documentation
mkdir -p docs
mv DEPLOYMENT.md docs/
mv HYBRID_APPROACH.md docs/
mv IMPLEMENTATION_SUMMARY.md docs/

# Create tests directory
mkdir -p tests
cat > tests/test_basic.py << 'EOF'
import unittest
import sys
import os

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app import app
from form_fetcher import KPCLFormFetcher

class TestBasicFunctionality(unittest.TestCase):
    
    def setUp(self):
        self.app = app.test_client()
        self.app.testing = True
    
    def test_index_page(self):
        """Test that index page loads"""
        response = self.app.get('/')
        self.assertEqual(response.status_code, 200)
    
    def test_status_endpoint(self):
        """Test status endpoint"""
        response = self.app.get('/status')
        self.assertEqual(response.status_code, 200)
        self.assertIn(b'healthy', response.data)
    
    def test_form_fetcher_import(self):
        """Test that form fetcher can be imported"""
        self.assertTrue(hasattr(KPCLFormFetcher, 'fetch_gatepass_form_data'))

if __name__ == '__main__':
    unittest.main()
EOF

# Create a comprehensive license
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

# Add serverless_wsgi to requirements for Lambda
if ! grep -q "serverless_wsgi" requirements.txt; then
    echo "serverless_wsgi" >> requirements.txt
fi

# Make deploy script executable
chmod +x aws/deploy.sh

# Git configuration
echo -e "${YELLOW}📦 Preparing Git commit...${NC}"

# Add all files
git add .

# Check if there are changes to commit
if git diff --staged --quiet; then
    echo -e "${YELLOW}ℹ️ No changes to commit${NC}"
else
    # Commit changes
    git commit -m "Initial commit: KPCL OTP Automation System

Features:
- Hybrid dynamic form fetching
- User-specific field overrides
- AWS Lambda deployment ready
- Scheduled execution at 6:59:59 AM IST
- Multi-user support
- Comprehensive monitoring and logging"

    echo -e "${GREEN}✅ Changes committed to Git${NC}"
fi

# GitHub repository creation
echo ""
echo -e "${YELLOW}🐙 GitHub Repository Setup${NC}"
echo "Please follow these steps to create your GitHub repository:"
echo ""
echo "1. Go to https://github.com/new"
echo "2. Repository name: $REPO_NAME"
echo "3. Description: KPCL OTP Automation System with AWS deployment"
echo "4. Set to Public or Private as needed"
echo "5. Do NOT initialize with README (we already have one)"
echo "6. Click 'Create repository'"
echo ""
read -p "Press Enter after creating the GitHub repository..."

# Add remote origin
echo -e "${YELLOW}🔗 Adding GitHub remote...${NC}"
git remote remove origin 2>/dev/null || true
git remote add origin "https://github.com/$GITHUB_USERNAME/$REPO_NAME.git"

# Push to GitHub
echo -e "${YELLOW}📤 Pushing to GitHub...${NC}"
git branch -M main
git push -u origin main

echo -e "${GREEN}✅ Code pushed to GitHub successfully!${NC}"

# AWS Deployment
echo ""
echo -e "${YELLOW}☁️ AWS Deployment${NC}"
read -p "Do you want to deploy to AWS now? (y/N): " DEPLOY_NOW

if [[ $DEPLOY_NOW =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}🚀 Starting AWS deployment...${NC}"
    
    # Check AWS configuration
    if ! aws sts get-caller-identity &> /dev/null; then
        echo -e "${RED}❌ AWS CLI not configured. Please run 'aws configure' first.${NC}"
        echo "You'll need:"
        echo "- AWS Access Key ID"
        echo "- AWS Secret Access Key" 
        echo "- Default region: $AWS_REGION"
        exit 1
    fi
    
    # Run deployment
    ./aws/deploy.sh
    
    echo ""
    echo -e "${GREEN}🎉 AWS deployment completed!${NC}"
else
    echo -e "${YELLOW}ℹ️ Skipping AWS deployment${NC}"
    echo "To deploy later, run: ./aws/deploy.sh"
fi

# Final summary
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}🎯 Setup Complete!${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "🐙 ${YELLOW}GitHub Repository:${NC} https://github.com/$GITHUB_USERNAME/$REPO_NAME"
echo -e "📚 ${YELLOW}Documentation:${NC} Available in docs/ folder"
echo -e "🧪 ${YELLOW}Tests:${NC} Run with 'python -m pytest tests/'"
echo -e "🔧 ${YELLOW}Local Development:${NC} python app.py"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "1. 🔐 Update users.json with real session cookies"
echo "2. 🧪 Test locally: python app.py"
echo "3. ☁️ Deploy to AWS: ./aws/deploy.sh (if not done already)"
echo "4. 📊 Monitor in AWS CloudWatch"
echo "5. 🔔 Set up SNS notifications for alerts"
echo ""
echo -e "${GREEN}Your KPCL automation system is ready! 🚀${NC}"
