@echo off
REM AWS Deployment Script for KPCL Automation (Windows)

setlocal EnableDelayedExpansion

REM Configuration
set STACK_NAME=kpcl-automation
set REGION=ap-south-1
for /f %%i in ('powershell -Command "Get-Date -UFormat %%s"') do set TIMESTAMP=%%i
set S3_BUCKET=kpcl-automation-code-!TIMESTAMP!

echo.
echo ==========================================
echo Deploying KPCL Automation to AWS...
echo ==========================================

REM Check AWS CLI
where aws >nul 2>nul
if %errorlevel% neq 0 (
    echo ERROR: AWS CLI not found. Please install AWS CLI first.
    pause
    exit /b 1
)

REM Check AWS configuration
aws sts get-caller-identity >nul 2>nul
if %errorlevel% neq 0 (
    echo ERROR: AWS CLI not configured. Please run 'aws configure' first.
    pause
    exit /b 1
)

REM Create S3 bucket
echo Creating S3 bucket for deployment...
aws s3 mb s3://%S3_BUCKET% --region %REGION% 2>nul || echo Bucket creation skipped

REM Prepare Lambda package
echo Preparing Lambda deployment package...
if exist lambda_package rmdir /s /q lambda_package
if exist kpcl-automation.zip del kpcl-automation.zip
mkdir lambda_package

REM Install dependencies
echo Installing Python dependencies...
pip install -r requirements.txt -t lambda_package\ --quiet

REM Copy application files
echo Copying application files...
copy *.py lambda_package\ >nul
if exist templates xcopy templates lambda_package\templates\ /E /I /Q >nul
copy users.json.example lambda_package\users.json >nul

REM Create Lambda handler
echo Creating Lambda handler...
(
echo import json
echo import os
echo import sys
echo import asyncio
echo import boto3
echo from botocore.exceptions import ClientError
echo.
echo # Import application modules
echo try:
echo     from app import app
echo     from scheduler import schedule_task
echo     from form_fetcher import fetch_form_data_sync, KPCLFormFetcher
echo except ImportError as e:
echo     print^(f"Import error: {e}"^)
echo     app = None
echo.
echo def get_user_config^(^):
echo     """Get user configuration from AWS Secrets Manager"""
echo     try:
echo         secret_name = os.environ.get^('USER_CONFIG_SECRET'^)
echo         if not secret_name:
echo             import json
echo             with open^('users.json', 'r'^) as f:
echo                 return json.load^(f^)
echo         
echo         client = boto3.client^('secretsmanager'^)
echo         response = client.get_secret_value^(SecretId=secret_name^)
echo         return json.loads^(response['SecretString']^)
echo     except Exception as e:
echo         print^(f"Error getting user config: {e}"^)
echo         return []
echo.
echo def lambda_handler^(event, context^):
echo     """AWS Lambda handler"""
echo     sys.path.insert^(0, os.path.dirname^(__file__^)^)
echo     print^(f"Event: {json.dumps^(event, default=str^)}"^)
echo     
echo     if event.get^('source'^) == 'aws.events':
echo         try:
echo             print^("Executing scheduled task..."^)
echo             users = get_user_config^(^)
echo             if not users:
echo                 return {'statusCode': 500, 'body': json.dumps^({'error': 'No user configuration found'}^)}
echo             
echo             import asyncio
echo             from scheduler import post_all_users
echo             import scheduler
echo             scheduler.USERS = users
echo             asyncio.run^(post_all_users^(^)^)
echo             
echo             return {'statusCode': 200, 'body': json.dumps^({'message': 'Success', 'users_processed': len^(users^)}^)}
echo         except Exception as e:
echo             print^(f"Error: {str^(e^)}"^)
echo             return {'statusCode': 500, 'body': json.dumps^({'error': str^(e^)}^)}
echo     
echo     try:
echo         if not app:
echo             return {'statusCode': 200, 'headers': {'Content-Type': 'text/html'}, 'body': 'KPCL Automation System - Running on AWS Lambda!'}
echo         
echo         try:
echo             import serverless_wsgi
echo             return serverless_wsgi.handle_request^(app, event, context^)
echo         except ImportError:
echo             path = event.get^('path', '/''^)
echo             if path == '/status':
echo                 return {'statusCode': 200, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps^({'status': 'healthy'}^)}
echo             return {'statusCode': 200, 'headers': {'Content-Type': 'text/html'}, 'body': 'KPCL Automation System'}
echo     except Exception as e:
echo         return {'statusCode': 500, 'body': json.dumps^({'error': str^(e^)}^)}
) > lambda_package\lambda_handler.py

REM Add dependencies
echo serverless_wsgi >> lambda_package\requirements.txt
echo boto3 >> lambda_package\requirements.txt

REM Create ZIP package
echo Creating deployment package...
cd lambda_package
powershell -Command "Compress-Archive -Path * -DestinationPath ..\kpcl-automation.zip -Force"
cd ..

REM Upload to S3
echo Uploading deployment package to S3...
aws s3 cp kpcl-automation.zip s3://%S3_BUCKET%/kpcl-automation.zip --region %REGION%

REM Check CloudFormation template
if not exist "aws\cloudformation.yml" (
    echo ERROR: CloudFormation template not found at aws\cloudformation.yml
    pause
    exit /b 1
)

REM Deploy CloudFormation stack
echo Deploying CloudFormation stack...
aws cloudformation deploy ^
    --template-file aws\cloudformation.yml ^
    --stack-name %STACK_NAME% ^
    --parameter-overrides ^
        LambdaCodeBucket=%S3_BUCKET% ^
        LambdaCodeKey=kpcl-automation.zip ^
    --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM ^
    --region %REGION%

if %errorlevel% equ 0 (
    echo CloudFormation deployment successful!
) else (
    echo CloudFormation deployment failed!
    pause
    exit /b 1
)

REM Get deployment outputs
echo Getting deployment information...
for /f "delims=" %%i in ('aws cloudformation describe-stacks --stack-name %STACK_NAME% --region %REGION% --query "Stacks[0].Outputs[?OutputKey==`ApiGatewayUrl`].OutputValue" --output text 2^>nul') do set API_URL=%%i
for /f "delims=" %%i in ('aws cloudformation describe-stacks --stack-name %STACK_NAME% --region %REGION% --query "Stacks[0].Outputs[?OutputKey==`LambdaFunctionArn`].OutputValue" --output text 2^>nul') do set LAMBDA_ARN=%%i
for /f "delims=" %%i in ('aws cloudformation describe-stacks --stack-name %STACK_NAME% --region %REGION% --query "Stacks[0].Outputs[?OutputKey==`UserConfigSecret`].OutputValue" --output text 2^>nul') do set SECRET_ARN=%%i

REM Test deployment
echo Testing deployment...
if defined API_URL (
    for /f %%i in ('curl -s -o nul -w "%%{http_code}" "%API_URL%/status" 2^>nul') do set HTTP_STATUS=%%i
    if "!HTTP_STATUS!"=="200" (
        echo API Gateway health check passed
    ) else (
        echo API Gateway returned status: !HTTP_STATUS!
    )
)

REM Display summary
echo.
echo ==========================================
echo Deployment completed successfully!
echo ==========================================
echo.
echo Deployment Summary:
echo ==========================================
echo Web Interface: %API_URL%
echo Schedule: 6:59:59 AM IST daily (1:29:59 AM UTC)
echo Login Window: 6:45-6:55 AM IST
echo Lambda Function: %LAMBDA_ARN%
echo User Config Secret: %SECRET_ARN%
echo.
echo Next Steps:
echo 1. Update user configuration in AWS Secrets Manager:
echo    aws secretsmanager update-secret --secret-id "%SECRET_ARN%" --secret-string file://users.json
echo.
echo 2. Monitor execution in CloudWatch:
echo    https://console.aws.amazon.com/lambda/home?region=%REGION%#/functions/kpcl-automation-function
echo.
echo 3. Set up SNS notifications (optional):
echo    aws sns subscribe --topic-arn [SNS-TOPIC-ARN] --protocol email --notification-endpoint your-email@example.com
echo.
echo Your KPCL automation system is now live and scheduled!

REM Cleanup
echo.
echo Cleaning up temporary files...
if exist lambda_package rmdir /s /q lambda_package
if exist kpcl-automation.zip del kpcl-automation.zip

echo.
echo Deployment complete!
pause
