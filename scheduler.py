import asyncio
import httpx
from apscheduler.schedulers.background import BackgroundScheduler
from datetime import datetime
import json
import os
import sys
from form_fetcher import KPCLFormFetcher

# Load user config (username, cookies, gatepass data)
import os
import sys

# Get the directory where the script is located
script_dir = os.path.dirname(os.path.abspath(__file__))
users_file = os.path.join(script_dir, "users.json")

try:
    with open(users_file) as f:
        USERS = json.load(f)
    
    # Validate user data structure
    for i, user in enumerate(USERS):
        required_fields = ['username', 'cookies']  # user_form_data is optional
        for field in required_fields:
            if field not in user:
                print(f"❌ Error: User {i+1} missing required field '{field}'")
                sys.exit(1)
        
        if not isinstance(user['cookies'], dict):
            print(f"❌ Error: User {i+1} 'cookies' must be a dictionary")
            sys.exit(1)
        
        # Validate user_form_data if present
        if 'user_form_data' in user and not isinstance(user['user_form_data'], dict):
            print(f"❌ Error: User {i+1} 'user_form_data' must be a dictionary")
            sys.exit(1)
            
except FileNotFoundError:
    print(f"Error: users.json not found at {users_file}")
    sys.exit(1)
except json.JSONDecodeError as e:
    print(f"Error: Invalid JSON in users.json - {e}")
    sys.exit(1)

async def post_gatepass(user):
    # Only set the Referer header as default, everything else fetched dynamically
    headers = {
        'Referer': 'https://kpcl-ams.com/user/gatepass.php'
    }
    
    # Fetch form data dynamically from the website and merge with user-specific overrides
    fetcher = KPCLFormFetcher(user["cookies"])
    user_overrides = user.get("user_form_data", {})
    
    form_data = await fetcher.fetch_and_merge_form_data(user_overrides)
    
    if not form_data:
        print(f"[{user['username']}] ❌ Failed to fetch form data from website")
        return
    
    print(f"[{user['username']}] 📋 Using {len(form_data)} form fields (dynamic + user overrides)")
    
    async with httpx.AsyncClient(cookies=user["cookies"], timeout=30) as client:
        try:
            resp = await client.post("https://kpcl-ams.com/user/proof_uploade_code.php", 
                                   data=form_data, 
                                   headers=headers)
            print(f"[{user['username']}] ✔ Status: {resp.status_code} in {resp.elapsed.total_seconds():.3f}s")
            if resp.status_code != 200:
                print(f"[{user['username']}] ⚠ Response: {resp.text[:200]}...")
        except httpx.TimeoutException:
            print(f"[{user['username']}] ❌ Timeout error")
        except httpx.ConnectError:
            print(f"[{user['username']}] ❌ Connection error")
        except Exception as e:
            print(f"[{user['username']}] ❌ Error: {e}")

async def post_all_users():
    print(f"\n🚀 Submitting gatepasses at {datetime.now().strftime('%H:%M:%S.%f')[:-3]}")
    if not USERS:
        print("⚠ No users found in users.json")
        return
    
    tasks = [post_gatepass(user) for user in USERS]
    await asyncio.gather(*tasks, return_exceptions=True)
    print(f"✅ Completed all submissions at {datetime.now().strftime('%H:%M:%S.%f')[:-3]}")

def schedule_task():
    try:
        asyncio.run(post_all_users())
    except Exception as e:
        print(f"❌ Scheduler task failed: {e}")

if __name__ == "__main__":
    if not USERS:
        print("❌ No users configured. Please check users.json file.")
        sys.exit(1)
        
    scheduler = BackgroundScheduler()
    # Schedule at 06:59:59 AM (removed microseconds for reliability)
    scheduler.add_job(schedule_task, 'cron', hour=6, minute=59, second=59, id='gatepass_job')
    scheduler.start()

    print(f"✅ Scheduler started. Waiting for 06:59:59 AM daily...")
    print(f"📊 Configured for {len(USERS)} user(s)")
    
    try:
        # Keep script alive with periodic status updates
        import time
        while True:
            time.sleep(3600)  # Sleep for 1 hour
            print(f"🕐 Scheduler running - Next execution at 06:59:59 AM")
    except (KeyboardInterrupt, SystemExit):
        print("\n🛑 Shutting down scheduler...")
        scheduler.shutdown()
        print("✅ Scheduler stopped.")


