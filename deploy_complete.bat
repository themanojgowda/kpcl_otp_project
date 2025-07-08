@echo off
REM KPCL Automation - Complete GitHub Pages + AWS Deployment Script for Windows

echo.
echo 🚀 KPCL Automation - Complete Deployment Setup
echo ==============================================

REM Check prerequisites
echo.
echo Checking prerequisites...

where git >nul 2>nul
if %errorlevel% neq 0 (
    echo ❌ ERROR: Git not found. Please install Git first.
    pause
    exit /b 1
)

where aws >nul 2>nul
if %errorlevel% neq 0 (
    echo ❌ ERROR: AWS CLI not found. Please install AWS CLI first.
    pause
    exit /b 1
)

where python >nul 2>nul
if %errorlevel% neq 0 (
    echo ❌ ERROR: Python not found. Please install Python first.
    pause
    exit /b 1
)

echo ✅ Prerequisites check passed!

REM Get user inputs
echo.
echo Configuration Setup
set /p GITHUB_USERNAME="Enter your GitHub username: "
set /p REPO_NAME="Enter repository name (default: kpcl-otp-automation): "
if "%REPO_NAME%"=="" set REPO_NAME=kpcl-otp-automation

set /p AWS_REGION="Enter AWS region (default: ap-south-1): "
if "%AWS_REGION%"=="" set AWS_REGION=ap-south-1

set /p S3_BUCKET="Enter AWS S3 bucket for deployment: "

echo.
echo Summary:
echo GitHub: https://github.com/%GITHUB_USERNAME%/%REPO_NAME%
echo AWS Region: %AWS_REGION%
echo S3 Bucket: %S3_BUCKET%
echo.

set /p CONFIRM="Continue with deployment? (y/N): "
if /i not "%CONFIRM%"=="y" (
    echo Deployment cancelled.
    pause
    exit /b 0
)

REM Step 1: Setup Git repository
echo.
echo Step 1: Setting up Git repository...

if not exist ".git" (
    git init
    echo ✅ Git repository initialized
) else (
    echo ✅ Git repository already exists
)

REM Create .gitignore
echo # Python > .gitignore
echo __pycache__/ >> .gitignore
echo *.py[cod] >> .gitignore
echo *$py.class >> .gitignore
echo *.so >> .gitignore
echo .Python >> .gitignore
echo build/ >> .gitignore
echo develop-eggs/ >> .gitignore
echo dist/ >> .gitignore
echo downloads/ >> .gitignore
echo eggs/ >> .gitignore
echo .eggs/ >> .gitignore
echo lib/ >> .gitignore
echo lib64/ >> .gitignore
echo parts/ >> .gitignore
echo sdist/ >> .gitignore
echo var/ >> .gitignore
echo wheels/ >> .gitignore
echo *.egg-info/ >> .gitignore
echo .installed.cfg >> .gitignore
echo *.egg >> .gitignore
echo MANIFEST >> .gitignore
echo. >> .gitignore
echo # Virtual Environment >> .gitignore
echo venv/ >> .gitignore
echo env/ >> .gitignore
echo ENV/ >> .gitignore
echo. >> .gitignore
echo # IDE >> .gitignore
echo .vscode/ >> .gitignore
echo .idea/ >> .gitignore
echo *.swp >> .gitignore
echo *.swo >> .gitignore
echo. >> .gitignore
echo # OS >> .gitignore
echo .DS_Store >> .gitignore
echo Thumbs.db >> .gitignore
echo. >> .gitignore
echo # App specific >> .gitignore
echo sessions/ >> .gitignore
echo *.log >> .gitignore
echo. >> .gitignore
echo # Sensitive data >> .gitignore
echo users.json >> .gitignore
echo .env >> .gitignore

echo ✅ .gitignore created

REM Step 2: Prepare project structure
echo.
echo Step 2: Preparing project structure...

mkdir docs 2>nul
if exist "DEPLOYMENT.md" copy "DEPLOYMENT.md" "docs\" >nul
if exist "HYBRID_APPROACH.md" copy "HYBRID_APPROACH.md" "docs\" >nul
if exist "IMPLEMENTATION_SUMMARY.md" copy "IMPLEMENTATION_SUMMARY.md" "docs\" >nul

echo ✅ Documentation moved to docs/ directory

REM Create tests directory
mkdir tests 2>nul

REM Create basic test file
echo import unittest > tests\test_basic.py
echo import sys >> tests\test_basic.py
echo import os >> tests\test_basic.py
echo. >> tests\test_basic.py
echo # Add parent directory to path >> tests\test_basic.py
echo sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__)))) >> tests\test_basic.py
echo. >> tests\test_basic.py
echo from app import app >> tests\test_basic.py
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

echo ✅ Test structure created

REM Create LICENSE
echo MIT License > LICENSE
echo. >> LICENSE
echo Copyright (c) 2025 KPCL OTP Automation >> LICENSE
echo. >> LICENSE
echo Permission is hereby granted, free of charge, to any person obtaining a copy >> LICENSE
echo of this software and associated documentation files (the "Software"), to deal >> LICENSE
echo in the Software without restriction, including without limitation the rights >> LICENSE
echo to use, copy, modify, merge, publish, distribute, sublicense, and/or sell >> LICENSE
echo copies of the Software, and to permit persons to whom the Software is >> LICENSE
echo furnished to do so, subject to the following conditions: >> LICENSE
echo. >> LICENSE
echo The above copyright notice and this permission notice shall be included in all >> LICENSE
echo copies or substantial portions of the Software. >> LICENSE
echo. >> LICENSE
echo THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR >> LICENSE
echo IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, >> LICENSE
echo FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE >> LICENSE
echo AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER >> LICENSE
echo LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, >> LICENSE
echo OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE >> LICENSE
echo SOFTWARE. >> LICENSE

echo ✅ LICENSE created

REM Step 3: AWS Setup
echo.
echo Step 3: Setting up AWS resources...

REM Check AWS credentials
aws sts get-caller-identity >nul 2>nul
if %errorlevel% neq 0 (
    echo ❌ ERROR: AWS credentials not configured. Please run 'aws configure' first.
    pause
    exit /b 1
)

echo ✅ AWS credentials verified

REM Create S3 bucket if it doesn't exist
aws s3 ls "s3://%S3_BUCKET%" >nul 2>nul
if %errorlevel% neq 0 (
    echo Creating S3 bucket: %S3_BUCKET%
    aws s3 mb "s3://%S3_BUCKET%" --region "%AWS_REGION%"
    echo ✅ S3 bucket created
) else (
    echo ✅ S3 bucket already exists
)

REM Step 4: Package Lambda function
echo.
echo Step 4: Packaging Lambda function...

REM Create deployment package
if exist lambda-package rmdir /s /q lambda-package
mkdir lambda-package

REM Install dependencies in package directory
pip install -r requirements.txt -t lambda-package\

REM Copy application files
copy *.py lambda-package\ >nul
xcopy templates lambda-package\templates\ /e /i /q >nul
xcopy static lambda-package\static\ /e /i /q >nul 2>nul
copy users.json.example lambda-package\users.json.example >nul

REM Create deployment package
cd lambda-package
powershell -command "Compress-Archive -Path * -DestinationPath ..\kpcl-automation-lambda.zip -Force"
cd ..

echo ✅ Lambda package created

REM Upload to S3
aws s3 cp kpcl-automation-lambda.zip "s3://%S3_BUCKET%/lambda/kpcl-automation-lambda.zip"
echo ✅ Lambda package uploaded to S3

REM Step 5: Deploy CloudFormation stack
echo.
echo Step 5: Deploying AWS infrastructure...

set STACK_NAME=kpcl-automation-stack

REM Deploy stack
aws cloudformation deploy ^
    --template-file aws/cloudformation.yml ^
    --stack-name %STACK_NAME% ^
    --parameter-overrides ^
        LambdaCodeBucket=%S3_BUCKET% ^
        LambdaCodeKey=lambda/kpcl-automation-lambda.zip ^
    --capabilities CAPABILITY_IAM ^
    --region %AWS_REGION%

if %errorlevel% equ 0 (
    echo ✅ CloudFormation stack deployed successfully
) else (
    echo ❌ CloudFormation deployment failed
    pause
    exit /b 1
)

REM Get API Gateway URL
for /f "tokens=*" %%i in ('aws cloudformation describe-stacks --stack-name %STACK_NAME% --region %AWS_REGION% --query "Stacks[0].Outputs[?OutputKey=='ApiGatewayUrl'].OutputValue" --output text') do set API_URL=%%i

echo ✅ API Gateway URL: %API_URL%

REM Step 6: Setup GitHub repository
echo.
echo Step 6: Setting up GitHub repository...

REM Add all files to git
git add .
git commit -m "Initial commit: KPCL OTP Automation System"

REM Add GitHub remote (if not already added)
git remote get-url origin >nul 2>nul
if %errorlevel% neq 0 (
    git remote add origin "https://github.com/%GITHUB_USERNAME%/%REPO_NAME%.git"
    echo ✅ GitHub remote added
)

echo ⚠️  Ready to push to GitHub. Please ensure the repository exists on GitHub first.

REM Step 7: Setup AWS Secrets Manager
echo.
echo Step 7: Setting up AWS Secrets Manager...

set SECRET_NAME=kpcl-user-config

REM Create template secret
set TEMPLATE_SECRET={"users":[{"username":"your_username","cookies":{"PHPSESSID":"your_session_id_here"},"user_form_data":{"ash_utilization":"Ash_based_Products","pickup_time":"07.00AM - 08.00AM","tps":"BTPS","vehi_type":"16","qty_fly_ash":"36","vehicle_no1":"KA36C5418","driver_mob_no1":"9740856523"}}]}

aws secretsmanager describe-secret --secret-id %SECRET_NAME% --region %AWS_REGION% >nul 2>nul
if %errorlevel% neq 0 (
    aws secretsmanager create-secret ^
        --name %SECRET_NAME% ^
        --description "KPCL user configuration and session data" ^
        --secret-string "%TEMPLATE_SECRET%" ^
        --region %AWS_REGION%
    echo ✅ AWS Secret created with template data
) else (
    echo ✅ AWS Secret already exists
)

REM Final instructions
echo.
echo 🎉 Deployment Complete!
echo ======================
echo.
echo Your KPCL Automation System is now deployed:
echo.
echo 📱 Web Application: %API_URL%
echo 📚 GitHub Repository: https://github.com/%GITHUB_USERNAME%/%REPO_NAME%
echo 🌐 GitHub Pages: https://%GITHUB_USERNAME%.github.io/%REPO_NAME% (available after first push)
echo ☁️  AWS Stack: %STACK_NAME% (region: %AWS_REGION%)
echo.
echo ⚠️  Next Steps:
echo 1. Push to GitHub: git push -u origin main
echo 2. Enable GitHub Pages in repository settings
echo 3. Update AWS Secret with your real PHPSESSID
echo 4. Test the application: curl %API_URL%/status
echo.
echo Daily Workflow:
echo 🕕 6:45-6:55 AM: Login via web interface to refresh session
echo 🕕 6:59:59 AM: Automated form submission (AWS Lambda)
echo.
echo ⚠️  Important: Update your PHPSESSID in AWS Secrets Manager every morning after login!
echo.
echo Happy automating! 🚀
echo.
pause
