#!/usr/bin/env python3
"""
Comparison of cURL form data with project configuration
"""

import json

# cURL form data from the command
curl_form_data = {
    'ash_price': '150',
    'balance_amount': '18078.489999999998',
    'total_extra': '1146.89',
    'gp_flag': '',
    'full_flyash': '50',
    'extra_flyash': '1.47',
    'ash_utilization': 'Ash_based_Products',
    'pickup_time': '07.00AM - 08.00AM',
    'silo_name': '',
    'silo_no': '',
    'tps': 'BTPS',
    'vehi_type': '16',
    'qty_fly_ash': '36',
    'vehi_type_oh': 'hired',
    'authorised_person': 'Manjula ',  # Note: has trailing space
    'vehicle_no': '',
    'dl_no': '9654',
    'driver_mob_no': '',
    'vehicle_no1': 'KA36C5418',
    'dl_no': '9654',  # Duplicate field
    'driver_mob_no1': '9740856523',
    'generate_flyash_gatepass': ''
}

# Load current users.json form_data
try:
    with open('users.json', 'r') as f:
        users = json.load(f)
    project_form_data = users[0]['form_data']
except:
    project_form_data = {}

print("🔍 CURL vs PROJECT FORM DATA COMPARISON\n")
print(f"{'Field':<25} {'cURL Value':<25} {'Project Value':<25} {'Status'}")
print("="*85)

all_fields = set(curl_form_data.keys()) | set(project_form_data.keys())

matches = 0
total_fields = len(all_fields)

for field in sorted(all_fields):
    curl_val = curl_form_data.get(field, 'MISSING')
    project_val = project_form_data.get(field, 'MISSING')
    
    if curl_val == project_val:
        status = "✅ MATCH"
        matches += 1
    elif curl_val == 'MISSING':
        status = "➕ EXTRA (project)"
    elif project_val == 'MISSING':
        status = "❌ MISSING (project)"
    else:
        status = "⚠️  DIFFER"
    
    print(f"{field:<25} {str(curl_val):<25} {str(project_val):<25} {status}")

print("="*85)
print(f"📊 Summary: {matches}/{total_fields} fields match ({matches/total_fields*100:.1f}%)")

# Show missing fields in project
missing_in_project = set(curl_form_data.keys()) - set(project_form_data.keys())
if missing_in_project:
    print(f"\n❌ Missing in project: {', '.join(missing_in_project)}")

# Show extra fields in project  
extra_in_project = set(project_form_data.keys()) - set(curl_form_data.keys())
if extra_in_project:
    print(f"➕ Extra in project: {', '.join(extra_in_project)}")

print("\n💡 RECOMMENDATIONS:")
if missing_in_project:
    print("- Add missing fields to users.json form_data")
if 'Manjula ' in curl_form_data.get('authorised_person', ''):
    print("- Note: cURL has trailing space in 'authorised_person'")
if curl_form_data.get('dl_no') == project_form_data.get('dl_no'):
    print("- cURL has duplicate 'dl_no' field - this might be intentional")
