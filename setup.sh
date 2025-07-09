#!/bin/bash
# 🚀 Quick Setup Script for KPCL Automation

echo "🚀 KPCL Automation - Quick Setup"
echo "================================="

# Check if Python is installed
echo "🔍 Checking Python installation..."
if ! command -v python &> /dev/null; then
    echo "❌ Python not found. Please install Python 3.9+ first."
    exit 1
fi

PYTHON_VERSION=$(python --version 2>&1 | cut -d' ' -f2)
echo "✅ Python $PYTHON_VERSION found"

# Install dependencies
echo "📦 Installing Python dependencies..."
pip install -r requirements.txt

# Check if users.json exists and is valid
echo "👤 Checking user configuration..."
if [ -f "users.json" ]; then
    if python -c "import json; json.load(open('users.json'))" 2>/dev/null; then
        echo "✅ users.json is valid"
        
        # Check if session ID needs updating
        SESSION_ID=$(python -c "import json; print(json.load(open('users.json'))[0]['cookies']['PHPSESSID'])")
        if [[ "$SESSION_ID" == *"your_session_id"* ]] || [[ "$SESSION_ID" == *"UPDATE_WITH"* ]]; then
            echo "⚠️  WARNING: Please update PHPSESSID in users.json with a real session ID"
            echo "   1. Login to https://kpcl-ams.com"
            echo "   2. Open Developer Tools (F12) → Application → Cookies"
            echo "   3. Copy PHPSESSID value and update users.json"
        else
            echo "✅ Session ID appears to be configured"
        fi
    else
        echo "❌ users.json has invalid JSON format"
        exit 1
    fi
else
    echo "❌ users.json not found. Creating from template..."
    cp users.json.example users.json
    echo "✅ Created users.json from template"
    echo "⚠️  Please update the session ID in users.json"
fi

# Test form fetcher
echo "🧪 Testing form fetcher..."
python -c "from form_fetcher import fetch_form_data_sync; print('✅ Form fetcher imports successfully')"

# Check AWS CLI (optional)
echo "☁️  Checking AWS CLI (optional for local development)..."
if command -v aws &> /dev/null; then
    if aws sts get-caller-identity &> /dev/null; then
        echo "✅ AWS CLI configured and working"
    else
        echo "⚠️  AWS CLI found but not configured"
        echo "   Run: aws configure"
    fi
else
    echo "ℹ️  AWS CLI not installed (only needed for deployment)"
fi

# Summary
echo ""
echo "📋 Setup Summary:"
echo "=================="
echo "✅ Python dependencies installed"
echo "✅ Form fetcher module ready"
echo "✅ User configuration file exists"

# Next steps
echo ""
echo "🎯 Next Steps:"
echo "=============="
echo "1. 🔐 Update users.json with real PHPSESSID from KPCL website"
echo "2. 🧪 Test: python test_form_fetcher.py"
echo "3. 🌐 Test locally: python app.py"
echo "4. ⏰ Test scheduler: python scheduler.py"
echo ""
echo "For AWS deployment:"
echo "5. 🔑 Setup AWS credentials (see AWS_SETUP_GUIDE.md)"
echo "6. 🚀 Deploy: git push origin main"
echo ""
echo "📚 Documentation:"
echo "  • README.md - General overview"
echo "  • AWS_SETUP_GUIDE.md - AWS deployment guide"
echo "  • DEPLOYMENT_SUMMARY.md - Complete deployment info"

echo ""
echo "🎉 Setup complete! Ready for testing and deployment."
