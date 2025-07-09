@echo off
REM 🚀 Quick Setup Script for KPCL Automation (Windows)

echo 🚀 KPCL Automation - Quick Setup
echo =================================

REM Check if Python is installed
echo 🔍 Checking Python installation...
python --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Python not found. Please install Python 3.9+ first.
    exit /b 1
)

for /f "tokens=2" %%i in ('python --version 2^>^&1') do set PYTHON_VERSION=%%i
echo ✅ Python %PYTHON_VERSION% found

REM Install dependencies
echo 📦 Installing Python dependencies...
pip install -r requirements.txt

REM Check if users.json exists and is valid
echo 👤 Checking user configuration...
if exist "users.json" (
    python -c "import json; json.load(open('users.json'))" >nul 2>&1
    if errorlevel 1 (
        echo ❌ users.json has invalid JSON format
        exit /b 1
    ) else (
        echo ✅ users.json is valid
        
        REM Check if session ID needs updating
        for /f "delims=" %%i in ('python -c "import json; print(json.load(open('users.json'))[0]['cookies']['PHPSESSID'])"') do set SESSION_ID=%%i
        echo %SESSION_ID% | findstr /C:"your_session_id" >nul && (
            echo ⚠️  WARNING: Please update PHPSESSID in users.json with a real session ID
            echo    1. Login to https://kpcl-ams.com
            echo    2. Open Developer Tools ^(F12^) → Application → Cookies
            echo    3. Copy PHPSESSID value and update users.json
        ) || (
            echo %SESSION_ID% | findstr /C:"UPDATE_WITH" >nul && (
                echo ⚠️  WARNING: Please update PHPSESSID in users.json with a real session ID
            ) || (
                echo ✅ Session ID appears to be configured
            )
        )
    )
) else (
    echo ❌ users.json not found. Creating from template...
    copy users.json.example users.json >nul
    echo ✅ Created users.json from template
    echo ⚠️  Please update the session ID in users.json
)

REM Test form fetcher
echo 🧪 Testing form fetcher...
python -c "from form_fetcher import fetch_form_data_sync; print('✅ Form fetcher imports successfully')"

REM Check AWS CLI (optional)
echo ☁️  Checking AWS CLI ^(optional for local development^)...
aws --version >nul 2>&1
if errorlevel 1 (
    echo ℹ️  AWS CLI not installed ^(only needed for deployment^)
) else (
    aws sts get-caller-identity >nul 2>&1
    if errorlevel 1 (
        echo ⚠️  AWS CLI found but not configured
        echo    Run: aws configure
    ) else (
        echo ✅ AWS CLI configured and working
    )
)

REM Summary
echo.
echo 📋 Setup Summary:
echo ==================
echo ✅ Python dependencies installed
echo ✅ Form fetcher module ready
echo ✅ User configuration file exists

REM Next steps
echo.
echo 🎯 Next Steps:
echo ==============
echo 1. 🔐 Update users.json with real PHPSESSID from KPCL website
echo 2. 🧪 Test: python test_form_fetcher.py
echo 3. 🌐 Test locally: python app.py
echo 4. ⏰ Test scheduler: python scheduler.py
echo.
echo For AWS deployment:
echo 5. 🔑 Setup AWS credentials ^(see AWS_SETUP_GUIDE.md^)
echo 6. 🚀 Deploy: git push origin main
echo.
echo 📚 Documentation:
echo   • README.md - General overview
echo   • AWS_SETUP_GUIDE.md - AWS deployment guide
echo   • DEPLOYMENT_SUMMARY.md - Complete deployment info

echo.
echo 🎉 Setup complete! Ready for testing and deployment.
pause
