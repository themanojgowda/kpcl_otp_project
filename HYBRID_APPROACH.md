# Hybrid Dynamic Form Fetching Documentation

## Overview

The KPCL OTP Project now uses a **hybrid approach** that combines:
- **Dynamic data fetching** from the KPCL website for real-time values
- **User-specific overrides** for fields that need to be customized per user

## Implementation Details

### Request Headers
As per the requirement, only the `Referer` header is set by default:
```
Referer: https://kpcl-ams.com/user/gatepass.php
```

All other headers and data are either:
- Fetched dynamically from the website
- Provided through user-specific configuration

### Form Data Flow

```
┌─────────────────────┐
│ KPCL Website        │
│ gatepass.php        │ ──┐
└─────────────────────┘   │
                          │ Dynamic Fetch
                          ▼
┌─────────────────────┐   ┌─────────────────────┐
│ User Configuration  │   │ Form Data Merger    │
│ user_form_data      │──▶│ (form_fetcher.py)   │
└─────────────────────┘   └─────────────────────┘
                                    │
                                    ▼
                          ┌─────────────────────┐
                          │ Final Form Data     │
                          │ for Submission      │
                          └─────────────────────┘
                                    │
                                    ▼
                          ┌─────────────────────┐
                          │ POST to             │
                          │ proof_uploade_code  │
                          └─────────────────────┘
```

### User-Specific Override Fields

Based on your cURL example, these fields are configurable per user:

| Field | Example Value | Description |
|-------|---------------|-------------|
| `ash_utilization` | "Ash_based_Products" | Purpose of ash utilization |
| `pickup_time` | "07.00AM - 08.00AM" | Pickup timing slot |
| `silo_name` | "" | Silo name (usually empty) |
| `silo_no` | "" | Silo number (usually empty) |
| `tps` | "BTPS" | Thermal Power Station |
| `vehi_type` | "16" | Vehicle type (16-wheeler) |
| `qty_fly_ash` | "36" | Quantity of fly ash |
| `vehi_type_oh` | "hired" | Vehicle ownership (own/hired) |
| `authorised_person` | "Manjula " | Authorized person name |
| `vehicle_no` | "" | Own vehicle number |
| `dl_no` | "9654" | Driver license number |
| `driver_mob_no` | "" | Own vehicle driver mobile |
| `vehicle_no1` | "KA36C5418" | Hired vehicle number |
| `driver_mob_no1` | "9740856523" | Hired vehicle driver mobile |
| `generate_flyash_gatepass` | "" | Form submission trigger |

### Dynamic Fields (Fetched from Website)

These fields are automatically extracted from the KPCL website:
- `ash_price` - Current ash pricing
- `balance_amount` - User's current balance
- `total_extra` - Additional charges
- `full_flyash` - Full flyash quantity limits
- `extra_flyash` - Extra flyash calculations
- `gp_flag` - Gatepass flags
- Hidden form tokens and CSRF protection
- Session-specific values

## Configuration Example

```json
{
  "username": "1901981",
  "cookies": {
    "PHPSESSID": "actual_session_id_from_browser"
  },
  "user_form_data": {
    "ash_utilization": "Ash_based_Products",
    "pickup_time": "07.00AM - 08.00AM",
    "tps": "BTPS",
    "vehi_type": "16",
    "qty_fly_ash": "36",
    "vehi_type_oh": "hired",
    "authorised_person": "Manjula ",
    "vehicle_no1": "KA36C5418",
    "dl_no": "9654",
    "driver_mob_no1": "9740856523"
  }
}
```

## Benefits of This Approach

### ✅ Advantages
1. **Real-time Data**: Always uses current pricing and balance information
2. **User Flexibility**: Each user can have different vehicle details, timing preferences
3. **Minimal Headers**: Only sets the required `Referer` header
4. **Authentic Flow**: Mimics actual website behavior
5. **Maintenance Free**: Adapts to website changes automatically

### 🔄 Data Freshness
- **Dynamic fields**: Updated every time a request is made
- **User fields**: Remain constant until manually changed
- **Session data**: Preserved from login session

## Error Handling

The system handles various scenarios:
- **Network errors**: Timeout and connection error handling
- **Authentication issues**: Session cookie validation
- **Missing fields**: Smart defaults for required fields
- **Website changes**: Graceful degradation when structure changes

## Testing

Use the test script to validate the configuration:
```bash
python test_form_fetcher.py
```

This will show:
1. Dynamic fields fetched from the website
2. User overrides being applied
3. Final merged form data
4. Field-by-field comparison with expected values

## Troubleshooting

### Common Issues
1. **No dynamic data fetched**: Check session cookies validity
2. **Override not applied**: Verify `user_form_data` field names
3. **Authentication errors**: Refresh PHPSESSID cookie
4. **Missing required fields**: Check website structure changes

### Debug Information
The system provides detailed logging:
- `📋 Using X form fields (dynamic + user overrides)`
- `🔄 Applying X user-specific overrides`
- `✏️ Overriding field: 'old_value' → 'new_value'`
- `➕ Adding field: 'new_value'`
