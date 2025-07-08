@echo off
REM GitHub Setup and Deployment Script for Windows

echo.
echo ==========================================
echo KPCL Automation - GitHub Setup ^& AWS Deployment
echo ==========================================

REM Check prerequisites
echo Checking prerequisites...

where git >nul 2>nul
if %errorlevel% neq 0 (
    echo ERROR: Git not found. Please install Git first.
    pause
    exit /b 1
)

where aws >nul 2>nul
if %errorlevel% neq 0 (
    echo ERROR: AWS CLI not found. Please install AWS CLI first.
    pause
    exit /b 1
)

where python >nul 2>nul
if %errorlevel% neq 0 (
    echo ERROR: Python not found. Please install Python first.
    pause
    exit /b 1
)

echo Prerequisites check passed!

REM Get user inputs
echo.
echo Configuration Setup
set /p GITHUB_USERNAME="Enter your GitHub username: "
set /p REPO_NAME="Enter repository name (default: kpcl-otp-automation): "
if "%REPO_NAME%"=="" set REPO_NAME=kpcl-otp-automation

set /p AWS_REGION="Enter AWS region (default: ap-south-1): "
if "%AWS_REGION%"=="" set AWS_REGION=ap-south-1

echo.
echo Setting up project structure...

REM Initialize Git if needed
if not exist ".git" (
    git init
    echo Git repository initialized
)

REM Create project structure
echo Creating GitHub project structure...

copy README_GITHUB.md README.md > nul
mkdir docs 2>nul
move DEPLOYMENT.md docs\ > nul 2>nul
move HYBRID_APPROACH.md docs\ > nul 2>nul
move IMPLEMENTATION_SUMMARY.md docs\ > nul 2>nul

REM Create tests directory
mkdir tests 2>nul
echo import unittest > tests\test_basic.py
echo import sys >> tests\test_basic.py
echo import os >> tests\test_basic.py
echo. >> tests\test_basic.py
echo # Add parent directory to path >> tests\test_basic.py
echo sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__)))) >> tests\test_basic.py
echo. >> tests\test_basic.py
echo from app import app >> tests\test_basic.py
echo from form_fetcher import KPCLFormFetcher >> tests\test_basic.py
echo. >> tests\test_basic.py
echo class TestBasicFunctionality(unittest.TestCase): >> tests\test_basic.py
echo     def setUp(self): >> tests\test_basic.py
echo         self.app = app.test_client() >> tests\test_basic.py
echo         self.app.testing = True >> tests\test_basic.py
echo. >> tests\test_basic.py
echo     def test_index_page(self): >> tests\test_basic.py
echo         response = self.app.get('/') >> tests\test_basic.py
echo         self.assertEqual(response.status_code, 200) >> tests\test_basic.py
echo. >> tests\test_basic.py
echo     def test_status_endpoint(self): >> tests\test_basic.py
echo         response = self.app.get('/status') >> tests\test_basic.py
echo         self.assertEqual(response.status_code, 200) >> tests\test_basic.py
echo         self.assertIn(b'healthy', response.data) >> tests\test_basic.py
echo. >> tests\test_basic.py
echo if __name__ == '__main__': >> tests\test_basic.py
echo     unittest.main() >> tests\test_basic.py

REM Create LICENSE
echo MIT License > LICENSE
echo. >> LICENSE
echo Copyright (c) 2025 KPCL OTP Automation >> LICENSE
echo. >> LICENSE
echo Permission is hereby granted, free of charge, to any person obtaining a copy >> LICENSE
echo of this software and associated documentation files (the "Software"), to deal >> LICENSE
echo in the Software without restriction... >> LICENSE

REM Add serverless_wsgi to requirements
findstr /C:"serverless_wsgi" requirements.txt >nul 2>nul
if %errorlevel% neq 0 (
    echo serverless_wsgi >> requirements.txt
)

REM Git operations
echo.
echo Preparing Git commit...

git add .

REM Check for changes
git diff --staged --quiet
if %errorlevel% equ 0 (
    echo No changes to commit
) else (
    git commit -m "Initial commit: KPCL OTP Automation System"
    echo Changes committed to Git
)

REM GitHub setup instructions
echo.
echo ==========================================
echo GitHub Repository Setup
echo ==========================================
echo Please follow these steps:
echo.
echo 1. Go to https://github.com/new
echo 2. Repository name: %REPO_NAME%
echo 3. Description: KPCL OTP Automation System with AWS deployment
echo 4. Set to Public or Private as needed
echo 5. Do NOT initialize with README (we already have one)
echo 6. Click 'Create repository'
echo.
pause

REM Add remote and push
echo Adding GitHub remote...
git remote remove origin 2>nul
git remote add origin "https://github.com/%GITHUB_USERNAME%/%REPO_NAME%.git"

echo Pushing to GitHub...
git branch -M main
git push -u origin main

echo Code pushed to GitHub successfully!

REM AWS Deployment
echo.
echo ==========================================
echo AWS Deployment
echo ==========================================
set /p DEPLOY_NOW="Do you want to deploy to AWS now? (y/N): "

if /i "%DEPLOY_NOW%"=="y" (
    echo Starting AWS deployment...
    
    REM Check AWS configuration
    aws sts get-caller-identity >nul 2>nul
    if %errorlevel% neq 0 (
        echo ERROR: AWS CLI not configured. Please run 'aws configure' first.
        echo You'll need:
        echo - AWS Access Key ID
        echo - AWS Secret Access Key
        echo - Default region: %AWS_REGION%
        pause
        exit /b 1
    )
    
    REM Run deployment (Windows version)
    call aws\deploy.bat
    
    echo.
    echo AWS deployment completed!
) else (
    echo Skipping AWS deployment
    echo To deploy later, run: aws\deploy.bat
)

REM Final summary
echo.
echo ==========================================
echo Setup Complete!
echo ==========================================
echo GitHub Repository: https://github.com/%GITHUB_USERNAME%/%REPO_NAME%
echo Documentation: Available in docs\ folder
echo Tests: Run with 'python -m pytest tests\'
echo Local Development: python app.py
echo.
echo Next Steps:
echo 1. Update users.json with real session cookies
echo 2. Test locally: python app.py
echo 3. Deploy to AWS: aws\deploy.bat (if not done already)
echo 4. Monitor in AWS CloudWatch
echo 5. Set up SNS notifications for alerts
echo.
echo Your KPCL automation system is ready!
pause
