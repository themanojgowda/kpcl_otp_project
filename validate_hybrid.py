#!/usr/bin/env python3
"""
Configuration validator for the new hybrid approach
"""

import json
import os

def validate_users_config():
    """Validate the users.json configuration"""
    print("🔍 Validating users.json configuration...")
    
    try:
        with open('users.json', 'r') as f:
            users = json.load(f)
        
        if not users:
            print("❌ No users found in users.json")
            return False
        
        print(f"✅ Found {len(users)} user(s)")
        
        for i, user in enumerate(users, 1):
            print(f"\n👤 User {i}:")
            
            # Check required fields
            required = ['username', 'cookies']
            for field in required:
                if field in user:
                    print(f"  ✅ {field}: Present")
                else:
                    print(f"  ❌ {field}: Missing")
                    return False
            
            # Check optional user_form_data
            if 'user_form_data' in user:
                override_count = len(user['user_form_data'])
                print(f"  ✅ user_form_data: {override_count} override fields")
                
                # Show override fields
                for field, value in user['user_form_data'].items():
                    print(f"    🎯 {field}: '{value}'")
            else:
                print(f"  ℹ️  user_form_data: Not present (will use only dynamic data)")
            
            # Check cookies
            if isinstance(user['cookies'], dict):
                cookie_count = len(user['cookies'])
                print(f"  ✅ cookies: {cookie_count} cookie(s) configured")
                for cookie_name in user['cookies'].keys():
                    print(f"    🍪 {cookie_name}")
            else:
                print(f"  ❌ cookies: Invalid format (must be dictionary)")
                return False
        
        print(f"\n🎉 Configuration validation passed!")
        return True
        
    except FileNotFoundError:
        print("❌ users.json file not found")
        return False
    except json.JSONDecodeError as e:
        print(f"❌ Invalid JSON format: {e}")
        return False
    except Exception as e:
        print(f"❌ Validation error: {e}")
        return False

def show_expected_structure():
    """Show the expected users.json structure"""
    print("\n📋 Expected users.json structure:")
    print("""
[
  {
    "username": "your_username",
    "cookies": {
      "PHPSESSID": "actual_session_id_from_browser"
    },
    "user_form_data": {
      "ash_utilization": "Ash_based_Products",
      "pickup_time": "07.00AM - 08.00AM",
      "silo_name": "",
      "silo_no": "",
      "tps": "BTPS",
      "vehi_type": "16",
      "qty_fly_ash": "36",
      "vehi_type_oh": "hired",
      "authorised_person": "Manjula ",
      "vehicle_no": "",
      "dl_no": "9654",
      "driver_mob_no": "",
      "vehicle_no1": "KA36C5418",
      "driver_mob_no1": "9740856523",
      "generate_flyash_gatepass": ""
    }
  }
]
""")

def check_dependencies():
    """Check if required Python packages are available"""
    print("📦 Checking dependencies...")
    
    required_packages = [
        ('httpx', 'httpx'), 
        ('beautifulsoup4', 'bs4'), 
        ('flask', 'flask'), 
        ('requests', 'requests'), 
        ('apscheduler', 'apscheduler'), 
        ('flask_cors', 'flask_cors')
    ]
    
    missing = []
    for package_name, import_name in required_packages:
        try:
            __import__(import_name)
            print(f"  ✅ {package_name}")
        except ImportError:
            print(f"  ❌ {package_name}: Not installed")
            missing.append(package_name)
    
    if missing:
        print(f"\n❌ Missing packages: {', '.join(missing)}")
        print("💡 Install with: pip install " + " ".join(missing))
        return False
    else:
        print("✅ All dependencies satisfied")
        return True

def main():
    """Main validation function"""
    print("🔧 KPCL Hybrid Approach Configuration Validator")
    print("=" * 60)
    
    # Check dependencies
    deps_ok = check_dependencies()
    print()
    
    # Check configuration
    config_ok = validate_users_config()
    
    print("\n" + "=" * 60)
    
    if deps_ok and config_ok:
        print("🎉 Everything looks good!")
        print("\n💡 Next steps:")
        print("   1. Update PHPSESSID with valid session cookie from browser")
        print("   2. Test with: python test_form_fetcher.py")
        print("   3. Run the application: python app.py")
        print("   4. Or start scheduler: python scheduler.py")
    else:
        print("⚠️  Issues found. Please fix the above errors.")
        if not config_ok:
            show_expected_structure()

if __name__ == "__main__":
    main()
