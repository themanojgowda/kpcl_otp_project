@echo off
REM KPCL Automation - Custom Domain Deployment Script for Windows
REM This script deploys the KPCL automation system to AWS with your custom domain

echo.
echo 🚀 KPCL Automation - Custom Domain Deployment
echo ==============================================

REM Configuration
set /p DOMAIN_NAME="Enter your domain name (e.g., kpcl.yourdomain.com): "
set /p CERTIFICATE_ARN="Enter your ACM Certificate ARN (optional): "
set /p AWS_REGION="Enter AWS Region [ap-south-1]: "
if "%AWS_REGION%"=="" set AWS_REGION=ap-south-1

set /p S3_BUCKET="Enter S3 bucket name for deployment [kpcl-automation-deployment]: "
if "%S3_BUCKET%"=="" set S3_BUCKET=kpcl-automation-deployment

echo.
echo 📋 Deployment Configuration:
echo    Domain: %DOMAIN_NAME%
echo    Certificate: %CERTIFICATE_ARN%
echo    Region: %AWS_REGION%
echo    S3 Bucket: %S3_BUCKET%
echo.

set /p CONFIRM="Continue with deployment? (y/N): "
if /i not "%CONFIRM%"=="y" (
    echo Deployment cancelled.
    exit /b 0
)

echo.
echo 🔧 Step 1: Preparing deployment package...

REM Create deployment directory
if exist deployment rmdir /s /q deployment
mkdir deployment
cd deployment

REM Copy application files
xcopy ..\templates . /E /I 2>nul || echo No templates directory found
xcopy ..\static . /E /I 2>nul || echo No static directory found
copy ..\*.py . 2>nul
copy ..\requirements.txt . 2>nul
copy ..\users.json.example users.json 2>nul

REM Install dependencies for Lambda
echo Installing Python dependencies...
pip install -r requirements.txt -t .
pip install serverless-wsgi -t .

REM Create optimized Lambda handler
echo import json > lambda_handler.py
echo import os >> lambda_handler.py
echo import asyncio >> lambda_handler.py
echo import logging >> lambda_handler.py
echo from datetime import datetime >> lambda_handler.py
echo import boto3 >> lambda_handler.py
echo from botocore.exceptions import ClientError >> lambda_handler.py
echo. >> lambda_handler.py
echo # Configure logging >> lambda_handler.py
echo logger = logging.getLogger() >> lambda_handler.py
echo logger.setLevel(logging.INFO) >> lambda_handler.py
echo. >> lambda_handler.py
echo def lambda_handler(event, context): >> lambda_handler.py
echo     """AWS Lambda handler for KPCL OTP Automation""" >> lambda_handler.py
echo     if event.get('source') == 'aws.events': >> lambda_handler.py
echo         return handle_scheduled_task(event, context) >> lambda_handler.py
echo     return handle_web_request(event, context) >> lambda_handler.py
echo. >> lambda_handler.py
echo def handle_scheduled_task(event, context): >> lambda_handler.py
echo     """Handle scheduled form submission""" >> lambda_handler.py
echo     try: >> lambda_handler.py
echo         logger.info("Starting scheduled KPCL form submission...") >> lambda_handler.py
echo         users = load_user_config() >> lambda_handler.py
echo         if not users: >> lambda_handler.py
echo             return {'statusCode': 500, 'body': json.dumps({'error': 'No config'})} >> lambda_handler.py
echo         from scheduler import post_gatepass >> lambda_handler.py
echo         results = [] >> lambda_handler.py
echo         for user in users: >> lambda_handler.py
echo             try: >> lambda_handler.py
echo                 result = asyncio.run(post_gatepass(user)) >> lambda_handler.py
echo                 results.append({'username': user.get('username'), 'success': True}) >> lambda_handler.py
echo             except Exception as e: >> lambda_handler.py
echo                 results.append({'username': user.get('username'), 'success': False, 'error': str(e)}) >> lambda_handler.py
echo         return {'statusCode': 200, 'body': json.dumps({'results': results})} >> lambda_handler.py
echo     except Exception as e: >> lambda_handler.py
echo         return {'statusCode': 500, 'body': json.dumps({'error': str(e)})} >> lambda_handler.py
echo. >> lambda_handler.py
echo def handle_web_request(event, context): >> lambda_handler.py
echo     """Handle web requests""" >> lambda_handler.py
echo     try: >> lambda_handler.py
echo         import serverless_wsgi >> lambda_handler.py
echo         from app import app >> lambda_handler.py
echo         return serverless_wsgi.handle_request(app, event, context) >> lambda_handler.py
echo     except ImportError: >> lambda_handler.py
echo         path = event.get('path', '/') >> lambda_handler.py
echo         if path == '/': >> lambda_handler.py
echo             return {'statusCode': 200, 'headers': {'Content-Type': 'text/html'}, 'body': '<!DOCTYPE html><html><head><title>KPCL Login</title></head><body><h1>KPCL OTP Automation</h1><p>System running on AWS Lambda!</p></body></html>'} >> lambda_handler.py
echo         elif path == '/status': >> lambda_handler.py
echo             return {'statusCode': 200, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps({'status': 'healthy', 'service': 'KPCL OTP Automation', 'timestamp': datetime.now().isoformat()})} >> lambda_handler.py
echo         return {'statusCode': 404, 'body': 'Not Found'} >> lambda_handler.py
echo. >> lambda_handler.py
echo def load_user_config(): >> lambda_handler.py
echo     """Load user config from Secrets Manager""" >> lambda_handler.py
echo     try: >> lambda_handler.py
echo         client = boto3.client('secretsmanager') >> lambda_handler.py
echo         secret = os.environ.get('USER_CONFIG_SECRET') >> lambda_handler.py
echo         if not secret: return None >> lambda_handler.py
echo         response = client.get_secret_value(SecretId=secret) >> lambda_handler.py
echo         return json.loads(response['SecretString']) >> lambda_handler.py
echo     except: return None >> lambda_handler.py

REM Create deployment package
echo Creating deployment package...
powershell -command "Compress-Archive -Path * -DestinationPath ..\kpcl-automation.zip -Force"

cd ..

echo.
echo ☁️ Step 2: Uploading to AWS...

REM Create S3 bucket if it doesn't exist
echo Creating S3 bucket: %S3_BUCKET%
aws s3 mb s3://%S3_BUCKET% --region %AWS_REGION% 2>nul || echo Bucket already exists

REM Upload deployment package
echo Uploading deployment package...
aws s3 cp kpcl-automation.zip s3://%S3_BUCKET%/kpcl-automation.zip

echo.
echo 🏗️ Step 3: Deploying CloudFormation stack...

REM Deploy CloudFormation stack
if "%CERTIFICATE_ARN%"=="" (
    aws cloudformation deploy --template-file aws\cloudformation.yml --stack-name kpcl-automation --parameter-overrides LambdaCodeBucket=%S3_BUCKET% LambdaCodeKey=kpcl-automation.zip DomainName=%DOMAIN_NAME% --capabilities CAPABILITY_IAM --region %AWS_REGION%
) else (
    aws cloudformation deploy --template-file aws\cloudformation.yml --stack-name kpcl-automation --parameter-overrides LambdaCodeBucket=%S3_BUCKET% LambdaCodeKey=kpcl-automation.zip DomainName=%DOMAIN_NAME% CertificateArn=%CERTIFICATE_ARN% --capabilities CAPABILITY_IAM --region %AWS_REGION%
)

echo.
echo 📋 Step 4: Getting deployment information...

REM Get API Gateway URL
for /f "tokens=*" %%i in ('aws cloudformation describe-stacks --stack-name kpcl-automation --region %AWS_REGION% --query "Stacks[0].Outputs[?OutputKey==\`ApiGatewayUrl\`].OutputValue" --output text') do set API_URL=%%i

echo.
echo ✅ Deployment completed successfully!
echo ==================================
echo.
echo 🌐 Your KPCL Automation System is now live:
echo.
if not "%DOMAIN_NAME%"=="" (
    echo    🏠 Primary URL: https://%DOMAIN_NAME%
)
echo    📡 API Gateway URL: %API_URL%
echo.
echo ⏰ Scheduled Execution: Daily at 6:59:59 AM IST
echo 🕕 User Login Window: 6:45-6:55 AM IST
echo.
echo 📋 Next Steps:
echo    1. Update your DNS to point %DOMAIN_NAME% to CloudFront
echo    2. Update users.json in AWS Secrets Manager with real session data
echo    3. Test the login flow between 6:45-6:55 AM
echo    4. Monitor execution in CloudWatch Logs
echo.
echo 📊 Monitoring:
echo    - CloudWatch Logs: https://console.aws.amazon.com/cloudwatch/home?region=%AWS_REGION%
echo    - Lambda Function: https://console.aws.amazon.com/lambda/home?region=%AWS_REGION%
echo.

REM Test the deployment
echo 🧪 Testing deployment...
curl -f "%API_URL%/status" >nul 2>&1 && echo ✅ Health check passed || echo ❌ Health check failed

echo.
echo 🎉 Deployment complete! Your KPCL automation system is ready!

REM Cleanup
rmdir /s /q deployment 2>nul
del kpcl-automation.zip 2>nul

pause
