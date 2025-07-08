#!/usr/bin/env python3
"""
Test script for dynamic form data fetching
"""

import asyncio
import json
from form_fetcher import KPCLFormFetcher, fetch_form_data_sync

def test_form_fetcher():
    """Test the form fetcher with current users.json configuration"""
    print("🧪 Testing Dynamic Form Data Fetcher")
    print("=" * 50)
    
    # Load user cookies from users.json
    try:
        with open('users.json', 'r') as f:
            users = json.load(f)
        
        if not users:
            print("❌ No users found in users.json")
            return False
        
        user = users[0]
        cookies = user.get('cookies', {})
        username = user.get('username', 'Unknown')
        
        print(f"📋 Testing with user: {username}")
        print(f"🍪 Using cookies: {list(cookies.keys())}")
        
        # Test synchronous version with user overrides
        print("\n🔄 Fetching form data with user overrides...")
        user_overrides = user.get('user_form_data', {})
        
        if user_overrides:
            print(f"🎯 Using {len(user_overrides)} user-specific overrides")
            form_data = fetch_form_data_sync(cookies, user_overrides)
        else:
            print("📝 No user overrides found, fetching base form data")
            form_data = fetch_form_data_sync(cookies)
        
        if form_data:
            print(f"✅ Successfully fetched {len(form_data)} form fields")
            print("\n📝 Form Data Preview:")
            
            # Show key fields
            key_fields = [
                'ash_price', 'balance_amount', 'total_extra',
                'ash_utilization', 'pickup_time', 'tps',
                'vehi_type', 'qty_fly_ash', 'vehi_type_oh',
                'authorised_person', 'vehicle_no1', 'driver_mob_no1'
            ]
            
            for field in key_fields:
                value = form_data.get(field, 'NOT FOUND')
                status = "✅" if value != 'NOT FOUND' else "❌"
                print(f"  {status} {field:<20}: {value}")
            
            print(f"\n📊 Total fields: {len(form_data)}")
            print("\n🔧 All fields:")
            for key, value in sorted(form_data.items()):
                print(f"  {key}: {value}")
                
            return True
        else:
            print("❌ Failed to fetch form data")
            print("💡 Possible causes:")
            print("   - Invalid session cookies")
            print("   - Network connectivity issues")
            print("   - Website structure changes")
            print("   - Authentication required")
            return False
            
    except FileNotFoundError:
        print("❌ users.json file not found")
        return False
    except json.JSONDecodeError as e:
        print(f"❌ Invalid JSON in users.json: {e}")
        return False
    except Exception as e:
        print(f"❌ Test failed: {e}")
        return False

async def test_async_fetcher():
    """Test the async version of the form fetcher"""
    print("\n🔄 Testing Async Form Fetcher...")
    
    try:
        with open('users.json', 'r') as f:
            users = json.load(f)
        
        if users:
            user = users[0]
            cookies = user.get('cookies', {})
            user_overrides = user.get('user_form_data', {})
            
            fetcher = KPCLFormFetcher(cookies)
            form_data = await fetcher.fetch_and_merge_form_data(user_overrides)
            
            if form_data:
                print(f"✅ Async fetch successful: {len(form_data)} fields")
                return True
            else:
                print("❌ Async fetch failed")
                return False
    except Exception as e:
        print(f"❌ Async test failed: {e}")
        return False

def compare_with_static_data():
    """Compare fetched data with previous static data for validation"""
    print("\n📊 Comparing with Previous Static Configuration...")
    
    static_data = {
        "ash_price": "150",
        "balance_amount": "18078.489999999998", 
        "total_extra": "1146.89",
        "full_flyash": "50",
        "extra_flyash": "1.47",
        "ash_utilization": "Ash_based_Products",
        "pickup_time": "07.00AM - 08.00AM",
        "tps": "BTPS",
        "vehi_type": "16",
        "qty_fly_ash": "36",
        "vehi_type_oh": "hired",
        "authorised_person": "Manjula",
        "vehicle_no1": "KA36C5418",
        "driver_mob_no1": "9740856523"
    }
    
    try:
        with open('users.json', 'r') as f:
            users = json.load(f)
        
        if users:
            cookies = users[0]['cookies']
            user_overrides = users[0].get('user_form_data', {})
            fetched_data = fetch_form_data_sync(cookies, user_overrides)
            
            if fetched_data:
                matches = 0
                total = len(static_data)
                
                print("\n🔍 Field Comparison:")
                for field, static_value in static_data.items():
                    fetched_value = fetched_data.get(field, 'MISSING')
                    
                    if str(fetched_value) == str(static_value):
                        status = "✅ MATCH"
                        matches += 1
                    elif fetched_value == 'MISSING':
                        status = "❌ MISSING"
                    else:
                        status = "⚠️ DIFFER"
                    
                    print(f"  {field:<20}: {str(static_value):<20} → {str(fetched_value):<20} {status}")
                
                accuracy = (matches / total) * 100
                print(f"\n📈 Accuracy: {matches}/{total} ({accuracy:.1f}%)")
                
                if accuracy >= 80:
                    print("✅ Good accuracy - dynamic fetching is working well")
                elif accuracy >= 50:
                    print("⚠️ Moderate accuracy - some fields may be dynamic")
                else:
                    print("❌ Low accuracy - check website authentication or structure")
                    
    except Exception as e:
        print(f"❌ Comparison failed: {e}")

if __name__ == "__main__":
    print("🚀 KPCL Dynamic Form Fetcher Test Suite")
    print("=" * 60)
    
    # Test synchronous fetching
    success = test_form_fetcher()
    
    if success:
        # Test async fetching
        async_success = asyncio.run(test_async_fetcher())
        
        # Compare with static data
        compare_with_static_data()
        
        print("\n" + "=" * 60)
        if success and async_success:
            print("🎉 All tests passed! Dynamic form fetching is ready.")
            print("💡 Next steps:")
            print("   1. Update session cookies in users.json with valid values")
            print("   2. Test with actual KPCL website authentication")
            print("   3. Run scheduler.py or app.py to test integration")
        else:
            print("⚠️ Some tests failed. Check authentication and connectivity.")
    else:
        print("\n❌ Primary test failed. Please check:")
        print("   - Valid session cookies in users.json")
        print("   - Network connectivity to KPCL website")
        print("   - Website availability")
