# KPCL OTP Project

A Flask web application for automating KPCL (Karnataka Power Corporation Limited) OTP authentication and gatepass submission with **dynamic form data fetching**.

## Features

- **OTP Generation**: Automatically request OTP from KPCL AMS system
- **OTP Verification**: Verify OTP and login to the system
- **Dynamic Gatepass Submission**: Fetches form data dynamically from the KPCL website
- **Automated Scheduling**: Schedule automatic gatepass submissions using APScheduler
- **Multi-user Support**: Support for multiple user sessions
- **Intelligent Form Parsing**: Automatically extracts current form values from the website

## Setup Instructions

### 1. Install Dependencies
```bash
pip install -r requirements.txt
```

### 2. Configure Users
Edit `users.json` to add your user configurations:

```json
[
  {
    "username": "your_username",
    "cookies": {
      "PHPSESSID": "your_actual_session_id"
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
```

**Hybrid Approach:**
- ✅ **Dynamic Base Data** - System fetches current balance amounts, pricing, and other dynamic fields from the website
- ✅ **User-Specific Overrides** - Only the fields in `user_form_data` are overridden with your specific values
- ✅ **Only Referer Header Default** - Only sets `Referer: https://kpcl-ams.com/user/gatepass.php` as per requirement
- ✅ **Best of Both Worlds** - Gets real-time data while maintaining user-specific preferences

**Session Cookie Setup:**
1. Login to KPCL AMS website manually in your browser
2. Open Developer Tools (F12) → Application/Storage → Cookies
3. Copy the `PHPSESSID` value
4. Update `users.json` with the actual session cookie

### 3. Run the Application

#### Web Interface
```bash
python app.py
```
Access the web interface at `http://localhost:5000`

#### Scheduler (for automated submissions)
```bash
python scheduler.py
```
This will schedule automatic gatepass submissions at 06:59:59 AM daily.

## Usage

### Web Interface
1. Navigate to `http://localhost:5000`
2. Enter your password (username is pre-filled)
3. Click "Get OTP" to request an OTP
4. Enter the received OTP and click "Login"
5. Fill out the gatepass form and submit

### Scheduler
The scheduler runs in the background and automatically submits gatepasses for all configured users at 06:59:59 AM daily.

## File Structure

```
kpcl_otp_project/
├── app.py                   # Flask web application with dynamic form fetching
├── scheduler.py             # Automated scheduler with dynamic data retrieval  
├── form_fetcher.py          # Dynamic form data fetching from KPCL website
├── test_form_fetcher.py     # Test script for form fetching functionality
├── requirements.txt         # Python dependencies (includes beautifulsoup4)
├── users.json              # User configuration (cookies only, no static form data)
├── curl_analysis.py        # cURL command analysis tool
├── cleanup.py              # Session cleanup utility
├── validate.py             # Configuration validator
├── test_template.py        # Template testing utility
├── README.md               # This file
├── CURL_INTEGRATION.md     # cURL integration documentation
├── templates/              # HTML templates
│   ├── index.html          # Login page
│   ├── gatepass.html       # Gatepass form
│   └── form.html           # Alternative form template
├── static/                 # Static files (empty)
├── sessions/               # Session storage (empty)
└── .vscode/                # VS Code configuration
    └── tasks.json          # Task runner configuration
```

## API Endpoints

- `GET /` - Main login page
- `GET /status` - Server status check
- `POST /generate-otp` - Request OTP
- `POST /verify-otp` - Verify OTP and login
- `GET /gatepass` - Gatepass form page
- `POST /submit-gatepass` - Submit gatepass form

## Configuration

### Environment Variables
- Set `FLASK_ENV=development` for development mode
- Set `FLASK_DEBUG=1` for debug mode

### Security Notes
- Change the `app.secret_key` in `app.py` for production
- Ensure `users.json` contains valid session cookies
- Keep user credentials secure

## Troubleshooting

### Common Issues

1. **Missing dependencies**: Run `pip install -r requirements.txt`
2. **Invalid cookies**: Obtain fresh cookies from a valid login session
3. **Connection errors**: Check network connectivity to KPCL AMS system
4. **JSON errors**: Validate `users.json` format

### Logging
The scheduler provides detailed logging:
- ✔ Success with timing information
- ❌ Error messages with details
- ⚠ Warnings for non-200 status codes

## Development

### VS Code Tasks
Use the configured VS Code tasks:
- **Install Dependencies**: `Ctrl+Shift+P` → "Tasks: Run Task" → "Install Dependencies"
- **Run Flask App**: `Ctrl+Shift+P` → "Tasks: Run Task" → "Run Flask App"
- **Run Scheduler**: `Ctrl+Shift+P` → "Tasks: Run Task" → "Run Scheduler"

## License

This project is for educational and automation purposes. Please ensure compliance with KPCL terms of service.

## Dynamic Form Data Fetching with User Overrides

### How It Works
The system uses a hybrid approach combining dynamic fetching with user-specific overrides:

1. **Dynamic Base**: Connects to `https://kpcl-ams.com/user/gatepass.php` using authenticated session
2. **HTML Parsing**: Extracts all current form fields, hidden inputs, and dynamic values from the website
3. **User Overrides**: Applies only the specific fields defined in `user_form_data` for each user
4. **Smart Merging**: Preserves real-time data while using user preferences for specific fields

### Only Referer Header
As per your requirement, only the `Referer: https://kpcl-ams.com/user/gatepass.php` header is set by default. All other data comes from the website or user overrides.

### Benefits
- ✅ **Real-time Dynamic Data**: Gets latest pricing, balances, and availability from the website
- ✅ **User-Specific Control**: Override only the fields you need (vehicle info, timing, etc.)
- ✅ **Minimal Configuration**: No need to maintain all form fields manually
- ✅ **Authentic Submission**: Uses the same data flow as manual website usage

### User Override Fields
The following fields can be customized per user in `user_form_data`:
- `ash_utilization`, `pickup_time`, `silo_name`, `silo_no`, `tps`
- `vehi_type`, `qty_fly_ash`, `vehi_type_oh`, `authorised_person`
- `vehicle_no`, `dl_no`, `driver_mob_no`, `vehicle_no1`, `driver_mob_no1`
- `generate_flyash_gatepass`

### Testing Form Fetching
```bash
python test_form_fetcher.py
```

This will:
- Test connection to KPCL website with your session cookies
- Show dynamic fields fetched from the website
- Apply user-specific overrides
- Display the final merged form data that will be submitted
