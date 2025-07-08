#!/usr/bin/env python3
"""
Project validation script for KPCL OTP Project
Checks for common configuration issues and dependencies
"""

import sys
import os
import json
import importlib.util

def check_dependencies():
    """Check if all required dependencies are installed"""
    print("🔍 Checking dependencies...")
    
    required_packages = [
        'flask',
        'flask_cors', 
        'requests',
        'apscheduler',
        'httpx'
    ]
    
    missing_packages = []
    
    for package in required_packages:
        spec = importlib.util.find_spec(package)
        if spec is None:
            missing_packages.append(package)
        else:
            print(f"  ✅ {package}")
    
    if missing_packages:
        print(f"  ❌ Missing packages: {', '.join(missing_packages)}")
        print("  💡 Run: pip install -r requirements.txt")
        return False
    
    return True

def check_users_json():
    """Validate users.json configuration"""
    print("\n🔍 Checking users.json...")
    
    if not os.path.exists('users.json'):
        print("  ❌ users.json not found")
        return False
    
    try:
        with open('users.json', 'r') as f:
            users = json.load(f)
        
        if not isinstance(users, list):
            print("  ❌ users.json should contain a list of users")
            return False
        
        if len(users) == 0:
            print("  ⚠️  users.json is empty")
            return False
        
        for i, user in enumerate(users):
            print(f"  🔍 Validating user {i+1}...")
            
            # Check required fields
            required_fields = ['username', 'cookies', 'form_data']
            for field in required_fields:
                if field not in user:
                    print(f"    ❌ Missing field: {field}")
                    return False
            
            # Check cookies structure
            if not isinstance(user['cookies'], dict):
                print(f"    ❌ 'cookies' should be a dictionary")
                return False
            
            if 'PHPSESSID' not in user['cookies']:
                print(f"    ⚠️  'PHPSESSID' not found in cookies (may be needed)")
            
            # Check form_data structure
            if not isinstance(user['form_data'], dict):
                print(f"    ❌ 'form_data' should be a dictionary")
                return False
            
            print(f"    ✅ User {user['username']} configuration valid")
        
        print(f"  ✅ All {len(users)} user(s) configured correctly")
        return True
        
    except json.JSONDecodeError as e:
        print(f"  ❌ Invalid JSON format: {e}")
        return False
    except Exception as e:
        print(f"  ❌ Error reading users.json: {e}")
        return False

def check_file_structure():
    """Check if all required files exist"""
    print("\n🔍 Checking file structure...")
    
    required_files = [
        'app.py',
        'scheduler.py',
        'requirements.txt',
        'templates/index.html',
        'templates/gatepass.html'
    ]
    
    required_dirs = [
        'templates',
        'static',
        'sessions'
    ]
    
    all_good = True
    
    for file_path in required_files:
        if os.path.exists(file_path):
            print(f"  ✅ {file_path}")
        else:
            print(f"  ❌ {file_path} missing")
            all_good = False
    
    for dir_path in required_dirs:
        if os.path.exists(dir_path) and os.path.isdir(dir_path):
            print(f"  ✅ {dir_path}/")
        else:
            print(f"  ❌ {dir_path}/ missing")
            all_good = False
    
    return all_good

def check_app_configuration():
    """Check app.py configuration"""
    print("\n🔍 Checking app.py configuration...")
    
    try:
        with open('app.py', 'r') as f:
            content = f.read()
        
        if "app.secret_key = 'your_secret_key'" in content:
            print("  ⚠️  Default secret key detected - change for production")
        else:
            print("  ✅ Secret key appears to be customized")
        
        if "debug=True" in content:
            print("  ⚠️  Debug mode enabled - disable for production")
        else:
            print("  ✅ Debug mode configuration")
        
        return True
        
    except Exception as e:
        print(f"  ❌ Error reading app.py: {e}")
        return False

def main():
    """Main validation function"""
    print("🚀 KPCL OTP Project Validation\n")
    
    checks = [
        check_file_structure,
        check_dependencies,
        check_users_json,
        check_app_configuration
    ]
    
    results = []
    for check in checks:
        results.append(check())
    
    print("\n" + "="*50)
    if all(results):
        print("🎉 All checks passed! Project is ready to run.")
        print("\n💡 To start the application:")
        print("   python app.py")
        print("\n💡 To start the scheduler:")
        print("   python scheduler.py")
    else:
        print("❌ Some issues found. Please fix them before running.")
        sys.exit(1)

if __name__ == "__main__":
    main()
