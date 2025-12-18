# End-to-End Testing Guide for ClientATS

This guide provides instructions for manual end-to-end (E2E) testing of the ClientATS application.

## Overview

ClientATS has three main areas for E2E testing:

1. **User Authentication & Dashboard** - User registration, login, session management
2. **Job Interest Management** - Creating, editing, viewing job interests, web scraping
3. **Database & Health Checks** - Connection pooling, health endpoints

## Prerequisites

### Local Setup

```bash
# Start Docker services
docker-compose up -d

# Create and migrate database
mix ecto.create
mix ecto.migrate

# Start development server
mix phx.server
```

Application runs on http://localhost:4000

### Optional Services

For full LLM testing:
```bash
docker-compose --profile llm up -d
# Then pull a model: ollama pull mistral
```

## Test Scenarios

### 1. Authentication & Registration

#### Test Case 1.1: User Registration

**Steps:**
1. Navigate to http://localhost:4000
2. Click "Register"
3. Fill in form:
   - Email: `test@example.com`
   - Password: `SecurePassword123!`
   - Confirm Password: `SecurePassword123!`
4. Click "Sign up"

**Expected Result:**
- ✅ User created successfully
- ✅ Redirected to dashboard
- ✅ User email shown in nav bar
- ✅ Session cookie set (check browser DevTools)

#### Test Case 1.2: User Login

**Steps:**
1. Navigate to http://localhost:4000/login
2. Enter email: `test@example.com`
3. Enter password: `SecurePassword123!`
4. Click "Sign in"

**Expected Result:**
- ✅ Logged in successfully
- ✅ Redirected to dashboard
- ✅ Session established
- ✅ Logout option available

#### Test Case 1.3: Invalid Credentials

**Steps:**
1. Navigate to http://localhost:4000/login
2. Enter email: `test@example.com`
3. Enter password: `WrongPassword`
4. Click "Sign in"

**Expected Result:**
- ✅ Error message displayed
- ✅ Not logged in
- ✅ Remains on login page

#### Test Case 1.4: Logout

**Steps:**
1. Login (from Test 1.2)
2. Click "Logout"

**Expected Result:**
- ✅ Session cleared
- ✅ Redirected to home page
- ✅ Cannot access dashboard without login

#### Test Case 1.5: Protected Routes

**Steps:**
1. Navigate to http://localhost:4000/dashboard (without logging in)

**Expected Result:**
- ✅ Redirected to login page
- ✅ Cannot access dashboard anonymously

---

### 2. Dashboard & Job Interests

#### Test Case 2.1: Dashboard Access

**Steps:**
1. Login with valid credentials
2. View dashboard

**Expected Result:**
- ✅ Dashboard loads with user info
- ✅ Quick links visible (New Interest, Resumes, Applications, etc.)
- ✅ Navigation menu accessible
- ✅ Profile icon in top nav

#### Test Case 2.2: Create Job Interest Manually

**Steps:**
1. From dashboard, click "New Interest"
2. Fill in form:
   - Job Title: "Senior Backend Engineer"
   - Company: "Tech Corp"
   - Description: "Building scalable systems"
   - Salary Min: "120000"
   - Salary Max: "160000"
   - Location: "San Francisco, CA"
3. Click "Save Interest"

**Expected Result:**
- ✅ Interest created successfully
- ✅ Success message displayed
- ✅ Redirected to job interest list
- ✅ New interest visible in list

#### Test Case 2.3: Edit Job Interest

**Steps:**
1. Click on a job interest from the list
2. Click "Edit"
3. Modify the description
4. Click "Save"

**Expected Result:**
- ✅ Changes saved
- ✅ Updated interest displayed
- ✅ Timestamps updated

#### Test Case 2.4: View Job Interest Details

**Steps:**
1. Click on a job interest
2. View full details

**Expected Result:**
- ✅ All details displayed correctly
- ✅ Edit/delete buttons available
- ✅ Timestamps shown

---

### 3. Web Scraping (If Ollama Available)

#### Test Case 3.1: Scrape Job from LinkedIn

**Steps:**
1. From dashboard, click "Scrape Job"
2. Enter a LinkedIn job posting URL (example):
   ```
   https://www.linkedin.com/jobs/view/1234567890/
   ```
3. Click "Scrape"
4. Wait for completion

**Expected Result:**
- ✅ Page shows "Scraping..." progress
- ✅ ETA displayed
- ✅ Job data extracted
- ✅ Form populated with job details
- ✅ Can review and save

#### Test Case 3.2: Manual Job Entry Fallback

**Steps:**
1. From scrape page, click "Can't find it? Enter manually"
2. Fill in job details:
   - Title: "Product Manager"
   - Company: "StartupXYZ"
   - Description: "Lead product strategy"
   - Salary: "$150,000 - $200,000"
   - Location: "Austin, TX"
3. Click "Save"

**Expected Result:**
- ✅ Job interest created
- ✅ All fields saved correctly
- ✅ Visible in job interest list

#### Test Case 3.3: Error Handling

**Steps:**
1. From scrape page, enter invalid URL:
   ```
   https://example.com/not-a-job
   ```
2. Click "Scrape"
3. Wait for error

**Expected Result:**
- ✅ Error message displayed
- ✅ Fallback to manual entry offered
- ✅ User can proceed manually

---

### 4. LLM Configuration

#### Test Case 4.1: Access LLM Settings

**Steps:**
1. From dashboard, click "Settings" or "LLM Config"
2. View available providers

**Expected Result:**
- ✅ All providers listed (OpenAI, Anthropic, Mistral, Gemini, Ollama)
- ✅ Configuration form displays
- ✅ API key field is hidden (password type)

#### Test Case 4.2: Configure Ollama (Local)

**Prerequisites:**
- Ollama running: `docker-compose --profile llm up`
- Model downloaded: `ollama pull mistral`

**Steps:**
1. Navigate to LLM Config
2. Click "Ollama" tab
3. Enter Base URL: `http://localhost:11434`
4. Click "Discover Models"
5. Wait for models to load
6. Select a model
7. Click "Test Connection"

**Expected Result:**
- ✅ Models discovered and displayed
- ✅ Connection test succeeds
- ✅ Success message shown

#### Test Case 4.3: Test Connection

**Steps:**
1. Configure any provider with valid API key
2. Click "Test Connection"
3. Wait for result

**Expected Result:**
- ✅ Connection test succeeds/fails appropriately
- ✅ Status message displayed
- ✅ Can save configuration

---

### 5. Database & Health Checks

#### Test Case 5.1: Simple Health Check

**Steps:**
1. From terminal, run:
   ```bash
   curl http://localhost:4000/health
   ```

**Expected Result:**
```json
{"status":"ok","timestamp":"2025-12-16T12:00:00Z"}
```

**Status Code:** 200 OK

#### Test Case 5.2: Database Ready Check

**Steps:**
1. From terminal, run:
   ```bash
   curl http://localhost:4000/health/ready
   ```

**Expected Result:**
```json
{
  "status":"healthy",
  "database":{"status":"healthy","latency_ms":2},
  "timestamp":"2025-12-16T12:00:00Z"
}
```

**Status Code:** 200 OK (or 503 if database down)

#### Test Case 5.3: Diagnostics (Authenticated)

**Steps:**
1. Set health token:
   ```bash
   export HEALTH_CHECK_TOKEN="test-token-123"
   ```
2. Run:
   ```bash
   curl -H "Authorization: Bearer test-token-123" \
     http://localhost:4000/health/diagnostics
   ```

**Expected Result:**
```json
{
  "status":"healthy",
  "database":{"status":"healthy","latency_ms":2},
  "pool":{
    "pool_size":10,
    "pool_count":1,
    "max_overflow":2,
    "timeout_ms":5000,
    "database_version":"PostgreSQL 15..."
  },
  "activity":{
    "total_connections":5,
    "active_connections":2,
    ...
  },
  "performance_insights":[...]
}
```

#### Test Case 5.4: Metrics Endpoint

**Steps:**
1. Navigate to http://localhost:4000/metrics

**Expected Result:**
- ✅ Prometheus-format metrics displayed
- ✅ Database query metrics visible
- ✅ HTTP request metrics shown

---

### 6. Resumes & Cover Letters

#### Test Case 6.1: Upload Resume

**Steps:**
1. From dashboard, click "Resumes"
2. Click "Add Resume"
3. Click file input and select a PDF
4. Enter name: "John Doe - Senior Backend"
5. Click "Upload"

**Expected Result:**
- ✅ File uploaded successfully
- ✅ Resume listed
- ✅ Download link available

#### Test Case 6.2: Create Cover Letter Template

**Steps:**
1. From dashboard, click "Cover Letters"
2. Click "New Template"
3. Enter template name: "Tech Company Template"
4. Fill in template:
   ```
   Dear [Company],

   I am interested in the [Position] role...
   ```
5. Click "Save"

**Expected Result:**
- ✅ Template created
- ✅ Listed in templates
- ✅ Can be edited/deleted

---

### 7. Job Applications Tracking

#### Test Case 7.1: Create Application Record

**Steps:**
1. From dashboard, click "Applications"
2. Click "New Application"
3. Fill in:
   - Job Interest: Select from list
   - Status: "Applied"
   - Date Applied: Today
   - Resume Used: Select from list
   - Notes: "Applied via LinkedIn"
4. Click "Save"

**Expected Result:**
- ✅ Application recorded
- ✅ Appears in applications list
- ✅ Timeline shown

#### Test Case 7.2: Update Application Status

**Steps:**
1. Click on an application
2. Change status to "Interview Scheduled"
3. Add notes: "Phone screen tomorrow at 2pm"
4. Save

**Expected Result:**
- ✅ Status updated
- ✅ Notes saved
- ✅ Timeline event created

---

## Performance Testing

### Load Test: Database Connection Pool

**Steps:**
1. Start application with monitoring:
   ```bash
   POOL_SIZE=5 mix phx.server &
   watch 'curl -s http://localhost:4000/health/diagnostics | jq ".activity"'
   ```

2. Run load test:
   ```bash
   ab -n 100 -c 10 http://localhost:4000/health
   ```

**Expected Result:**
- ✅ No connection timeout errors
- ✅ Response time < 100ms
- ✅ No pool exhaustion warnings

### Concurrent User Test

**Steps:**
1. Have 5 users open the app simultaneously
2. Each creates a job interest
3. Each accesses different pages

**Expected Result:**
- ✅ All operations complete successfully
- ✅ No race conditions
- ✅ Data consistency maintained

---

## Browser DevTools Checks

### 1. Network Tab

**Steps:**
1. Open DevTools (F12)
2. Click "Network" tab
3. Perform actions (login, create interest, etc.)

**Check:**
- ✅ No 4xx or 5xx errors
- ✅ Request times < 1 second
- ✅ Proper HTTP methods (GET, POST, etc.)
- ✅ Session cookies present

### 2. Console Tab

**Steps:**
1. Open DevTools
2. Click "Console"
3. Perform actions

**Check:**
- ✅ No JavaScript errors
- ✅ No deprecation warnings
- ✅ WebSocket connection healthy (if applicable)

### 3. Application Tab

**Steps:**
1. Open DevTools
2. Click "Application"
3. Expand "Storage"

**Check:**
- ✅ Session cookie present: `_clientats_web_key`
- ✅ Cookie is HttpOnly (secure)
- ✅ Cookie domain is localhost

---

## Error Scenarios

### Test Case: Database Connection Down

**Steps:**
1. Stop PostgreSQL:
   ```bash
   docker-compose down
   ```
2. Try accessing dashboard
3. Try health check:
   ```bash
   curl http://localhost:4000/health/ready
   ```

**Expected Result:**
- ✅ Dashboard shows error
- ✅ Health check returns 503
- ✅ Error message is helpful

### Test Case: Invalid Form Data

**Steps:**
1. Try to create job interest with:
   - Empty required fields
   - Invalid salary format
2. Submit form

**Expected Result:**
- ✅ Form validates client-side
- ✅ Error messages displayed
- ✅ Form not submitted

### Test Case: Session Timeout

**Steps:**
1. Login
2. Wait 30+ minutes
3. Try to perform action

**Expected Result:**
- ✅ Redirected to login
- ✅ Session expired message
- ✅ Can re-login

---

## Testing Checklist

### Core Functionality
- [ ] User registration
- [ ] User login/logout
- [ ] Dashboard access
- [ ] Create job interest
- [ ] Edit job interest
- [ ] Delete job interest
- [ ] Web scraping (if LLM available)
- [ ] Health checks working

### Data Integrity
- [ ] Data persists after page reload
- [ ] No duplicate entries
- [ ] Timestamps are accurate
- [ ] User data is isolated

### Performance
- [ ] Pages load < 2 seconds
- [ ] Forms submit < 1 second
- [ ] No excessive database queries
- [ ] Health checks responsive

### Security
- [ ] No sensitive data in logs
- [ ] CSRF protection active
- [ ] Session cookies secure
- [ ] Input validation working

### Browser Compatibility
- [ ] Works on Chrome
- [ ] Works on Firefox
- [ ] Works on Safari (if on macOS)
- [ ] Mobile responsive (if applicable)

---

## Reporting Issues

When reporting issues found during E2E testing:

1. **Document the scenario:**
   - Clear steps to reproduce
   - Expected vs. actual behavior

2. **Include environment:**
   - Browser and version
   - Operating system
   - Elixir/OTP versions

3. **Add artifacts:**
   - Browser console errors
   - Network tab requests/responses
   - Server logs

4. **Example issue:**
   ```
   Title: Dashboard fails to load with 500 error

   Steps:
   1. Login with valid credentials
   2. Wait 30 seconds
   3. Click "Dashboard"

   Expected: Dashboard loads in < 2 seconds
   Actual: "500 Internal Server Error"

   Browser: Chrome 120.0.6099.129
   OS: Ubuntu 22.04

   Error from console:
   POST /dashboard 500 (Internal Server Error)
   ```

---

## Continuous Testing

### Automated E2E Tests

For automated testing, consider setting up:

```bash
# Using Playwright (browser automation)
npm install --save-dev @playwright/test

# Using Selenium (if needed)
mix ecto.reset # Reset DB before each test run
mix test       # Run test suite
```

### CI/CD Integration

The repository includes GitHub Actions workflows that automatically:
- ✅ Run unit tests on every PR
- ✅ Check code quality
- ✅ Build Docker image
- ✅ Deploy to staging
- ✅ Generate coverage reports

Check `.github/workflows/` for details.

---

## Troubleshooting

### Issue: "Cannot connect to localhost:4000"

**Solution:**
```bash
# Ensure app is running
mix phx.server

# Check port is open
lsof -i :4000
```

### Issue: Database errors during tests

**Solution:**
```bash
# Reset database
mix ecto.reset

# Recreate and migrate
mix ecto.create
mix ecto.migrate
```

### Issue: LLM not responding

**Solution:**
```bash
# Check Ollama is running
curl http://localhost:11434/api/tags

# Restart Ollama
docker-compose restart ollama

# Pull a model if needed
docker-compose exec ollama ollama pull mistral
```

---

## Documentation References

- [Phoenix Testing Guide](https://hexdocs.pm/phoenix/testing_live_views.html)
- [Ecto Testing](https://hexdocs.pm/ecto/Ecto.Repo.html#module-testing)
- [Playwright Documentation](https://playwright.dev/)
- [HTTP Status Codes](https://httpwg.org/specs/rfc7231.html#status.codes)

---

## Sign-Off

After completing all test cases, confirm:

- [ ] All test cases passed
- [ ] No blocking issues found
- [ ] Performance acceptable
- [ ] Security checks passed
- [ ] Ready for release

**Tested by:** _______________
**Date:** _______________
**Version:** _______________
