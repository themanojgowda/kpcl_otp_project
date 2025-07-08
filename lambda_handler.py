"""
AWS Lambda handler for KPCL OTP Automation System
Supports both web interface and scheduled execution
"""
import json
import os
import boto3
from datetime import datetime
import logging
from botocore.exceptions import ClientError

# Import your application modules
try:
    from app import app
    from scheduler import post_gatepass
    import asyncio
except ImportError as e:
    print(f"Import error: {e}")

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """
    AWS Lambda handler that supports multiple invocation types:
    1. API Gateway requests (web interface)
    2. CloudWatch Events (scheduled execution)
    3. Manual invocation
    """
    
    logger.info(f"Lambda invoked with event: {json.dumps(event, default=str)}")
    
    try:
        # Determine invocation source
        invocation_source = get_invocation_source(event)
        logger.info(f"Invocation source: {invocation_source}")
        
        if invocation_source == "cloudwatch_scheduled":
            # Scheduled execution at 6:59:59 AM
            return handle_scheduled_execution(event, context)
        elif invocation_source == "api_gateway":
            # Web interface request
            return handle_web_request(event, context)
        else:
            # Manual or other invocation
            return handle_manual_invocation(event, context)
            
    except Exception as e:
        logger.error(f"Lambda execution failed: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': str(e),
                'timestamp': datetime.utcnow().isoformat()
            })
        }

def get_invocation_source(event):
    """Determine how Lambda was invoked"""
    if 'source' in event and event['source'] == 'aws.events':
        return "cloudwatch_scheduled"
    elif 'httpMethod' in event or 'requestContext' in event:
        return "api_gateway"
    else:
        return "manual"

def handle_scheduled_execution(event, context):
    """Handle scheduled execution at 6:59:59 AM"""
    logger.info("Executing scheduled KPCL form submission")
    
    try:
        # Load user configuration from AWS Secrets Manager
        users = load_user_config_from_secrets()
        
        results = []
        for user in users:
            try:
                logger.info(f"Processing user: {user.get('username', 'unknown')}")
                
                # Run async gatepass submission
                loop = asyncio.new_event_loop()
                asyncio.set_event_loop(loop)
                result = loop.run_until_complete(post_gatepass(user))
                loop.close()
                
                results.append({
                    'username': user.get('username'),
                    'status': 'success',
                    'timestamp': datetime.utcnow().isoformat(),
                    'result': result
                })
                
            except Exception as e:
                logger.error(f"Failed to process user {user.get('username')}: {str(e)}")
                results.append({
                    'username': user.get('username'),
                    'status': 'error',
                    'error': str(e),
                    'timestamp': datetime.utcnow().isoformat()
                })
        
        # Send notification if configured
        send_execution_notification(results)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Scheduled execution completed',
                'results': results,
                'timestamp': datetime.utcnow().isoformat()
            })
        }
        
    except Exception as e:
        logger.error(f"Scheduled execution failed: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': f'Scheduled execution failed: {str(e)}',
                'timestamp': datetime.utcnow().isoformat()
            })
        }

def handle_web_request(event, context):
    """Handle web interface requests through API Gateway"""
    logger.info("Handling web request through API Gateway")
    
    try:
        # Import Flask app and create WSGI adapter
        from werkzeug.wrappers import Request, Response
        from werkzeug.serving import WSGIRequestHandler
        import io
        
        # Convert API Gateway event to WSGI environ
        environ = create_wsgi_environ(event)
        
        # Create a response container
        response_data = {}
        
        def start_response(status, headers):
            response_data['status'] = status
            response_data['headers'] = dict(headers)
        
        # Call Flask app
        response_iter = app(environ, start_response)
        response_body = b''.join(response_iter).decode('utf-8')
        
        # Convert back to API Gateway format
        status_code = int(response_data['status'].split()[0])
        
        return {
            'statusCode': status_code,
            'headers': response_data.get('headers', {}),
            'body': response_body
        }
        
    except Exception as e:
        logger.error(f"Web request handling failed: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': str(e)})
        }

def handle_manual_invocation(event, context):
    """Handle manual or test invocations"""
    logger.info("Handling manual invocation")
    
    # Check if this is a test request
    if event.get('test', False):
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'KPCL Automation Lambda is healthy',
                'timestamp': datetime.utcnow().isoformat(),
                'version': '1.0.0',
                'features': [
                    'Scheduled execution at 6:59:59 AM',
                    'Web interface support',
                    'Dynamic form fetching',
                    'AWS Secrets Manager integration'
                ]
            })
        }
    
    # Default response for unknown manual invocations
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Lambda invoked manually',
            'event': event,
            'timestamp': datetime.utcnow().isoformat()
        })
    }

def load_user_config_from_secrets():
    """Load user configuration from AWS Secrets Manager"""
    try:
        secrets_client = boto3.client('secretsmanager')
        secret_name = os.environ.get('USER_CONFIG_SECRET_NAME', 'kpcl-user-config')
        
        response = secrets_client.get_secret_value(SecretId=secret_name)
        secret_data = json.loads(response['SecretString'])
        
        # Extract users array
        if 'users' in secret_data:
            return secret_data['users']
        else:
            return secret_data  # Assume the entire secret is the users array
            
    except ClientError as e:
        logger.error(f"Failed to load user config from Secrets Manager: {str(e)}")
        # Fallback to environment variable if available
        users_json = os.environ.get('USERS_JSON')
        if users_json:
            return json.loads(users_json)
        else:
            raise Exception("No user configuration found in Secrets Manager or environment")

def send_execution_notification(results):
    """Send execution results via SNS if configured"""
    try:
        sns_topic_arn = os.environ.get('SNS_TOPIC_ARN')
        if not sns_topic_arn:
            logger.info("No SNS topic configured, skipping notification")
            return
        
        sns_client = boto3.client('sns')
        
        # Prepare notification message
        success_count = len([r for r in results if r['status'] == 'success'])
        error_count = len([r for r in results if r['status'] == 'error'])
        
        message = f"""
KPCL Automation Execution Report
================================
Timestamp: {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')}
Total Users: {len(results)}
Successful: {success_count}
Failed: {error_count}

Results:
{json.dumps(results, indent=2)}
"""
        
        subject = f"KPCL Automation - {'✅ Success' if error_count == 0 else '⚠️ Partial Success' if success_count > 0 else '❌ Failed'}"
        
        sns_client.publish(
            TopicArn=sns_topic_arn,
            Subject=subject,
            Message=message
        )
        
        logger.info("Execution notification sent successfully")
        
    except Exception as e:
        logger.error(f"Failed to send notification: {str(e)}")

def create_wsgi_environ(event):
    """Convert API Gateway event to WSGI environ"""
    environ = {
        'REQUEST_METHOD': event.get('httpMethod', 'GET'),
        'SCRIPT_NAME': '',
        'PATH_INFO': event.get('path', '/'),
        'QUERY_STRING': '',
        'CONTENT_TYPE': '',
        'CONTENT_LENGTH': '',
        'SERVER_NAME': 'localhost',
        'SERVER_PORT': '80',
        'wsgi.version': (1, 0),
        'wsgi.url_scheme': 'https',
        'wsgi.input': io.StringIO(),
        'wsgi.errors': io.StringIO(),
        'wsgi.multithread': False,
        'wsgi.multiprocess': True,
        'wsgi.run_once': False
    }
    
    # Add headers
    headers = event.get('headers', {})
    for key, value in headers.items():
        key = key.upper().replace('-', '_')
        if key not in ('CONTENT_TYPE', 'CONTENT_LENGTH'):
            key = f'HTTP_{key}'
        environ[key] = value
    
    # Add query string
    if event.get('queryStringParameters'):
        from urllib.parse import urlencode
        environ['QUERY_STRING'] = urlencode(event['queryStringParameters'])
    
    # Add body
    if event.get('body'):
        environ['wsgi.input'] = io.StringIO(event['body'])
        environ['CONTENT_LENGTH'] = str(len(event['body']))
    
    return environ
