# KPCL OTP Automation System

A Flask web application for automating KPCL (Karnataka Power Corporation Limited) OTP authentication and gatepass submission with hybrid dynamic form fetching.

## 🚀 Features

- **Automated Login Flow**: Web interface for users to login between 6:45-6:55 AM
- **Hybrid Form Fetching**: Combines real-time data from KPCL website with user-specific preferences
- **Scheduled Submission**: Automatically submits gatepasses at 6:59:59 AM daily
- **Multi-user Support**: Support for multiple user sessions
- **Dynamic Data**: Fetches current pricing, balances, and availability from KPCL website

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   User Login    │    │  Form Fetcher   │    │   Scheduler     │
│  (6:45-6:55 AM) │───▶│  (Dynamic Data) │───▶│ (6:59:59 AM)    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ Session Storage │    │ KPCL Website    │    │   Submission    │
│   (Cookies)     │    │  (gatepass.php) │    │ (proof_uploade) │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🛠️ Technology Stack

- **Backend**: Flask (Python)
- **Scheduling**: APScheduler
- **Web Scraping**: BeautifulSoup4, httpx
- **Frontend**: HTML5, JavaScript
- **Deployment**: AWS (EC2 + CloudWatch Events)

## 📋 Setup Instructions

### Local Development

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/kpcl-otp-automation.git
   cd kpcl-otp-automation
   ```

2. **Create virtual environment**
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

3. **Install dependencies**
   ```bash
   pip install -r requirements.txt
   ```

4. **Configure users**
   ```bash
   cp users.json.example users.json
   # Edit users.json with your configuration
   ```

5. **Run the application**
   ```bash
   # For web interface
   python app.py
   
   # For scheduler only
   python scheduler.py
   ```

### Production Deployment (AWS)

See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed AWS deployment instructions.

## 📁 Project Structure

```
kpcl-otp-automation/
├── app.py                   # Flask web application
├── scheduler.py             # Automated scheduler with dynamic data retrieval
├── form_fetcher.py          # Dynamic form data fetching from KPCL website
├── requirements.txt         # Python dependencies
├── users.json.example       # Example user configuration
├── Dockerfile              # Docker configuration for deployment
├── docker-compose.yml       # Local Docker setup
├── .github/workflows/       # GitHub Actions for CI/CD
│   └── deploy.yml
├── aws/                     # AWS deployment scripts
│   ├── cloudformation.yml
│   └── deploy.sh
├── templates/               # HTML templates
│   ├── index.html          # Login page
│   └── gatepass.html       # Gatepass form
├── static/                 # Static assets
├── tests/                  # Test files
└── docs/                   # Documentation
    ├── DEPLOYMENT.md
    └── API.md
```

## ⚡ Quick Start

1. **User Login Window**: Users login between 6:45-6:55 AM to establish fresh sessions
2. **Automatic Processing**: System fetches dynamic data and submits at exactly 6:59:59 AM
3. **Multi-user Support**: Each user can have different vehicle details and preferences

## 🔧 Configuration

### User Configuration (`users.json`)
```json
[
  {
    "username": "your_username",
    "cookies": {
      "PHPSESSID": "session_will_be_updated_on_login"
    },
    "user_form_data": {
      "ash_utilization": "Ash_based_Products",
      "pickup_time": "07.00AM - 08.00AM",
      "vehi_type": "16",
      "vehicle_no1": "KA36C5418",
      "driver_mob_no1": "9740856523"
    }
  }
]
```

## 🚀 Deployment

### AWS Lambda + CloudWatch (Recommended)
- Serverless execution
- Automatic scaling
- Cost-effective for daily runs

### EC2 + Cron
- Full control over environment
- Suitable for complex requirements
- Always-on web interface

### Docker
```bash
docker build -t kpcl-otp-automation .
docker run -p 5000:5000 kpcl-otp-automation
```

## 📊 Monitoring

- **Health Checks**: `/status` endpoint for monitoring
- **Logging**: Comprehensive logging for troubleshooting
- **Alerts**: AWS CloudWatch alerts for failures

## 🔐 Security

- Session cookies are encrypted
- No sensitive data stored in plain text
- HTTPS enforced in production
- Rate limiting implemented

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⚠️ Disclaimer

This tool is for educational and automation purposes. Ensure compliance with KPCL terms of service and applicable regulations.

## 📞 Support

- Create an issue for bug reports
- Discussion forum for questions
- Email: support@yourproject.com

---

**Built with ❤️ for KPCL users**
