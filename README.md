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

The desktop app stores the database in a platform-appropriate directory (see [Backup & Data](#-backup--data)). Development uses `./clientats_dev.db` in the project directory.

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

## 📦 Backup & Data

### Database Location

ClientATS uses SQLite. Your data is stored in a single file:

| Platform | Location |
|----------|----------|
| macOS | `~/Library/Application Support/clientats/db/clientats.db` |
| Linux | `~/.config/clientats/db/clientats.db` |
| Windows | `%APPDATA%/clientats/db/clientats.db` |
| Development | `./clientats_dev.db` (project directory) |

### Backup & Restore

Just copy the database file:
```bash
# Backup
cp ~/Library/Application\ Support/clientats/db/clientats.db ~/my-backup.db

# Restore
cp ~/my-backup.db ~/Library/Application\ Support/clientats/db/clientats.db
```

### Moving to Another Machine

1. Copy your database file to the new machine
2. Place it in the appropriate location for your platform (see table above)
3. Install and run ClientATS - it will use your existing data

### Export & Import (JSON)

ClientATS also supports exporting your data as JSON, which is useful for:
- Sharing data between accounts
- Keeping a human-readable backup
- Migrating data selectively

**Export:** Go to `http://localhost:4000/export` (while logged in) to download a JSON file with all your job interests, applications, resumes, and cover letter templates.

**Import:** Go to `http://localhost:4000/import` to upload a previously exported JSON file. Imported data is added to your existing data (not replaced).

## 🛠️ Development

```bash
# Run tests
mix test

# Reset database (dev only)
mix ecto.reset

# Start with interactive shell
iex -S mix phx.server
```

## 🐛 Troubleshooting

**"Provider not configured"** - Set up an LLM provider in Dashboard → LLM Configuration

**"Connection failed"** - For Ollama, make sure it's running (`ollama serve`). For Gemini, check your API key.

**Port 4000 in use** - Another app is using the port. Find it with `lsof -i :4000` and stop it.

**Database issues** - Reset with `mix ecto.reset` (warning: deletes all data)

## 💡 Tips

- **Use Ollama for frequent requests** - Local execution, no API costs
- **Results are cached** - Re-importing the same URL won't re-process it
- **Don't commit API keys** - Use environment variables if sharing your setup

## 📞 Support & Documentation

- **Phoenix Framework**: https://www.phoenixframework.org/
- **Elixir Docs**: https://hexdocs.pm/elixir/
- **Ecto Guide**: https://hexdocs.pm/ecto/
- **LiveView**: https://hexdocs.pm/phoenix_live_view/

## 📄 License

This project is provided as-is. See LICENSE file for details.

---

**Last Updated:** December 27, 2025
**Version:** 1.0.0-alpha2
**Status:** Alpha
**LLM Providers:** Gemini, Ollama
