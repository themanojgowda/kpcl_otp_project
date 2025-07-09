#!/usr/bin/env python3
"""
KPCL Form Data Fetcher

This module provides functionality to dynamically fetch form data from the KPCL AMS website
and merge it with user-specific overrides. It supports both synchronous and asynchronous operations.

Features:
- Dynamic form data extraction from KPCL gatepass page
- User-specific field overrides
- Session cookie authentication
- Robust error handling and logging
- Both sync and async interfaces
"""

import asyncio
import re
import time
from typing import Dict, Optional, Any
import requests
import httpx
from bs4 import BeautifulSoup


class KPCLFormFetcher:
    """
    Asynchronous form data fetcher for KPCL AMS website
    """
    
    def __init__(self, cookies: Dict[str, str]):
        """
        Initialize the form fetcher with user session cookies
        
        Args:
            cookies: Dictionary containing session cookies (typically PHPSESSID)
        """
        self.cookies = cookies
        self.base_url = "https://kpcl-ams.com"
        self.gatepass_url = f"{self.base_url}/user/gatepass.php"
        
        # Default headers to mimic browser behavior
        self.headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.9',
            'Accept-Encoding': 'gzip, deflate, br',
            'Cache-Control': 'no-cache',
            'Pragma': 'no-cache',
            'Upgrade-Insecure-Requests': '1',
            'Sec-Fetch-Dest': 'document',
            'Sec-Fetch-Mode': 'navigate',
            'Sec-Fetch-Site': 'same-origin',
        }

    async def fetch_gatepass_form_data(self) -> Optional[Dict[str, str]]:
        """
        Fetch raw form data from the KPCL gatepass page
        
        Returns:
            Dictionary containing all form fields and their current values,
            or None if fetching fails
        """
        try:
            async with httpx.AsyncClient(
                cookies=self.cookies,
                headers=self.headers,
                timeout=30.0,
                follow_redirects=True
            ) as client:
                
                print(f"🌐 Fetching form data from: {self.gatepass_url}")
                response = await client.get(self.gatepass_url)
                
                if response.status_code == 200:
                    return self._parse_form_data(response.text)
                elif response.status_code == 302:
                    print("⚠️ Redirected - session may have expired")
                    return None
                else:
                    print(f"❌ HTTP {response.status_code}: Failed to fetch gatepass page")
                    return None
                    
        except httpx.TimeoutException:
            print("❌ Timeout while fetching form data")
            return None
        except httpx.ConnectError:
            print("❌ Connection error while fetching form data")
            return None
        except Exception as e:
            print(f"❌ Unexpected error fetching form data: {e}")
            return None

    def _parse_form_data(self, html_content: str) -> Dict[str, str]:
        """
        Parse HTML content and extract form field values
        
        Args:
            html_content: Raw HTML content from gatepass page
            
        Returns:
            Dictionary mapping form field names to their values
        """
        form_data = {}
        
        try:
            soup = BeautifulSoup(html_content, 'html.parser')
            
            # Find all input fields
            inputs = soup.find_all(['input', 'select', 'textarea'])
            
            for element in inputs:
                name = element.get('name')
                if not name:
                    continue
                
                # Handle different input types
                input_type = element.get('type', '').lower()
                tag_name = element.name.lower()
                
                if tag_name == 'input':
                    if input_type in ['text', 'hidden', 'number', 'email', 'tel']:
                        form_data[name] = element.get('value', '')
                    elif input_type == 'checkbox':
                        # Include checkbox value if checked
                        if element.get('checked'):
                            form_data[name] = element.get('value', '1')
                        else:
                            form_data[name] = ''
                    elif input_type == 'radio':
                        # Include radio value if checked
                        if element.get('checked'):
                            form_data[name] = element.get('value', '')
                        elif name not in form_data:
                            form_data[name] = ''
                            
                elif tag_name == 'select':
                    # Find selected option
                    selected_option = element.find('option', {'selected': True})
                    if selected_option:
                        form_data[name] = selected_option.get('value', '')
                    else:
                        # If no option is selected, use the first one or empty
                        first_option = element.find('option')
                        form_data[name] = first_option.get('value', '') if first_option else ''
                        
                elif tag_name == 'textarea':
                    form_data[name] = element.get_text(strip=True)
            
            # Extract dynamic values from JavaScript or page content
            self._extract_dynamic_values(soup, form_data, html_content)
            
            print(f"📋 Extracted {len(form_data)} form fields")
            return form_data
            
        except Exception as e:
            print(f"❌ Error parsing form data: {e}")
            return {}

    def _extract_dynamic_values(self, soup: BeautifulSoup, form_data: Dict[str, str], html_content: str):
        """
        Extract dynamic values that might be set via JavaScript or embedded in the page
        
        Args:
            soup: BeautifulSoup object of the parsed HTML
            form_data: Dictionary to update with extracted values
            html_content: Raw HTML content for regex extraction
        """
        try:
            # Extract values from JavaScript variables (common patterns)
            js_patterns = [
                r'var\s+ash_price\s*=\s*["\']([^"\']+)["\']',
                r'var\s+balance_amount\s*=\s*["\']([^"\']+)["\']',
                r'var\s+total_extra\s*=\s*["\']([^"\']+)["\']',
                r'ash_price\s*=\s*["\']([^"\']+)["\']',
                r'balance_amount\s*=\s*["\']([^"\']+)["\']',
                r'total_extra\s*=\s*["\']([^"\']+)["\']',
            ]
            
            for pattern in js_patterns:
                matches = re.finditer(pattern, html_content, re.IGNORECASE)
                for match in matches:
                    # Extract variable name from pattern
                    var_name = pattern.split('\\s+')[1] if '\\s+' in pattern else None
                    if var_name and var_name.endswith('price') or var_name.endswith('amount') or var_name.endswith('extra'):
                        form_data[var_name] = match.group(1)
            
            # Look for values in specific table cells or divs (KPCL-specific patterns)
            # These patterns are based on common KPCL website structures
            value_selectors = [
                ('#ash_price', 'ash_price'),
                ('#balance_amount', 'balance_amount'), 
                ('#total_extra', 'total_extra'),
                ('.price-value', 'ash_price'),
                ('.balance-value', 'balance_amount'),
                ('.extra-value', 'total_extra'),
            ]
            
            for selector, field_name in value_selectors:
                element = soup.select_one(selector)
                if element:
                    value = element.get_text(strip=True)
                    # Clean up the value (remove currency symbols, spaces, etc.)
                    clean_value = re.sub(r'[^\d.-]', '', value)
                    if clean_value:
                        form_data[field_name] = clean_value
            
            # Extract values from data attributes
            data_elements = soup.find_all(attrs={'data-price': True})
            for element in data_elements:
                if element.get('data-price'):
                    form_data['ash_price'] = element['data-price']
                    
            data_elements = soup.find_all(attrs={'data-balance': True})
            for element in data_elements:
                if element.get('data-balance'):
                    form_data['balance_amount'] = element['data-balance']
                    
        except Exception as e:
            print(f"⚠️ Warning: Could not extract dynamic values: {e}")

    async def fetch_and_merge_form_data(self, user_overrides: Optional[Dict[str, Any]] = None) -> Optional[Dict[str, str]]:
        """
        Fetch form data from website and merge with user-specific overrides
        
        Args:
            user_overrides: Dictionary of user-specific field values to override defaults
            
        Returns:
            Merged form data dictionary, or None if fetching fails
        """
        # Fetch base form data from website
        base_form_data = await self.fetch_gatepass_form_data()
        
        if base_form_data is None:
            print("❌ Failed to fetch base form data")
            return None
        
        # Start with base form data
        merged_data = base_form_data.copy()
        
        # Apply user overrides
        if user_overrides:
            override_count = 0
            for key, value in user_overrides.items():
                if value is not None and str(value).strip():  # Only override with non-empty values
                    merged_data[key] = str(value)
                    override_count += 1
            
            print(f"🎯 Applied {override_count} user-specific overrides")
        
        # Ensure critical fields have values
        self._ensure_critical_fields(merged_data)
        
        return merged_data

    def _ensure_critical_fields(self, form_data: Dict[str, str]):
        """
        Ensure critical form fields have reasonable default values
        
        Args:
            form_data: Form data dictionary to validate and fix
        """
        # Define critical fields with fallback values
        critical_defaults = {
            'ash_utilization': 'Ash_based_Products',
            'pickup_time': '07.00AM - 08.00AM',
            'tps': 'BTPS',
            'vehi_type': '16',
            'qty_fly_ash': '36',
            'vehi_type_oh': 'hired',
            'authorised_person': 'Manjula',
            'dl_no': '9654',
            'generate_flyash_gatepass': ''
        }
        
        for field, default_value in critical_defaults.items():
            if field not in form_data or not form_data[field]:
                form_data[field] = default_value
                print(f"🔧 Set default value for {field}: {default_value}")


class SyncKPCLFormFetcher:
    """
    Synchronous wrapper for KPCL form fetching (for compatibility)
    """
    
    def __init__(self, cookies: Dict[str, str]):
        self.cookies = cookies
        self.base_url = "https://kpcl-ams.com"
        self.gatepass_url = f"{self.base_url}/user/gatepass.php"
        
        self.headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.9',
            'Accept-Encoding': 'gzip, deflate, br',
            'Cache-Control': 'no-cache',
            'Referer': self.base_url,
        }

    def fetch_gatepass_form_data(self) -> Optional[Dict[str, str]]:
        """
        Synchronously fetch form data from KPCL gatepass page
        
        Returns:
            Dictionary containing form fields and values, or None if failed
        """
        try:
            print(f"🌐 Fetching form data from: {self.gatepass_url}")
            
            session = requests.Session()
            session.cookies.update(self.cookies)
            session.headers.update(self.headers)
            
            response = session.get(self.gatepass_url, timeout=30)
            
            if response.status_code == 200:
                return self._parse_form_data(response.text)
            elif response.status_code == 302:
                print("⚠️ Redirected - session may have expired")
                return None
            else:
                print(f"❌ HTTP {response.status_code}: Failed to fetch gatepass page")
                return None
                
        except requests.exceptions.Timeout:
            print("❌ Timeout while fetching form data")
            return None
        except requests.exceptions.ConnectionError:
            print("❌ Connection error while fetching form data")
            return None
        except Exception as e:
            print(f"❌ Unexpected error fetching form data: {e}")
            return None

    def _parse_form_data(self, html_content: str) -> Dict[str, str]:
        """Parse HTML and extract form data (same logic as async version)"""
        form_data = {}
        
        try:
            soup = BeautifulSoup(html_content, 'html.parser')
            
            # Find all form elements
            inputs = soup.find_all(['input', 'select', 'textarea'])
            
            for element in inputs:
                name = element.get('name')
                if not name:
                    continue
                
                input_type = element.get('type', '').lower()
                tag_name = element.name.lower()
                
                if tag_name == 'input':
                    if input_type in ['text', 'hidden', 'number', 'email', 'tel']:
                        form_data[name] = element.get('value', '')
                    elif input_type == 'checkbox':
                        if element.get('checked'):
                            form_data[name] = element.get('value', '1')
                        else:
                            form_data[name] = ''
                    elif input_type == 'radio':
                        if element.get('checked'):
                            form_data[name] = element.get('value', '')
                        elif name not in form_data:
                            form_data[name] = ''
                            
                elif tag_name == 'select':
                    selected_option = element.find('option', {'selected': True})
                    if selected_option:
                        form_data[name] = selected_option.get('value', '')
                    else:
                        first_option = element.find('option')
                        form_data[name] = first_option.get('value', '') if first_option else ''
                        
                elif tag_name == 'textarea':
                    form_data[name] = element.get_text(strip=True)
            
            # Extract dynamic values
            self._extract_dynamic_values(soup, form_data, html_content)
            
            print(f"📋 Extracted {len(form_data)} form fields")
            return form_data
            
        except Exception as e:
            print(f"❌ Error parsing form data: {e}")
            return {}

    def _extract_dynamic_values(self, soup: BeautifulSoup, form_data: Dict[str, str], html_content: str):
        """Extract dynamic values (same logic as async version)"""
        try:
            # JavaScript variable patterns
            js_patterns = [
                r'var\s+ash_price\s*=\s*["\']([^"\']+)["\']',
                r'var\s+balance_amount\s*=\s*["\']([^"\']+)["\']',
                r'var\s+total_extra\s*=\s*["\']([^"\']+)["\']',
            ]
            
            for pattern in js_patterns:
                matches = re.finditer(pattern, html_content, re.IGNORECASE)
                for match in matches:
                    if 'ash_price' in pattern:
                        form_data['ash_price'] = match.group(1)
                    elif 'balance_amount' in pattern:
                        form_data['balance_amount'] = match.group(1)
                    elif 'total_extra' in pattern:
                        form_data['total_extra'] = match.group(1)
            
            # CSS selector patterns
            value_selectors = [
                ('#ash_price', 'ash_price'),
                ('#balance_amount', 'balance_amount'),
                ('#total_extra', 'total_extra'),
            ]
            
            for selector, field_name in value_selectors:
                element = soup.select_one(selector)
                if element:
                    value = element.get_text(strip=True)
                    clean_value = re.sub(r'[^\d.-]', '', value)
                    if clean_value:
                        form_data[field_name] = clean_value
                        
        except Exception as e:
            print(f"⚠️ Warning: Could not extract dynamic values: {e}")

    def fetch_and_merge_form_data(self, user_overrides: Optional[Dict[str, Any]] = None) -> Optional[Dict[str, str]]:
        """
        Fetch and merge form data synchronously
        
        Args:
            user_overrides: User-specific field overrides
            
        Returns:
            Merged form data or None if failed
        """
        # Fetch base form data
        base_form_data = self.fetch_gatepass_form_data()
        
        if base_form_data is None:
            print("❌ Failed to fetch base form data")
            return None
        
        # Start with base data
        merged_data = base_form_data.copy()
        
        # Apply user overrides
        if user_overrides:
            override_count = 0
            for key, value in user_overrides.items():
                if value is not None and str(value).strip():
                    merged_data[key] = str(value)
                    override_count += 1
            
            print(f"🎯 Applied {override_count} user-specific overrides")
        
        # Ensure critical fields
        self._ensure_critical_fields(merged_data)
        
        return merged_data

    def _ensure_critical_fields(self, form_data: Dict[str, str]):
        """Ensure critical fields have default values"""
        critical_defaults = {
            'ash_utilization': 'Ash_based_Products',
            'pickup_time': '07.00AM - 08.00AM',
            'tps': 'BTPS',
            'vehi_type': '16',
            'qty_fly_ash': '36',
            'vehi_type_oh': 'hired',
            'authorised_person': 'Manjula',
            'dl_no': '9654',
            'generate_flyash_gatepass': ''
        }
        
        for field, default_value in critical_defaults.items():
            if field not in form_data or not form_data[field]:
                form_data[field] = default_value


# Convenience functions for backward compatibility
def fetch_form_data_sync(cookies: Dict[str, str], user_overrides: Optional[Dict[str, Any]] = None) -> Optional[Dict[str, str]]:
    """
    Synchronous function to fetch and merge form data
    
    Args:
        cookies: Session cookies dictionary
        user_overrides: Optional user-specific field overrides
        
    Returns:
        Merged form data dictionary or None if failed
    """
    fetcher = SyncKPCLFormFetcher(cookies)
    return fetcher.fetch_and_merge_form_data(user_overrides)


async def fetch_form_data_async(cookies: Dict[str, str], user_overrides: Optional[Dict[str, Any]] = None) -> Optional[Dict[str, str]]:
    """
    Asynchronous function to fetch and merge form data
    
    Args:
        cookies: Session cookies dictionary
        user_overrides: Optional user-specific field overrides
        
    Returns:
        Merged form data dictionary or None if failed
    """
    fetcher = KPCLFormFetcher(cookies)
    return await fetcher.fetch_and_merge_form_data(user_overrides)


if __name__ == "__main__":
    """
    Test the form fetcher with sample data
    """
    print("🧪 Testing KPCL Form Fetcher")
    print("=" * 50)
    
    # Sample cookies (replace with real session cookies for testing)
    test_cookies = {
        "PHPSESSID": "test_session_id_here"
    }
    
    # Sample user overrides
    test_overrides = {
        "vehicle_no1": "KA36C5418",
        "driver_mob_no1": "9740856523",
        "authorised_person": "Test User"
    }
    
    print("🔄 Testing synchronous fetcher...")
    sync_result = fetch_form_data_sync(test_cookies, test_overrides)
    
    if sync_result:
        print(f"✅ Sync test successful: {len(sync_result)} fields")
    else:
        print("❌ Sync test failed - check cookies and connectivity")
    
    print("\n🔄 Testing asynchronous fetcher...")
    async def test_async():
        async_result = await fetch_form_data_async(test_cookies, test_overrides)
        if async_result:
            print(f"✅ Async test successful: {len(async_result)} fields")
        else:
            print("❌ Async test failed - check cookies and connectivity")
    
    asyncio.run(test_async())
    
    print("\n💡 To use with real data:")
    print("   1. Update cookies with valid PHPSESSID from KPCL website")
    print("   2. Run test_form_fetcher.py for comprehensive testing")
    print("   3. Integrate with scheduler.py or app.py")
