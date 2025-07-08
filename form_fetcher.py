#!/usr/bin/env python3
"""
Dynamic form data fetcher for KPCL AMS gatepass form
Fetches form data from the actual website instead of using static values
"""

import httpx
from bs4 import BeautifulSoup
import re
import json
from typing import Dict, Optional

class KPCLFormFetcher:
    def __init__(self, cookies: Dict[str, str]):
        """
        Initialize form fetcher with user session cookies
        
        Args:
            cookies: Dictionary containing session cookies (PHPSESSID, etc.)
        """
        self.cookies = cookies
        self.headers = {
            'Referer': 'https://kpcl-ams.com/user/gatepass.php'
        }
    
    async def fetch_gatepass_form_data(self) -> Optional[Dict[str, str]]:
        """
        Fetch form data dynamically from KPCL gatepass page
        
        Returns:
            Dictionary containing extracted form data or None if failed
        """
        try:
            async with httpx.AsyncClient(cookies=self.cookies, timeout=30) as client:
                # First, get the gatepass page
                response = await client.get('https://kpcl-ams.com/user/gatepass.php')
                
                if response.status_code != 200:
                    print(f"❌ Failed to fetch gatepass page: {response.status_code}")
                    return None
                
                # Parse the HTML to extract form data
                soup = BeautifulSoup(response.text, 'html.parser')
                form_data = {}
                
                # Extract hidden input values
                hidden_inputs = soup.find_all('input', {'type': 'hidden'})
                for input_field in hidden_inputs:
                    name = input_field.get('name')
                    value = input_field.get('value', '')
                    if name:
                        form_data[name] = value
                
                # Extract selected option values from select elements
                select_elements = soup.find_all('select')
                for select in select_elements:
                    name = select.get('name')
                    if name:
                        # Find selected option or default to first option with value
                        selected = select.find('option', {'selected': True})
                        if selected and selected.get('value'):
                            form_data[name] = selected.get('value')
                        else:
                            # Use first option with non-empty value as default
                            options = select.find_all('option')
                            for option in options:
                                value = option.get('value', '').strip()
                                if value:
                                    form_data[name] = value
                                    break
                            else:
                                form_data[name] = ''
                
                # Extract input field values (text, radio, checkbox)
                input_elements = soup.find_all('input', {'type': ['text', 'radio', 'checkbox']})
                for input_field in input_elements:
                    name = input_field.get('name')
                    if name:
                        input_type = input_field.get('type')
                        
                        if input_type == 'radio':
                            # For radio buttons, only add if checked
                            if input_field.get('checked'):
                                form_data[name] = input_field.get('value', '')
                        elif input_type == 'checkbox':
                            # For checkboxes, only add if checked
                            if input_field.get('checked'):
                                form_data[name] = input_field.get('value', '')
                        else:
                            # For text inputs, use current value or default
                            value = input_field.get('value', '')
                            form_data[name] = value
                
                # Extract specific fields that might be in JavaScript or AJAX calls
                await self._extract_dynamic_fields(client, form_data)
                
                # Ensure required fields exist with default values
                self._set_default_values(form_data)
                
                print(f"✅ Successfully extracted {len(form_data)} form fields")
                return form_data
                
        except httpx.TimeoutException:
            print("❌ Timeout while fetching form data")
            return None
        except httpx.ConnectError:
            print("❌ Connection error while fetching form data")
            return None
        except Exception as e:
            print(f"❌ Error fetching form data: {e}")
            return None
    
    async def _extract_dynamic_fields(self, client: httpx.AsyncClient, form_data: Dict[str, str]):
        """
        Extract dynamic fields that might be loaded via AJAX or JavaScript
        
        Args:
            client: HTTP client instance
            form_data: Form data dictionary to update
        """
        try:
            # Check for any AJAX endpoints that might provide form data
            # This could include balance amounts, pricing, etc.
            
            # Example: Check if there's a balance endpoint
            balance_endpoints = [
                'https://kpcl-ams.com/user/get_balance.php',
                'https://kpcl-ams.com/user/check_balance.php',
                'https://kpcl-ams.com/ajax/balance.php'
            ]
            
            for endpoint in balance_endpoints:
                try:
                    response = await client.get(endpoint)
                    if response.status_code == 200:
                        # Try to parse JSON response
                        try:
                            data = response.json()
                            if isinstance(data, dict):
                                # Add any balance-related fields
                                for key, value in data.items():
                                    if key in ['balance_amount', 'ash_price', 'total_extra']:
                                        form_data[key] = str(value)
                        except:
                            # If not JSON, try to extract numbers from text
                            text = response.text
                            balance_match = re.search(r'(\d+\.?\d*)', text)
                            if balance_match:
                                form_data['balance_amount'] = balance_match.group(1)
                except:
                    continue
                    
        except Exception as e:
            print(f"⚠ Warning: Could not extract dynamic fields: {e}")
    
    def _set_default_values(self, form_data: Dict[str, str]):
        """
        Set default values for required fields that might not be present
        
        Args:
            form_data: Form data dictionary to update
        """
        defaults = {
            'gp_flag': '',
            'silo_name': '',
            'silo_no': '',
            'vehicle_no': '',
            'driver_mob_no': '',
            'generate_flyash_gatepass': '',
            'tps': 'BTPS',
            # Add other required fields with empty defaults
        }
        
        for key, default_value in defaults.items():
            if key not in form_data:
                form_data[key] = default_value

    async def fetch_and_merge_form_data(self, user_overrides: Dict[str, str] = None) -> Optional[Dict[str, str]]:
        """
        Fetch form data dynamically and merge with user-specific overrides
        
        Args:
            user_overrides: Dictionary of user-specific form fields to override
            
        Returns:
            Dictionary containing merged form data or None if failed
        """
        # First fetch all form data from the website
        form_data = await self.fetch_gatepass_form_data()
        
        if not form_data:
            return None
        
        # Override with user-specific data
        if user_overrides:
            print(f"🔄 Applying {len(user_overrides)} user-specific overrides")
            for key, value in user_overrides.items():
                if key in form_data:
                    print(f"  ✏️  Overriding {key}: '{form_data[key]}' → '{value}'")
                else:
                    print(f"  ➕ Adding {key}: '{value}'")
                form_data[key] = value
        
        return form_data

# Synchronous wrapper for compatibility
def fetch_form_data_sync(cookies: Dict[str, str], user_overrides: Dict[str, str] = None) -> Optional[Dict[str, str]]:
    """
    Synchronous wrapper for fetching form data with user overrides
    
    Args:
        cookies: Dictionary containing session cookies
        user_overrides: Dictionary of user-specific form fields to override
        
    Returns:
        Dictionary containing merged form data or None if failed
    """
    import asyncio
    
    fetcher = KPCLFormFetcher(cookies)
    
    try:
        # Check if there's already a running event loop
        loop = asyncio.get_running_loop()
        # If we're in an async context, we need to create a new thread
        import concurrent.futures
        with concurrent.futures.ThreadPoolExecutor() as executor:
            future = executor.submit(asyncio.run, fetcher.fetch_and_merge_form_data(user_overrides))
            return future.result()
    except RuntimeError:
        # No running loop, we can use asyncio.run directly
        return asyncio.run(fetcher.fetch_and_merge_form_data(user_overrides))

if __name__ == "__main__":
    # Test the form fetcher
    import json
    
    # Load cookies from users.json for testing
    try:
        with open('users.json', 'r') as f:
            users = json.load(f)
        
        if users:
            test_cookies = users[0]['cookies']
            user_overrides = users[0].get('user_form_data', {})
            print("🧪 Testing form data fetcher...")
            
            if user_overrides:
                print(f"🎯 Using {len(user_overrides)} user-specific overrides")
                form_data = fetch_form_data_sync(test_cookies, user_overrides)
            else:
                print("📝 No user overrides found, fetching base form data")
                form_data = fetch_form_data_sync(test_cookies)
            
            if form_data:
                print("\n✅ Form data extracted successfully:")
                for key, value in sorted(form_data.items()):
                    print(f"  {key}: {value}")
            else:
                print("❌ Failed to extract form data")
    except Exception as e:
        print(f"❌ Test failed: {e}")
