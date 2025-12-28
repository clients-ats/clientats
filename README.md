# Clientats - Job Scraping & Management Platform

A Phoenix-based application for intelligent job posting scraping, data extraction, and job interest tracking using multiple LLM providers.

**Available as both a web application and standalone desktop app** for macOS, Windows, and Linux.

## 🎯 Features

### Job Scraping & Extraction
- **Intelligent URL-based scraping** - Extract job details from URLs using AI-powered vision models
- **Multiple extraction modes** - Support for both specific job boards and generic content
- **Screenshot-based analysis** - Uses browser screenshots for accurate visual information capture
- **Smart fallback chain** - Automatically tries multiple LLM providers if one fails
- **Cached results** - Avoids re-processing the same URLs

### LLM Provider Support
- **Google Gemini** - Cloud-based multi-modal support with free tier and fast inference
- **Ollama** - Local, privacy-focused model execution (runs on your machine)

### Job Interest Management
- **Track job opportunities** - Save and organize job postings you're interested in
- **Detailed job data** - Company, position, location, salary, work model, description
- **Status tracking** - Interested, Researching, Not a Fit, Ready to Apply, Applied
- **Priority levels** - High, Medium, Low priority organization
- **Notes & annotations** - Add personal notes and observations

### Configuration Management
- **Multi-provider setup** - Configure multiple LLM providers simultaneously
- **Connection testing** - Verify provider connectivity before use
- **User-scoped settings** - Each user has independent provider configurations
- **Secure API key storage** - Plain-text storage in database (can be extended to use environment variables)
- **Model customization** - Set default, vision, and text models per provider

### User Authentication
- **Secure account system** - Email-based registration and login
- **Session management** - Persistent sessions with logout
- **User profile data** - First name, last name, email tracking

## 📋 Supported Job Boards

The application works with many major job boards including:
- LinkedIn
- Indeed
- Glassdoor
- AngelList
- Lever
- Greenhouse
- Workday
- And many more generic job posting sites

## 💻 Desktop Application

**Prefer a desktop app?** ClientATS is available as a standalone desktop application:

- **Download pre-built apps** from [GitHub Actions artifacts](../../actions) or [Releases](../../releases)
- **Supported platforms**: macOS (Intel + Apple Silicon), Windows, Linux
- **Fully self-contained**: No dependencies, embedded database, works offline
- **See the [Tauri documentation](docs/TAURI.md)** for installation and build instructions

## 🚀 Quick Start (Web Development)

### Prerequisites
- Elixir 1.19.4+
- Erlang/OTP 26.0+
- SQLite 3
- Node.js 18+ (for assets)

### Installation

1. **Clone the repository**
```bash
git clone <repository-url>
cd clientats
```

2. **Install dependencies**
```bash
mix setup
```

This will:
- Install Hex dependencies
- Create the SQLite database
- Run database migrations
- Compile the application

3. **Start the development server**
```bash
mix phx.server
```

**Note:** Database migrations run automatically on startup, so you don't need to run `mix ecto.migrate` manually. The application will ensure your database schema is always up to date.

4. **Access the application**
Open your browser and navigate to `http://localhost:4000`

### Initial Setup

1. **Create an account**
   - Click "Sign up" on the login page
   - Enter your email, password, first name, and last name
   - Verify your account

2. **Configure LLM provider**
   - Go to Dashboard → LLM Configuration
   - Choose **Gemini** (easiest, free tier available) OR **Ollama** (local, completely free)
   - See the [LLM Provider Setup Guide](#-llm-provider-setup-guide) below for detailed steps
   - After setup, click "Test Connection" to verify
   - Click "Save Configuration"

3. **Start importing jobs**
   - Go to Dashboard → Job Interests → "Add Interest"
   - Click "Import from URL"
   - Paste a job posting URL
   - Review extracted data
   - Save the job interest

## ⚙️ Configuration

### Environment Variables

Create a `.env` file or set environment variables:

```bash
# Database (optional - uses platform-specific location if not set)
# Linux: ~/.config/clientats/db/clientats.db
# macOS: ~/Library/Application Support/clientats/db/clientats.db
# Windows: %APPDATA%/clientats/db/clientats.db
DATABASE_PATH=/custom/path/clientats.db  # Override default location

# Phoenix
SECRET_KEY_BASE=<generated-secret>
PHX_HOST=localhost
PHX_PORT=4000

# LLM Encryption (optional)
LLM_ENCRYPTION_KEY=<your-encryption-key>
```

**Note:** In production, the database will automatically be stored in a platform-appropriate directory unless `DATABASE_PATH` is explicitly set. Development and test environments use local database files in the project directory.

### 🚀 LLM Provider Setup Guide

Clientats supports two powerful LLM providers. Choose one or configure both for enhanced flexibility!

#### Option 1: Google Gemini (Recommended for Getting Started)

**Why choose Gemini?**
- ✅ Free tier available (no credit card required)
- ✅ Fast inference
- ✅ Great multi-modal capabilities
- ✅ Easiest to set up

**Setup Steps:**

1. **Get API Key**
   - Visit https://aistudio.google.com/apikey
   - Click "Create API Key"
   - Copy your API key

2. **Configure in Clientats**
   - Go to Dashboard → LLM Configuration
   - Click the **Gemini** tab
   - Enable the provider with the checkbox
   - Paste your API key
   - Keep the default models:
     - Default Model: `gemini-2.0-flash`
     - Vision Model: `gemini-2.0-flash`
     - Text Model: `gemini-2.0-flash`

3. **Test Connection**
   - Click "Test Connection" button
   - You should see a success message
   - Click "Save Configuration"

**Screenshot:**
![Gemini Setup](docs/screenshots/gemini-setup.png)

**Video Demo:**
[Watch the LLM Setup Demo](docs/llm-setup-demo.mp4)

---

#### Option 2: Ollama (Local & Private)

**Why choose Ollama?**
- 🔒 Runs locally - complete privacy, no internet required
- 💰 Completely free
- ⚡ Fast for inference
- 🎮 Great for development and testing
- ⚙️ Full control over models

**Prerequisites:**
- Install Ollama from https://ollama.ai

**Setup Steps:**

1. **Install and Run Ollama**
   ```bash
   # On macOS/Linux/Windows, install from https://ollama.ai
   # Start Ollama (it runs in background)
   ollama serve
   ```

2. **Pull a Model**
   In another terminal:
   ```bash
   # Pull a model (one-time download)
   ollama pull llama3.2
   ```

3. **Configure in Clientats**
   - Go to Dashboard → LLM Configuration
   - Click the **Ollama** tab
   - Enable the provider with the checkbox
   - Base URL should be: `http://localhost:11434` (default)
   - Click "Discover Models" button
   - Select models from the dropdowns that appear
   - Click "Save Configuration"

4. **Test Connection**
   - Click "Test Connection" button
   - You should see a success message

**Screenshot:**
![Ollama Setup](docs/screenshots/ollama-setup.png)

---

#### Using Both Providers

You can configure both Gemini and Ollama! The system will:
- Use the first enabled provider
- Automatically fall back to another if the first one fails
- Give you maximum flexibility

**Recommended Setup for Production:**
```
Primary: Gemini (fast, reliable)
Fallback: Ollama (local backup if Gemini is down)
```

---

### LLM Provider Configuration Reference

#### Google Gemini
```
API Key: From https://aistudio.google.com/apikey
Default Model: gemini-2.0-flash
Vision Model: gemini-2.0-flash (for image analysis)
Text Model: gemini-2.0-flash (for text-only tasks)
Cost: Free tier available, paid tiers for higher usage
```

#### Ollama (Local)
```
Base URL: http://localhost:11434
Models: llama3.2, llama3.1, gemma2, etc.
Default Model: Select after running "Discover Models"
Cost: Completely free
Privacy: 100% local, no data sent anywhere
```

## 📦 Backup & Restore

### Database Backup

#### Manual SQLite Backup
Since ClientATS uses SQLite, backing up is as simple as copying the database file.

**Development:**
```bash
# Create a backup (development database in project directory)
cp clientats_dev.db backups/clientats_dev_backup.db

# Restore from backup
cp backups/clientats_dev_backup.db clientats_dev.db
```

**Production:**
```bash
# Find your database location (platform-specific)
# Linux: ~/.config/clientats/db/clientats.db
# macOS: ~/Library/Application Support/clientats/db/clientats.db
# Windows: %APPDATA%/clientats/db/clientats.db

# Create a backup (Linux example)
cp ~/.config/clientats/db/clientats.db backups/clientats_backup_$(date +%Y%m%d_%H%M%S).db

# Or use DATABASE_PATH if you set a custom location
cp $DATABASE_PATH backups/clientats_backup_$(date +%Y%m%d_%H%M%S).db

# Restore from backup
cp backups/clientats_backup_20240101_120000.db ~/.config/clientats/db/clientats.db
```

#### Full Application Backup
```bash
# Backup database and configuration
mkdir -p backups
cp clientats_dev.db backups/clientats_$(date +%Y%m%d_%H%M%S).db

# Backup configuration files
cp -r config/runtime.exs backups/
```

### Restore from Backup

#### Restore Database
```bash
# Simply copy the backup file to the database location
# Development:
cp backups/clientats_backup_20240101_120000.db clientats_dev.db

# Production (Linux example):
cp backups/clientats_backup_20240101_120000.db ~/.config/clientats/db/clientats.db

# Restart application
mix phx.server
```

#### Restore Configuration
```bash
# Restore config files
cp backups/runtime.exs config/

# Restart application
mix phx.server
```

### Automated Backups

Create a backup script (e.g., `backup.sh`):
```bash
#!/bin/bash
BACKUP_DIR="/path/to/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Platform-specific database location
# Linux: ~/.config/clientats/db/clientats.db
# macOS: ~/Library/Application Support/clientats/db/clientats.db
DB_PATH="${DATABASE_PATH:-$HOME/.config/clientats/db/clientats.db}"

mkdir -p $BACKUP_DIR

# Database backup (simple file copy)
cp "$DB_PATH" "$BACKUP_DIR/db_${TIMESTAMP}.db"

# Keep only last 7 days of backups
find $BACKUP_DIR -name "db_*.db" -mtime +7 -delete

echo "Backup completed: $BACKUP_DIR/db_${TIMESTAMP}.db"
```

Schedule with cron:
```bash
0 2 * * * /path/to/backup.sh
```

## 🛠️ Development

### Running Tests
```bash
# Run all tests
mix test

# Run specific test file
mix test test/clientats/llm_config_test.exs

# Run with coverage
mix coveralls
```

### Database Migrations

**Note:** Migrations run automatically on application startup, so you typically don't need to run them manually. However, these commands are available for development tasks:

```bash
# Create new migration
mix ecto.gen.migration migration_name

# Run migrations manually (optional - they run automatically on startup)
mix ecto.migrate

# Rollback last migration
mix ecto.rollback

# Reset database (dev only)
mix ecto.reset
```

### Code Quality
```bash
# Format code
mix format

# Check for unused variables
mix credo

# Run linter
mix dialyzer
```

### Debugging
```bash
# Start with IEx
iex -S mix phx.server

# Query database interactively
iex> import Ecto.Query
iex> Clientats.Repo.all(Clientats.LLM.Setting)
```

## 📊 Project Structure

```
clientats/
├── lib/
│   ├── clientats/              # Core application logic
│   │   ├── llm/                # LLM integration
│   │   │   ├── service.ex      # Main extraction service
│   │   │   ├── error_handler.ex # Error handling & retry logic
│   │   │   ├── cache.ex        # Result caching
│   │   │   └── providers/      # Provider implementations
│   │   ├── jobs/               # Job interest management
│   │   ├── accounts/           # User authentication
│   │   └── browser.ex          # Browser automation
│   └── clientats_web/          # Web interface
│       ├── live/               # LiveView components
│       ├── controllers/        # HTTP controllers
│       └── templates/          # HTML templates
├── priv/
│   └── repo/migrations/        # Database migrations
├── test/                       # Test suite
├── config/                     # Configuration files
└── README.md                   # This file
```

## 🔧 API Endpoints

### Job Interests
- `GET /dashboard/job-interests` - List all job interests
- `GET /dashboard/job-interests/:id` - View job interest details
- `POST /dashboard/job-interests` - Create new job interest
- `PUT /dashboard/job-interests/:id` - Update job interest
- `DELETE /dashboard/job-interests/:id` - Delete job interest

### LLM Configuration
- `GET /dashboard/llm-config` - View configuration page
- `POST /dashboard/llm-config/save` - Save provider configuration
- `POST /dashboard/llm-config/test` - Test provider connection

### Job Scraping
- `GET /dashboard/job-interests/scrape` - Import from URL page
- `POST /dashboard/job-interests/scrape` - Process URL import

## 🐛 Troubleshooting

### Common Issues

**"Provider not configured" error**
- Ensure you've set up at least one LLM provider
- Check that the provider is enabled in LLM Configuration
- Verify API key is entered (if required)

**"Connection failed" error**
- For Ollama: Verify it's running on http://localhost:11434
- For cloud providers: Check API key is valid
- Test internet connectivity

**Screenshot extraction fails**
- Ensure browser is properly configured
- Check disk space for temporary screenshots
- Verify JavaScript is enabled in browser

**Database connection error**
```bash
# Verify database file exists
ls -la clientats_dev.db  # Development
ls -la ~/.config/clientats/db/clientats.db  # Production (Linux)

# Check database integrity
sqlite3 clientats_dev.db "PRAGMA integrity_check;"

# Reset database if needed
mix ecto.reset
```

**"Port 4000 already in use"**
```bash
# Find process using port 4000
lsof -i :4000

# Kill process if needed
kill -9 <PID>
```

## 📝 API Key Recommendations

### Security Best Practices
1. **Never commit API keys** - Use environment variables
2. **Rotate keys regularly** - Change keys every 90 days
3. **Use least privilege** - Only enable necessary scopes
4. **Monitor usage** - Watch for unusual API activity
5. **Backup securely** - Encrypt backup files containing keys

### Cost Optimization
- **Ollama** - Free, runs locally (requires GPU for fast inference)
- **Google Gemini** - Free tier available with rate limits, paid tiers for higher usage

## 📈 Performance Tips

1. **Use Ollama for frequent requests** - Local execution, no API costs
2. **Cache results** - Application automatically caches extraction results
3. **Batch operations** - Import multiple URLs in sequence
4. **Monitor LLM tokens** - Some providers charge per token
5. **Optimize screenshots** - Larger screenshots = higher LLM costs

## 🔒 Security Considerations

1. **Database encryption** - Consider encrypting sensitive database columns
2. **API key management** - Use environment variables, never hardcode
3. **Session timeouts** - Configure appropriate session expiration
4. **HTTPS in production** - Always use TLS for deployed applications
5. **Input validation** - URLs and content are validated before processing

## 📞 Support & Documentation

- **Phoenix Framework**: https://www.phoenixframework.org/
- **Elixir Docs**: https://hexdocs.pm/elixir/
- **Ecto Guide**: https://hexdocs.pm/ecto/
- **LiveView**: https://hexdocs.pm/phoenix_live_view/

## 📄 License

This project is provided as-is. See LICENSE file for details.

## 🚀 Deployment

### Production Checklist
- [ ] Set strong `SECRET_KEY_BASE`
- [ ] (Optional) Configure `DATABASE_PATH` if not using default platform directory
- [ ] Set up LLM provider keys in environment variables
- [ ] Enable HTTPS/TLS
- [ ] Configure backup strategy
- [ ] Set up monitoring and logging
- [ ] Test all LLM providers
- [ ] Create database backups before deploying

**Notes:**
- The database will automatically be stored in a platform-specific directory (e.g., `~/.config/clientats/db/` on Linux) unless `DATABASE_PATH` is explicitly set.
- The Phoenix server is **enabled by default** in production mode. To disable, set `PHX_SERVER=false`.
- Database migrations run automatically on startup.

### Docker Deployment
See `Dockerfile` for containerized deployment instructions.

### Cloud Platforms
The application can be deployed to:
- DigitalOcean App Platform
- AWS (ECS, Elastic Beanstalk)
- Google Cloud Run
- Any platform supporting Elixir/Phoenix

**Note:** Since ClientATS uses SQLite (file-based database), ensure your deployment platform supports persistent storage for the database file.

---

**Last Updated:** December 27, 2025
**Version:** 1.0.0-alpha2
**Status:** Alpha
**LLM Providers:** Gemini, Ollama
