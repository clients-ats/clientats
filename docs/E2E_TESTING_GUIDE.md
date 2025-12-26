# End-to-End Testing Guide for ClientATS

This guide provides comprehensive instructions for manual end-to-end (E2E) testing of the ClientATS application.

**Document Version:** 2.0 (Comprehensive Coverage)
**Test Cases:** ~180
**Last Updated:** December 2025

This testing guide covers all major features and edge cases of ClientATS, from basic authentication to advanced LLM features, background jobs, API endpoints, audit logging, and platform-specific functionality. Use this guide for thorough pre-release testing, regression testing, and quality assurance.

## Automated E2E Tests

For **automated E2E testing** using Wallaby and ChromeDriver, see the dedicated guide:
- **[test/e2e/README.md](../test/e2e/README.md)** - Automated E2E test infrastructure, fixtures, and patterns

The `test/e2e/` directory contains automated browser-based tests that complement this manual testing guide.

## Overview

ClientATS has the following areas for E2E testing:

1. **User Authentication & Profile** - Registration, login, session management, profile updates, password changes
2. **Dashboard & Navigation** - Dashboard access, quick links, LLM setup banner, closed applications toggle
3. **Job Interest Management** - CRUD operations, status workflows, search/filtering, sorting, pagination
4. **Job Application Tracking** - Application lifecycle, status transitions, events timeline, conversion wizard
5. **Application Events** - Event creation, timeline display, contact tracking, follow-up scheduling
6. **Resume Management** - Upload (PDF/DOCX), download, default selection, file validation, database storage
7. **Cover Letter Management** - Templates, AI generation (text & multimodal), PDF export, variable substitution
8. **LLM/AI Features** - Provider configuration, job scraping (generic/specific modes), job board detection, cover letter generation, multimodal support, circuit breaker, caching
9. **Background Jobs (Oban)** - Async scraping, nightly backups, job status, retry logic, queue management
10. **API Endpoints** - Versioning (v1/v2/legacy), scraping API, LLM config, API documentation (Swagger/ReDoc)
11. **Data Import/Export** - JSON export with base64 resumes, import validation, transaction rollback, statistics
12. **Audit Logging** - Action tracking, IP/user-agent capture, old/new value tracking, immutable records
13. **Help System** - Tutorials, context helpers, interaction tracking, feedback collection
14. **Search & Filtering** - Full-text search, multi-criteria filtering, sorting, pagination, aggregations
15. **Database & Health Checks** - Connection pooling, health endpoints, diagnostics, metrics
16. **Platform Features** - Cross-platform paths, desktop app (Tauri), platform-specific directories
17. **Validation** - URL, email, salary, file type/size, phone number, API keys
18. **Security** - CSRF protection, session cookies, password hashing, input sanitization
19. **Performance** - Large dataset handling, concurrent users, response times
20. **Error Handling** - Network errors, LLM failures, database errors, form validation, session timeout

## Prerequisites

### Local Setup

```bash
# Install dependencies
mix deps.get

# Setup database (SQLite)
mix setup

# Start development server
mix phx.server
```

Application runs on http://localhost:4000

### Optional Services

For full LLM testing:
- **Ollama**: Install locally from [ollama.ai](https://ollama.ai) and run `ollama serve`.
- **Gemini**: Obtain an API key from Google AI Studio.

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

#### Test Case 1.6: Password Validation

**Steps:**
1. Navigate to registration page
2. Try weak passwords:
   - Less than 8 characters: `Pass1!`
   - More than 72 characters: `[very long password]`
   - No special characters: `Password123`
3. Attempt to register

**Expected Result:**
- ✅ Validation errors displayed for weak passwords
- ✅ Form not submitted until valid password provided
- ✅ Password requirements clearly stated

#### Test Case 1.7: Email Validation

**Steps:**
1. Navigate to registration page
2. Try invalid emails:
   - Missing @: `testexample.com`
   - Invalid format: `test@`
   - Duplicate email (register twice with same email)
3. Attempt to register

**Expected Result:**
- ✅ Email format validation errors shown
- ✅ Duplicate email error message displayed
- ✅ Form not submitted with invalid email

#### Test Case 1.8: User Profile Update

**Steps:**
1. Login
2. Navigate to user profile/settings
3. Update first name and last name
4. Save changes

**Expected Result:**
- ✅ Profile updated successfully
- ✅ Updated name displayed in navigation
- ✅ Changes persisted after page reload

#### Test Case 1.9: Change Password

**Steps:**
1. Login
2. Navigate to user profile/settings
3. Enter current password
4. Enter new password (must be different)
5. Confirm new password
6. Save

**Expected Result:**
- ✅ Password changed successfully
- ✅ Can login with new password
- ✅ Cannot login with old password

#### Test Case 1.10: Primary LLM Provider Selection

**Steps:**
1. Login
2. Configure multiple LLM providers (e.g., Ollama and Gemini)
3. Navigate to user profile/settings
4. Select primary LLM provider
5. Save

**Expected Result:**
- ✅ Primary provider saved
- ✅ Scraping and AI features use selected provider by default
- ✅ Can change primary provider later

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

#### Test Case 2.5: Delete Job Interest

**Steps:**
1. Click on a job interest
2. Click "Delete"
3. Confirm deletion

**Expected Result:**
- ✅ Confirmation prompt shown
- ✅ Interest deleted from database
- ✅ Redirected to interest list
- ✅ Deleted interest no longer visible

#### Test Case 2.6: Job Interest Status Workflow

**Steps:**
1. Create a new job interest with status "Interested"
2. Edit and change status to "Researching"
3. Edit and change status to "Ready to Apply"
4. Edit and change status to "Applied"
5. View each status transition in the UI

**Expected Result:**
- ✅ Status updates successfully at each step
- ✅ Status changes reflected in the list view
- ✅ Can filter by each status
- ✅ Status "Not a Fit" also available

#### Test Case 2.7: Priority Management

**Steps:**
1. Create job interests with different priorities (Low, Medium, High)
2. View interest list
3. Sort by priority

**Expected Result:**
- ✅ Priority saved correctly
- ✅ Priority displayed with appropriate visual indicator
- ✅ Can filter by priority
- ✅ Sorting by priority works correctly

#### Test Case 2.8: Work Model Selection

**Steps:**
1. Create job interests with different work models:
   - Remote
   - Hybrid
   - On-site
2. View interest list

**Expected Result:**
- ✅ Work model saved correctly
- ✅ Work model displayed in list/detail view
- ✅ Can filter by work model

#### Test Case 2.9: Salary Range Validation

**Steps:**
1. Create job interest
2. Enter Salary Min: "150000"
3. Enter Salary Max: "120000" (less than min)
4. Attempt to save

**Expected Result:**
- ✅ Validation error shown (max must be >= min)
- ✅ Form not submitted
- ✅ Can correct and save successfully

#### Test Case 2.10: Full-Text Search

**Steps:**
1. Create multiple job interests with different companies, titles, locations
2. Use search box to search for:
   - Company name
   - Position title
   - Location
   - Keywords in description
   - Keywords in notes
3. View results

**Expected Result:**
- ✅ Search returns matching interests
- ✅ Search is case-insensitive
- ✅ Partial matches work
- ✅ No results message shown when appropriate

#### Test Case 2.11: Advanced Filtering

**Steps:**
1. Create 20+ job interests with varied attributes
2. Apply filters:
   - Status = "Interested"
   - Priority = "High"
   - Salary Min >= $120,000
   - Location contains "San Francisco"
   - Work Model = "Remote"
3. Apply multiple filters simultaneously

**Expected Result:**
- ✅ Each filter works independently
- ✅ Combined filters work correctly (AND logic)
- ✅ Result count updates
- ✅ Can clear filters

#### Test Case 2.12: Sorting Options

**Steps:**
1. View job interests list
2. Sort by:
   - Company name (A-Z, Z-A)
   - Position title (A-Z, Z-A)
   - Priority (High to Low, Low to High)
   - Created date (Newest, Oldest)
   - Salary (High to Low, Low to High)

**Expected Result:**
- ✅ Each sort option works correctly
- ✅ Sort direction toggles
- ✅ Sort persists during pagination
- ✅ Sort indicator shown in UI

#### Test Case 2.13: Pagination

**Steps:**
1. Create 30+ job interests
2. View interest list (default 10 per page)
3. Navigate to page 2, 3
4. Change items per page (10, 25, 50)

**Expected Result:**
- ✅ Correct number of items per page
- ✅ Page navigation works
- ✅ Total count displayed correctly
- ✅ "Next" disabled on last page

#### Test Case 2.14: Notes Management

**Steps:**
1. Create/edit job interest
2. Add detailed notes in the notes field
3. Save and view
4. Edit notes later

**Expected Result:**
- ✅ Notes saved correctly
- ✅ Notes displayed in detail view
- ✅ Markdown/formatting preserved (if supported)
- ✅ Notes searchable via full-text search

#### Test Case 2.15: LLM Setup Banner

**Steps:**
1. Login as a new user (no LLM configured)
2. View dashboard

**Expected Result:**
- ✅ Banner shown prompting LLM setup
- ✅ Link to LLM configuration page
- ✅ Banner dismissible
- ✅ Banner doesn't show after LLM configured

#### Test Case 2.16: Toggle Closed Applications

**Steps:**
1. Create applications with various statuses
2. On dashboard, locate toggle for "Show Closed Applications"
3. Toggle on/off

**Expected Result:**
- ✅ Closed applications hidden by default
- ✅ Toggle shows closed applications (rejected, withdrawn)
- ✅ Toggle state persists across page reloads
- ✅ Application count updates correctly

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

#### Test Case 3.4: Job Board Detection (Specific Mode)

**Steps:**
1. Test scraping from different known job boards:
   - LinkedIn: `https://www.linkedin.com/jobs/view/[id]/`
   - Indeed: `https://www.indeed.com/viewjob?jk=[id]`
   - Glassdoor: `https://www.glassdoor.com/job-listing/[id]`
   - AngelList: `https://angel.co/company/[company]/jobs/[id]`
   - Lever: `https://jobs.lever.co/[company]/[id]`
   - Greenhouse: `https://boards.greenhouse.io/[company]/jobs/[id]`
2. Verify mode is set to "specific"

**Expected Result:**
- ✅ Job board correctly identified
- ✅ Specific extraction prompt used
- ✅ Better extraction accuracy
- ✅ Source marked as detected board

#### Test Case 3.5: Generic Mode Scraping

**Steps:**
1. From scrape page, enter URL for unknown job site
2. Ensure mode is "generic" (or auto-detected)
3. Click "Scrape"

**Expected Result:**
- ✅ Generic extraction used
- ✅ Job data still extracted
- ✅ May require more manual review
- ✅ Fallback works for any URL

#### Test Case 3.6: Screenshot-Based Multimodal Extraction

**Steps:**
1. From scrape page, enter a job URL
2. Scrape job (system should capture screenshot)
3. Wait for extraction with vision model

**Expected Result:**
- ✅ Screenshot captured
- ✅ Vision model processes image
- ✅ Job data extracted from visual content
- ✅ More accurate than text-only extraction

#### Test Case 3.7: Auto-Save After Scraping

**Steps:**
1. From scrape page, enter job URL
2. Enable "Auto-save" option (if available)
3. Scrape job
4. Wait for completion

**Expected Result:**
- ✅ Job automatically saved as interest
- ✅ Redirected to interest detail page
- ✅ No manual review step needed
- ✅ Can edit after auto-save

#### Test Case 3.8: Async Background Scraping

**Steps:**
1. From scrape page, enter job URL
2. Choose "Background" or async option (if available)
3. Start scraping
4. Navigate away from page

**Expected Result:**
- ✅ Scraping continues in background (Oban worker)
- ✅ Notification when complete
- ✅ Can track job status
- ✅ Results available when done

#### Test Case 3.9: Network Error During Scraping

**Steps:**
1. Start scraping a job
2. Disconnect network mid-scrape (or use invalid URL)
3. Observe error handling

**Expected Result:**
- ✅ Timeout error shown
- ✅ Retry offered
- ✅ Fallback to manual entry
- ✅ No data corruption

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

#### Test Case 4.4: Configure Gemini (Cloud)

**Steps:**
1. Navigate to LLM Config
2. Click "Gemini" tab
3. Enter API key from Google AI Studio
4. Select models:
   - Default model: `gemini-2.0-flash-exp`
   - Vision model: `gemini-2.0-flash-exp`
5. Click "Test Connection"
6. Save configuration

**Expected Result:**
- ✅ API key accepted and encrypted
- ✅ Connection test succeeds
- ✅ Models saved
- ✅ Provider status: "Connected"

#### Test Case 4.5: Provider Status Tracking

**Steps:**
1. View LLM config page
2. Observe provider statuses:
   - Unconfigured (no API key/URL)
   - Configured (API key set, not tested)
   - Connected (test succeeded)
   - Error (test failed)

**Expected Result:**
- ✅ Each status displayed with appropriate icon/color
- ✅ Last tested timestamp shown
- ✅ Error message displayed for failed providers
- ✅ Can re-test from any status

#### Test Case 4.6: Model Selection

**Steps:**
1. Configure Ollama provider
2. Discover available models
3. Select different models for:
   - Default model (general text)
   - Vision model (multimodal)
   - Text model (text-only tasks)
4. Save

**Expected Result:**
- ✅ Models discovered from provider
- ✅ Can select different models for each purpose
- ✅ Vision models only shown for vision field
- ✅ Selected models saved correctly

#### Test Case 4.7: Provider Priority/Reordering

**Steps:**
1. Configure multiple providers (Ollama, Gemini)
2. Drag to reorder providers in priority list
3. Save configuration

**Expected Result:**
- ✅ Providers reorder visually
- ✅ Order saved to database
- ✅ Higher priority providers tried first in fallback
- ✅ Drag handle visible

#### Test Case 4.8: Enable/Disable Provider

**Steps:**
1. Configure a provider
2. Toggle "Enabled" checkbox
3. Disable provider
4. Attempt to use disabled provider

**Expected Result:**
- ✅ Disabled provider shown as inactive
- ✅ Disabled provider not used for scraping/generation
- ✅ Fallback skips disabled providers
- ✅ Can re-enable later

#### Test Case 4.9: LLM Circuit Breaker

**Steps:**
1. Configure provider with invalid credentials
2. Attempt multiple scraping operations (5+)
3. Observe circuit breaker behavior

**Expected Result:**
- ✅ After N failures, circuit opens
- ✅ Provider temporarily disabled
- ✅ Error message indicates circuit open
- ✅ Auto-recovery after timeout period

#### Test Case 4.10: Provider Fallback Chain

**Steps:**
1. Configure multiple providers (Ollama primary, Gemini secondary)
2. Disable or break primary provider (Ollama)
3. Attempt to scrape job

**Expected Result:**
- ✅ Primary provider attempted first
- ✅ On failure, fallback to secondary
- ✅ Job scraping succeeds with secondary
- ✅ User notified which provider was used

#### Test Case 4.11: Retry Logic with Exponential Backoff

**Steps:**
1. Configure provider with intermittent connectivity
2. Attempt scraping operation
3. Monitor retry attempts in logs

**Expected Result:**
- ✅ First retry after 1 second
- ✅ Second retry after 2 seconds
- ✅ Third retry after 4 seconds
- ✅ Max 3 retries before failure
- ✅ Retries only for retryable errors (500, timeout, network)

#### Test Case 4.12: API Key Validation

**Steps:**
1. Navigate to LLM config
2. Enter invalid API key formats:
   - Empty string
   - Too short (< 10 chars)
   - Invalid characters
3. Attempt to save

**Expected Result:**
- ✅ Validation errors shown
- ✅ Form not submitted with invalid key
- ✅ API key encrypted when saved
- ✅ API key hidden (password field) in UI

#### Test Case 4.13: LLM Setup Wizard

**Steps:**
1. Login as new user
2. Click on LLM setup banner/link
3. Follow wizard steps:
   - Choose provider
   - Enter credentials
   - Test connection
   - Complete setup

**Expected Result:**
- ✅ Wizard guides through setup
- ✅ Step-by-step instructions clear
- ✅ Can go back to previous steps
- ✅ Configuration saved on completion

---

### 6. Resumes & Cover Letters

#### Test Case 6.1: Upload Resume

**Steps:**
1. From dashboard, click "Resumes"
2. Click "Upload Resume"
3. Select a PDF, DOC, or DOCX file
4. Enter name: "John Doe - Senior Backend"
5. Click "Upload Resume"

**Expected Result:**
- ✅ File uploaded successfully and stored in database
- ✅ Resume listed in "My Resumes"
- ✅ "Download" button is active

#### Test Case 6.2: Invalid Resume Handling (Migration Test)

**Steps:**
1. *Simulate corruption*: Manually set `is_valid` to `false` in database or mock a missing file scenario during migration.
   (For manual testing: Look for any pre-existing resumes from before the DB storage migration that might have missing files)
2. View "Resumes" list.

**Expected Result:**
- ✅ Resume marked with "Invalid File" badge
- ✅ Warning message displayed
- ✅ "Download" button disabled
- ✅ User can still Edit/Delete the record

#### Test Case 6.3: Create Cover Letter Template

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

#### Test Case 6.4: Job Application Conversion Wizard

**Steps:**
1. Go to "Job Interests"
2. Click "Convert to Application" on an interest
3. **Step 1:** Confirm details (Company, Title) -> Click "Next"
4. **Step 2:** Select Resume -> Choose an uploaded resume -> Click "Next"
5. **Step 3:** Cover Letter -> Select a template -> Click "Generate with AI" (optional) -> Click "Next"
6. **Step 4:** Review -> Click "Create Application"

**Expected Result:**
- ✅ Application created with status "Applied"
- ✅ Resume and Cover Letter attached
- ✅ Redirected to Application Details page

#### Test Case 6.5: Download Cover Letter PDF

**Steps:**
1. View a Job Application detail page
2. Click "Download PDF" button next to Cover Letter

**Expected Result:**
- ✅ PDF file downloads
- ✅ PDF contains correctly formatted cover letter text

#### Test Case 6.6: Delete Resume

**Steps:**
1. Navigate to "Resumes"
2. Click on a resume
3. Click "Delete"
4. Confirm deletion

**Expected Result:**
- ✅ Confirmation prompt shown
- ✅ Resume deleted from database
- ✅ File data removed
- ✅ Redirected to resume list

#### Test Case 6.7: Edit Resume Metadata

**Steps:**
1. Navigate to "Resumes"
2. Click on a resume
3. Click "Edit"
4. Update name and description
5. Save

**Expected Result:**
- ✅ Metadata updated successfully
- ✅ File unchanged (still downloadable)
- ✅ Updated info shown in list

#### Test Case 6.8: Set Default Resume

**Steps:**
1. Upload multiple resumes
2. Mark one as "Default"
3. Create new application

**Expected Result:**
- ✅ Only one resume can be default
- ✅ Setting new default clears previous
- ✅ Default resume pre-selected in wizard
- ✅ Default badge shown in list

#### Test Case 6.9: Upload DOCX Resume

**Steps:**
1. Navigate to "Resumes"
2. Click "Upload Resume"
3. Select a .docx file
4. Fill in details
5. Upload

**Expected Result:**
- ✅ DOCX file accepted
- ✅ File stored in database
- ✅ Downloadable as DOCX
- ✅ Text extraction works for AI

#### Test Case 6.10: File Size Validation

**Steps:**
1. Attempt to upload resume > 10 MB
2. Observe error

**Expected Result:**
- ✅ File size validation error shown
- ✅ Upload rejected
- ✅ Size limit clearly communicated

#### Test Case 6.11: Resume Text Extraction

**Steps:**
1. Upload PDF or DOCX resume
2. Use in AI cover letter generation
3. Verify text extracted correctly

**Expected Result:**
- ✅ Text extracted from PDF (pdftotext)
- ✅ Text extracted from DOCX
- ✅ Extracted text used in prompts
- ✅ Extraction errors handled gracefully

#### Test Case 6.12: Download Resume

**Steps:**
1. Navigate to "Resumes"
2. Click "Download" button on a resume

**Expected Result:**
- ✅ File downloads with original filename
- ✅ File type correct (PDF/DOCX)
- ✅ File content intact
- ✅ Download button disabled for invalid resumes

#### Test Case 6.13: Delete Cover Letter Template

**Steps:**
1. Navigate to "Cover Letters"
2. Click on a template
3. Click "Delete"
4. Confirm

**Expected Result:**
- ✅ Confirmation prompt shown
- ✅ Template deleted
- ✅ Cannot delete if in use (or warning shown)
- ✅ Redirected to template list

#### Test Case 6.14: Edit Cover Letter Template

**Steps:**
1. Navigate to "Cover Letters"
2. Click on a template
3. Click "Edit"
4. Modify content
5. Save

**Expected Result:**
- ✅ Template updated
- ✅ Changes reflected in future uses
- ✅ Existing applications unchanged

#### Test Case 6.15: Set Default Cover Letter Template

**Steps:**
1. Create multiple templates
2. Mark one as "Default"
3. Use in application wizard

**Expected Result:**
- ✅ Only one template can be default
- ✅ Setting new default clears previous
- ✅ Default template pre-selected in wizard
- ✅ Default badge shown in list

#### Test Case 6.16: Template Variables

**Steps:**
1. Create template with variables:
   ```
   Dear Hiring Manager at [Company],

   I am applying for the [Position] role...
   ```
2. Use template in application
3. Verify variables replaced

**Expected Result:**
- ✅ [Company] replaced with company name
- ✅ [Position] replaced with job title
- ✅ Other variables supported (if any)
- ✅ Variables documented

#### Test Case 6.17: AI Cover Letter Generation (Text-Based)

**Steps:**
1. In application wizard, reach Step 3
2. Select a template (or no template)
3. Ensure resume is text-extractable (PDF/DOCX)
4. Click "Generate with AI"
5. Wait for generation

**Expected Result:**
- ✅ LLM generates personalized cover letter
- ✅ Uses job description and resume text
- ✅ Template incorporated (if selected)
- ✅ User can edit generated content
- ✅ Generation time < 30 seconds

#### Test Case 6.18: AI Cover Letter Generation (Multimodal)

**Steps:**
1. In application wizard, Step 3
2. Upload resume as PDF (non-extractable or complex formatting)
3. Click "Generate with AI"
4. Observe multimodal generation

**Expected Result:**
- ✅ Vision model processes PDF visually
- ✅ Cover letter generated from visual resume
- ✅ More accurate than text extraction
- ✅ Works with scanned PDFs or images

#### Test Case 6.19: Resume in Database Storage

**Steps:**
1. Upload resume
2. Check database for `data` field populated
3. Delete original file from disk (if exists)
4. Download resume

**Expected Result:**
- ✅ Resume stored as binary in database
- ✅ Download works from database
- ✅ Migration from file-based to DB storage successful
- ✅ No dependency on filesystem

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

#### Test Case 7.3: Delete Application

**Steps:**
1. Navigate to "Applications"
2. Click on an application
3. Click "Delete"
4. Confirm deletion

**Expected Result:**
- ✅ Confirmation prompt shown
- ✅ Application deleted
- ✅ Associated events deleted (or orphaned)
- ✅ Redirected to applications list

#### Test Case 7.4: Edit Application

**Steps:**
1. Click on an application
2. Click "Edit"
3. Modify fields (notes, status, dates)
4. Save

**Expected Result:**
- ✅ Changes saved
- ✅ Updated info displayed
- ✅ Timestamps updated
- ✅ Timeline reflects changes

#### Test Case 7.5: Application Status Workflow

**Steps:**
1. Create application with status "Applied"
2. Update to "Phone Screen"
3. Update to "Interview Scheduled"
4. Update to "Interviewed"
5. Update to "Offer Received"
6. Update to "Offer Accepted"

Also test terminal states:
7. Test "Rejected"
8. Test "Withdrawn"

**Expected Result:**
- ✅ All status transitions work
- ✅ Status displayed correctly in list
- ✅ Can filter by each status
- ✅ Timeline shows status history
- ✅ Terminal statuses (rejected/withdrawn) mark as closed

#### Test Case 7.6: Filter Applications by Status

**Steps:**
1. Create applications with various statuses
2. Apply status filter:
   - Applied
   - Phone Screen
   - Interview Scheduled
   - Interviewed
   - Offer Received
   - Offer Accepted
   - Rejected
   - Withdrawn

**Expected Result:**
- ✅ Filter shows only matching status
- ✅ Can select multiple statuses
- ✅ Result count updates
- ✅ Can clear filter

#### Test Case 7.7: Filter Applications by Date Range

**Steps:**
1. Create applications with different application dates
2. Set date filters:
   - From date: 2025-01-01
   - To date: 2025-12-31
3. Apply filter

**Expected Result:**
- ✅ Only applications within date range shown
- ✅ Date picker works correctly
- ✅ Can filter by start date only
- ✅ Can filter by end date only

#### Test Case 7.8: Search Applications

**Steps:**
1. Create multiple applications
2. Use search box to search for:
   - Company name
   - Position title
   - Keywords in job description
   - Keywords in notes
3. View results

**Expected Result:**
- ✅ Search returns matching applications
- ✅ Search is case-insensitive
- ✅ Partial matches work
- ✅ Search across all text fields

#### Test Case 7.9: Sort Applications

**Steps:**
1. View applications list
2. Sort by:
   - Company name (A-Z, Z-A)
   - Position title (A-Z, Z-A)
   - Application date (Newest, Oldest)
   - Status

**Expected Result:**
- ✅ Each sort option works
- ✅ Sort direction toggles
- ✅ Sort persists during pagination

#### Test Case 7.10: Application Timeline Display

**Steps:**
1. Create application
2. Add multiple events (see section 7A)
3. View application details
4. Observe timeline

**Expected Result:**
- ✅ Events displayed chronologically
- ✅ Event types clearly labeled
- ✅ Dates and contacts shown
- ✅ Notes for each event visible
- ✅ Timeline interactive

#### Test Case 7.11: Application Statistics

**Steps:**
1. Create multiple applications
2. View dashboard or applications page
3. Check statistics displayed

**Expected Result:**
- ✅ Total applications count
- ✅ Count by status
- ✅ Response rate (if applicable)
- ✅ Average time to offer

#### Test Case 7.12: Cover Letter Editor in Wizard

**Steps:**
1. In conversion wizard, reach Step 3 (Cover Letter)
2. Select template
3. Edit content inline
4. Use formatting tools (if available)
5. Preview letter
6. Continue to next step

**Expected Result:**
- ✅ Rich text editor works
- ✅ Template content loaded
- ✅ Can edit freely
- ✅ Preview accurate
- ✅ Changes saved

---

### 7A. Application Events

#### Test Case 7A.1: Create Application Event (Applied)

**Steps:**
1. View application details
2. Click "Add Event"
3. Select event type: "Applied"
4. Set event date
5. Add notes
6. Save

**Expected Result:**
- ✅ Event created
- ✅ Appears in timeline
- ✅ Event date shown
- ✅ Notes displayed

#### Test Case 7A.2: Create Contact Event

**Steps:**
1. View application details
2. Add event type: "Contact"
3. Fill in:
   - Contact person: "Jane Smith"
   - Contact email: "jane@company.com"
   - Contact phone: "555-1234"
   - Event date
   - Notes: "Initial outreach"
4. Save

**Expected Result:**
- ✅ Event created with contact info
- ✅ Email validated
- ✅ Contact details displayed in timeline
- ✅ Can click email to send (if linked)

#### Test Case 7A.3: Create Phone Screen Event

**Steps:**
1. Add event type: "Phone Screen"
2. Set event date and time
3. Add contact person
4. Add notes
5. Set follow-up date
6. Save

**Expected Result:**
- ✅ Event created
- ✅ Follow-up date tracked
- ✅ Reminder shown (if implemented)
- ✅ Timeline shows phone screen

#### Test Case 7A.4: Create Interview Events

**Steps:**
1. Add events for:
   - Technical Screen
   - Interview (Onsite)
2. Include contact person for each
3. Add detailed notes
4. Save

**Expected Result:**
- ✅ Each event type works
- ✅ Multiple interviews can be tracked
- ✅ Timeline shows all interviews
- ✅ Chronological order maintained

#### Test Case 7A.5: Create Follow-Up Event

**Steps:**
1. Add event type: "Follow-Up"
2. Set event date
3. Reference previous event in notes
4. Set next follow-up date
5. Save

**Expected Result:**
- ✅ Event created
- ✅ Follow-up chain trackable
- ✅ Next action date highlighted
- ✅ Can schedule multiple follow-ups

#### Test Case 7A.6: Create Offer Event

**Steps:**
1. Add event type: "Offer"
2. Set event date
3. Add offer details in notes (salary, benefits, etc.)
4. Save
5. Optionally update application status to "Offer Received"

**Expected Result:**
- ✅ Offer event created
- ✅ Offer details preserved
- ✅ Status can be updated
- ✅ Timeline shows offer

#### Test Case 7A.7: Create Rejection Event

**Steps:**
1. Add event type: "Rejection"
2. Set event date
3. Add notes (reason if known)
4. Save
5. Optionally update application status to "Rejected"

**Expected Result:**
- ✅ Rejection event created
- ✅ Application marked as closed
- ✅ Event visible in timeline
- ✅ Notes captured

#### Test Case 7A.8: Create Withdrawn Event

**Steps:**
1. Add event type: "Withdrawn"
2. Set event date
3. Add reason in notes
4. Save
5. Update application status to "Withdrawn"

**Expected Result:**
- ✅ Event created
- ✅ Application marked as closed
- ✅ Reason preserved
- ✅ Appears in timeline

#### Test Case 7A.9: Edit Application Event

**Steps:**
1. View application timeline
2. Click on an event
3. Click "Edit"
4. Modify fields
5. Save

**Expected Result:**
- ✅ Event updated
- ✅ Changes reflected in timeline
- ✅ Timestamps updated
- ✅ History preserved (if versioned)

#### Test Case 7A.10: Delete Application Event

**Steps:**
1. View application timeline
2. Click on an event
3. Click "Delete"
4. Confirm

**Expected Result:**
- ✅ Confirmation prompt shown
- ✅ Event deleted
- ✅ Timeline updated
- ✅ Application status unchanged

#### Test Case 7A.11: Contact Email Validation

**Steps:**
1. Add event with contact email
2. Try invalid emails:
   - Missing @
   - Invalid format
3. Save

**Expected Result:**
- ✅ Email validation works
- ✅ Error message shown
- ✅ Form not submitted with invalid email

#### Test Case 7A.12: Follow-Up Date Scheduling

**Steps:**
1. Create event with follow-up date
2. Set date in future
3. Save
4. View upcoming follow-ups (if dashboard shows this)

**Expected Result:**
- ✅ Follow-up date saved
- ✅ Appears in reminders/upcoming tasks
- ✅ Can mark as completed
- ✅ Overdue follow-ups highlighted

#### Test Case 7A.13: Phone Number Validation

**Steps:**
1. Add event with contact phone
2. Try various formats:
   - (555) 123-4567
   - 555-123-4567
   - 5551234567
   - Invalid: "abc"
3. Save

**Expected Result:**
- ✅ Phone formats accepted
- ✅ Invalid formats rejected
- ✅ Format standardized in display

---

### 8. Data Management

#### Test Case 8.1: Export User Data

**Steps:**
1. Navigate to "Settings" (or `localhost:4000/export` if no UI link)
2. Click "Export Data"

**Expected Result:**
- ✅ JSON file downloads (`clientats_export_....json`)
- ✅ File contains user profile, job interests, applications, and resumes (base64 encoded)

#### Test Case 8.2: Import User Data

**Steps:**
1. Navigate to `/import` (or via Settings)
2. Select a previously exported JSON file
3. Click "Import"

**Expected Result:**
- ✅ Data imported successfully
- ✅ Dashboard reflects imported items
- ✅ Resumes are restored and downloadable

#### Test Case 8.3: Export Format Validation

**Steps:**
1. Export data
2. Open JSON file in text editor
3. Validate structure

**Expected Result:**
- ✅ Valid JSON format
- ✅ Version field present (e.g., "1.0")
- ✅ Contains sections: user, job_interests, job_applications, application_events, resumes, cover_letter_templates
- ✅ Timestamp (exported_at) included
- ✅ All required fields present

#### Test Case 8.4: Resume Base64 Encoding in Export

**Steps:**
1. Upload a resume
2. Export data
3. Check JSON for resume data

**Expected Result:**
- ✅ Resume file encoded as base64
- ✅ File metadata included (filename, size, mime_type)
- ✅ Encoding/decoding lossless
- ✅ Can import and restore file

#### Test Case 8.5: Import Validation and Version Checking

**Steps:**
1. Create invalid JSON file
2. Attempt to import
3. Observe error

Also test:
4. Incompatible version number
5. Missing required fields

**Expected Result:**
- ✅ Invalid JSON rejected
- ✅ Version mismatch detected
- ✅ Missing fields reported
- ✅ Clear error messages
- ✅ No partial import

#### Test Case 8.6: Import Statistics

**Steps:**
1. Import data
2. View import results page

**Expected Result:**
- ✅ Shows counts: X interests imported, Y applications imported, etc.
- ✅ Lists any errors or skipped items
- ✅ Summary of successful import
- ✅ Link to imported data

#### Test Case 8.7: Import Transaction Rollback on Failure

**Steps:**
1. Create JSON with partial invalid data
2. Attempt import
3. Verify no partial data saved

**Expected Result:**
- ✅ Import fails atomically
- ✅ No partial data in database
- ✅ Database state unchanged
- ✅ Can retry after fixing data

#### Test Case 8.8: Export with Large Dataset

**Steps:**
1. Create 100+ job interests, applications, events
2. Export data
3. Verify export completeness

**Expected Result:**
- ✅ All records included
- ✅ Export completes in reasonable time (< 30s)
- ✅ File size manageable
- ✅ No truncation

#### Test Case 8.9: Import Duplicate Handling

**Steps:**
1. Import data
2. Import same data again
3. Observe behavior

**Expected Result:**
- ✅ Duplicates detected or prevented
- ✅ User warned/prompted
- ✅ Can choose to skip or merge
- ✅ No data corruption

---

### 9. Background Jobs (Oban)

#### Test Case 9.1: Async Job Scraping

**Steps:**
1. Navigate to scrape page
2. Enter job URL
3. Select "Background" mode (if option exists)
4. Start scraping
5. Navigate away
6. Check job status later

**Expected Result:**
- ✅ Job queued in Oban (:scrape queue)
- ✅ Job ID returned
- ✅ Can check status via API/UI
- ✅ Scraping completes in background
- ✅ User notified on completion

#### Test Case 9.2: Job Status Tracking

**Steps:**
1. Queue background job
2. Check status immediately
3. Check status while running
4. Check status after completion

**Expected Result:**
- ✅ Status: "queued" → "running" → "completed"
- ✅ ETA displayed
- ✅ Progress updated (if applicable)
- ✅ Result available when done

#### Test Case 9.3: Job Cancellation

**Steps:**
1. Queue long-running background job
2. Get job ID
3. Cancel job before completion

**Expected Result:**
- ✅ Job cancellation succeeds
- ✅ Job status: "cancelled"
- ✅ Resources cleaned up
- ✅ No partial results saved

#### Test Case 9.4: Retry Logic (Max 3 Attempts)

**Steps:**
1. Queue job that fails (e.g., invalid URL)
2. Observe retry behavior
3. Check logs

**Expected Result:**
- ✅ First attempt fails
- ✅ Second attempt after delay
- ✅ Third attempt after longer delay
- ✅ After 3 failures, job marked as failed
- ✅ No infinite retries

#### Test Case 9.5: Queue Statistics

**Steps:**
1. Queue multiple jobs
2. View Oban dashboard or stats API
3. Check queue metrics

**Expected Result:**
- ✅ Jobs in queue count
- ✅ Jobs completed count
- ✅ Jobs failed count
- ✅ Average processing time
- ✅ Queue health status

#### Test Case 9.6: Nightly Backup Worker

**Steps:**
1. Wait for scheduled backup (or trigger manually)
2. Check backup directory
3. Verify backup files

**Expected Result:**
- ✅ Backup job runs nightly (cron schedule)
- ✅ SQLite database backed up
- ✅ JSON export created for all users
- ✅ Backup stored in platform-specific directory
- ✅ Timestamp in filename

#### Test Case 9.7: Backup Rotation (Keep Last 2 Days)

**Steps:**
1. Run backup job for 3+ consecutive days
2. Check backup directory
3. Count backup files

**Expected Result:**
- ✅ Only last 2 days of backups kept
- ✅ Older backups deleted automatically
- ✅ Rotation configurable (env var)
- ✅ Manual backups not deleted

#### Test Case 9.8: Scheduled Data Export Job

**Steps:**
1. Schedule export job for specific user
2. Wait for execution or trigger manually
3. Check results

**Expected Result:**
- ✅ Export job queued
- ✅ Export completes successfully
- ✅ File available for download
- ✅ User notified (if implemented)

#### Test Case 9.9: Job Queue Management

**Steps:**
1. View Oban Web UI (if enabled) or check via API
2. View pending jobs in each queue (:scrape, :default, :low)
3. Observe job processing

**Expected Result:**
- ✅ Jobs listed by queue
- ✅ Can see job arguments
- ✅ Timestamps visible
- ✅ Queue priority respected

#### Test Case 9.10: Concurrent Job Processing

**Steps:**
1. Queue 10+ jobs simultaneously
2. Observe processing
3. Check completion times

**Expected Result:**
- ✅ Multiple jobs process concurrently
- ✅ No deadlocks
- ✅ Database pool not exhausted
- ✅ All jobs complete successfully

---

### 10. API Endpoints

#### Test Case 10.1: API Versioning (v1, v2, Legacy)

**Steps:**
1. Test endpoints:
   - `POST /api/scrape_job` (legacy)
   - `POST /api/v1/scrape_job`
   - `POST /api/v2/scrape_job`
2. Verify behavior

**Expected Result:**
- ✅ Legacy endpoint redirects to v1
- ✅ v1 and v2 both functional
- ✅ Version metadata in response headers
- ✅ Deprecation warnings for legacy

#### Test Case 10.2: Scraping API (POST /api/v1/scrape_job)

**Steps:**
1. Send POST request:
   ```bash
   curl -X POST http://localhost:4000/api/v1/scrape_job \
     -H "Content-Type: application/json" \
     -d '{
       "url": "https://www.linkedin.com/jobs/view/123/",
       "mode": "specific",
       "provider": "ollama",
       "save": true
     }'
   ```
2. Check response

**Expected Result:**
- ✅ Returns job data JSON
- ✅ Accepts parameters: url, mode, provider, save
- ✅ Auto-saves if `save: true`
- ✅ Returns 200 on success, 4xx/5xx on error

#### Test Case 10.3: GET /api/v1/llm/providers

**Steps:**
1. Send GET request:
   ```bash
   curl http://localhost:4000/api/v1/llm/providers
   ```

**Expected Result:**
- ✅ Returns list of available providers
- ✅ JSON format
- ✅ Shows provider status (configured/connected)
- ✅ No sensitive data (API keys hidden)

#### Test Case 10.4: GET /api/v1/llm/config

**Steps:**
1. Configure LLM providers
2. Send GET request:
   ```bash
   curl http://localhost:4000/api/v1/llm/config
   ```

**Expected Result:**
- ✅ Returns user's LLM configuration
- ✅ API keys masked
- ✅ Models listed
- ✅ Provider status included

#### Test Case 10.5: API Documentation - Swagger UI

**Steps:**
1. Navigate to http://localhost:4000/api-docs/swagger-ui

**Expected Result:**
- ✅ Swagger UI loads
- ✅ All endpoints documented
- ✅ Request/response schemas shown
- ✅ "Try it out" functionality works

#### Test Case 10.6: API Documentation - ReDoc

**Steps:**
1. Navigate to http://localhost:4000/api-docs/redoc

**Expected Result:**
- ✅ ReDoc UI loads
- ✅ Clean, readable documentation
- ✅ All endpoints listed
- ✅ Examples provided

#### Test Case 10.7: OpenAPI Specification

**Steps:**
1. Fetch OpenAPI spec:
   ```bash
   curl http://localhost:4000/api-docs/openapi.json
   ```

**Expected Result:**
- ✅ Valid OpenAPI 3.0 JSON
- ✅ All endpoints defined
- ✅ Schemas complete
- ✅ Can import into Postman/Insomnia

#### Test Case 10.8: API Error Responses

**Steps:**
1. Test invalid requests:
   - Missing required parameters
   - Invalid URL format
   - Unsupported provider
2. Check error responses

**Expected Result:**
- ✅ 400 Bad Request for invalid input
- ✅ 404 Not Found for missing resources
- ✅ 500 Internal Server Error for server issues
- ✅ Error messages clear and helpful
- ✅ Consistent error format

#### Test Case 10.9: API Rate Limiting (If Implemented)

**Steps:**
1. Send many rapid API requests (100+)
2. Observe rate limiting

**Expected Result:**
- ✅ Rate limit enforced
- ✅ 429 Too Many Requests returned
- ✅ Retry-After header present
- ✅ Limit resets after period

---

### 11. Audit Logging

#### Test Case 11.1: Audit Log Creation for User Actions

**Steps:**
1. Perform various actions:
   - Create job interest
   - Update application
   - Delete resume
   - Login
   - Logout
2. Check database audit_logs table

**Expected Result:**
- ✅ Each action logged
- ✅ Action type correct (create, update, delete, login, logout)
- ✅ Resource type and ID captured
- ✅ Timestamp recorded

#### Test Case 11.2: IP Address and User Agent Tracking

**Steps:**
1. Perform action from different browser/IP
2. Check audit log

**Expected Result:**
- ✅ IP address captured
- ✅ User agent string stored
- ✅ Can track user's device/location
- ✅ Privacy considerations documented

#### Test Case 11.3: Old/New Values Tracking

**Steps:**
1. Edit a job interest (change company name)
2. Check audit log

**Expected Result:**
- ✅ Old value stored: {"company_name": "OldCo"}
- ✅ New value stored: {"company_name": "NewCo"}
- ✅ Can see what changed
- ✅ JSON format for values

#### Test Case 11.4: Status Tracking (Success/Failure)

**Steps:**
1. Perform successful action (create interest)
2. Attempt failed action (invalid form)
3. Check audit logs

**Expected Result:**
- ✅ Successful actions marked: status = "success"
- ✅ Failed actions marked: status = "failure"
- ✅ Error messages captured for failures
- ✅ Partial operations marked: status = "partial"

#### Test Case 11.5: Immutable Audit Records

**Steps:**
1. Create audit log entry
2. Attempt to edit or delete (via database)
3. Verify protection

**Expected Result:**
- ✅ Audit logs write-once
- ✅ No update/delete allowed
- ✅ Database constraints prevent modification
- ✅ Only insert permitted

#### Test Case 11.6: File Operations Logging

**Steps:**
1. Upload resume (file_upload)
2. Download resume (file_download)
3. Check audit logs

**Expected Result:**
- ✅ Upload logged with file metadata
- ✅ Download logged with user and file ID
- ✅ File size and type captured
- ✅ Timestamps accurate

#### Test Case 11.7: Data Export/Import Logging

**Steps:**
1. Export data
2. Import data
3. Check audit logs

**Expected Result:**
- ✅ Export action logged
- ✅ Import action logged with record counts
- ✅ Success/failure status
- ✅ Can audit data movements

#### Test Case 11.8: Configuration Change Logging

**Steps:**
1. Change LLM provider settings
2. Update primary LLM provider
3. Check audit logs

**Expected Result:**
- ✅ Config changes logged (config_change)
- ✅ Old/new configuration captured
- ✅ Provider and settings shown
- ✅ Can trace configuration history

#### Test Case 11.9: API Key Lifecycle Logging

**Steps:**
1. Create LLM provider with API key (api_key_created)
2. Update API key
3. Delete provider (api_key_deleted)
4. Check audit logs

**Expected Result:**
- ✅ API key creation logged (key not stored in log)
- ✅ API key updates logged
- ✅ API key deletion logged
- ✅ Security events tracked

---

### 12. Help System

#### Test Case 12.1: Tutorial Manager

**Steps:**
1. Login as new user
2. View tutorial prompts
3. Start tutorial
4. Complete tutorial
5. Check help_interactions table

**Expected Result:**
- ✅ Tutorial offered to new users
- ✅ Tutorial start tracked (tutorial_start)
- ✅ Tutorial completion tracked (tutorial_complete)
- ✅ Progress saved
- ✅ Can replay tutorial

#### Test Case 12.2: Tutorial Dismissal

**Steps:**
1. View tutorial prompt
2. Click "Dismiss" or "Skip"
3. Check tracking

**Expected Result:**
- ✅ Dismissal tracked (tutorial_dismiss)
- ✅ Tutorial not shown again
- ✅ Can access tutorials later from help menu
- ✅ Dismissal preferences saved

#### Test Case 12.3: Context Helper

**Steps:**
1. Navigate to various pages
2. Click help icon/button
3. View contextual help

**Expected Result:**
- ✅ Help content relevant to current page
- ✅ Feature-specific guidance shown
- ✅ Links to full documentation
- ✅ Help interactions tracked

#### Test Case 12.4: Help Interaction Tracking

**Steps:**
1. Access help on various features
2. Check help_interactions table
3. Verify tracking

**Expected Result:**
- ✅ Each help view tracked (help_view)
- ✅ Feature and element captured
- ✅ Context stored (current page, user state)
- ✅ Timestamp recorded

#### Test Case 12.5: Feedback Collection

**Steps:**
1. View help content
2. Click "Was this helpful?" (Yes/No)
3. Submit feedback

**Expected Result:**
- ✅ Feedback captured (helpful: true/false)
- ✅ Optional text feedback accepted
- ✅ Feedback linked to help interaction
- ✅ Can analyze helpfulness

#### Test Case 12.6: Recovery Feature Usage

**Steps:**
1. Encounter error or stuck state
2. Use recovery feature (if available)
3. Check tracking

**Expected Result:**
- ✅ Recovery usage tracked (recovery_used)
- ✅ Error context captured
- ✅ Recovery successful/failed logged
- ✅ Can identify problem areas

---

### 13. Platform Features

#### Test Case 13.1: Cross-Platform Database Paths

**Steps:**
1. Run application on different platforms:
   - Linux: ~/.config/clientats/
   - macOS: ~/Library/Application Support/clientats/
   - Windows: %APPDATA%/clientats/
2. Verify database location

**Expected Result:**
- ✅ Database created in correct platform directory
- ✅ Path resolution automatic
- ✅ Permissions correct
- ✅ Can find database on all platforms

#### Test Case 13.2: Cross-Platform Upload Directories

**Steps:**
1. Upload files on different platforms
2. Check upload directory

**Expected Result:**
- ✅ Uploads stored in platform-specific directory
- ✅ Directory created if missing
- ✅ File paths work on all platforms
- ✅ No hardcoded paths

#### Test Case 13.3: Cross-Platform Backup Directories

**Steps:**
1. Run backup on different platforms
2. Check backup location

**Expected Result:**
- ✅ Backups in platform-specific directory
- ✅ Path resolution correct
- ✅ Backups accessible
- ✅ No permission issues

#### Test Case 13.4: Tauri Desktop App Build

**Steps:**
1. Build desktop app:
   ```bash
   cd src-tauri
   cargo tauri build
   ```
2. Install and run

**Expected Result:**
- ✅ Build succeeds on platform
- ✅ Installer created
- ✅ App runs standalone
- ✅ No web browser needed

#### Test Case 13.5: Tauri Desktop App - Database Isolation

**Steps:**
1. Run web version and desktop version
2. Create data in each
3. Verify separation

**Expected Result:**
- ✅ Each has separate database
- ✅ Data not mixed
- ✅ Can run both simultaneously
- ✅ Import/export for data transfer

#### Test Case 13.6: Tauri Desktop App - Auto-Updates (If Implemented)

**Steps:**
1. Check for updates in desktop app
2. Trigger update (if available)

**Expected Result:**
- ✅ Update check works
- ✅ Download and install smooth
- ✅ Data preserved across updates
- ✅ User notified of updates

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

### Large Dataset Performance

**Steps:**
1. Create 500+ job interests
2. Create 200+ applications
3. Create 50+ resumes
4. Test search, filtering, sorting operations

**Expected Result:**
- ✅ Search remains fast (< 1 second)
- ✅ Pagination handles large datasets
- ✅ No N+1 query problems
- ✅ Database queries optimized

### LLM Response Time Under Load

**Steps:**
1. Queue 10 scraping jobs simultaneously
2. Monitor processing times
3. Check for degradation

**Expected Result:**
- ✅ Average scrape time acceptable (< 60s)
- ✅ No significant slowdown with concurrent requests
- ✅ Queue processes efficiently
- ✅ Timeouts configured appropriately

### File Upload Performance

**Steps:**
1. Upload large resume (8-10 MB)
2. Monitor upload time and memory usage
3. Verify database storage

**Expected Result:**
- ✅ Upload completes in reasonable time (< 30s)
- ✅ Memory usage acceptable
- ✅ File stored correctly in database
- ✅ Download works for large files

---

## Security Testing

### CSRF Protection Verification

**Steps:**
1. Open DevTools Network tab
2. Perform POST request (create interest)
3. Check request headers

**Expected Result:**
- ✅ CSRF token present in requests
- ✅ Requests without token rejected
- ✅ Token rotates per session
- ✅ Token validated on server

### Session Cookie Security

**Steps:**
1. Login
2. Open DevTools → Application → Cookies
3. Inspect session cookie

**Expected Result:**
- ✅ HttpOnly flag set
- ✅ Secure flag set (in production)
- ✅ SameSite attribute configured
- ✅ Cookie domain correct

### Password Hashing

**Steps:**
1. Register user
2. Check database for hashed_password field

**Expected Result:**
- ✅ Password hashed with bcrypt
- ✅ No plaintext passwords stored
- ✅ Hash format correct (bcrypt $2b$)
- ✅ Cannot reverse hash

### Input Sanitization - XSS Prevention

**Steps:**
1. Create job interest with script tags in title:
   ```
   <script>alert('XSS')</script>
   ```
2. View interest details

**Expected Result:**
- ✅ Script not executed
- ✅ HTML escaped in display
- ✅ No JavaScript injection possible
- ✅ Content Security Policy enforced

### SQL Injection Prevention

**Steps:**
1. Try SQL injection in search:
   ```
   ' OR '1'='1
   ```
2. Try in other input fields

**Expected Result:**
- ✅ No SQL injection possible
- ✅ Parameterized queries used
- ✅ Input validation prevents injection
- ✅ Error messages don't leak schema info

### API Key Encryption

**Steps:**
1. Configure LLM provider with API key
2. Check database llm_settings table
3. Inspect api_key field

**Expected Result:**
- ✅ API key encrypted in database
- ✅ Not stored in plaintext
- ✅ Decryption works for API calls
- ✅ Key never exposed in logs or UI

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

### Test Case: Database Error

**Steps:**
1. *Simulate error*: Rename the database file `clientats_dev.db` to something else temporarily while app is running, or change permissions to read-only.
2. Try accessing dashboard
3. Try health check:
   ```bash
   curl http://localhost:4000/health/ready
   ```

**Expected Result:**
- ✅ Dashboard shows error or 500 page
- ✅ Health check returns 503
- ✅ Error message is helpful (logs check)

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

### 1. User Authentication & Profile (10 tests)
- [ ] User registration
- [ ] User login/logout
- [ ] Protected routes
- [ ] Password validation
- [ ] Email validation
- [ ] User profile update
- [ ] Change password
- [ ] Primary LLM provider selection
- [ ] Invalid credentials handling
- [ ] Session timeout

### 2. Dashboard & Navigation (4 tests)
- [ ] Dashboard access and layout
- [ ] Quick links functionality
- [ ] LLM setup banner
- [ ] Toggle closed applications

### 3. Job Interest Management (16 tests)
- [ ] Create job interest
- [ ] Edit job interest
- [ ] View job interest details
- [ ] Delete job interest
- [ ] Status workflow (5 statuses)
- [ ] Priority management (low/medium/high)
- [ ] Work model selection (remote/hybrid/on-site)
- [ ] Salary range validation
- [ ] Full-text search
- [ ] Advanced filtering (multiple criteria)
- [ ] Sorting options (5+ fields)
- [ ] Pagination
- [ ] Notes management
- [ ] Aggregate statistics

### 4. Web Scraping & LLM (9 tests)
- [ ] Scrape from LinkedIn
- [ ] Manual job entry fallback
- [ ] Error handling
- [ ] Job board detection (6+ boards)
- [ ] Generic mode scraping
- [ ] Screenshot-based multimodal extraction
- [ ] Auto-save after scraping
- [ ] Async background scraping
- [ ] Network error handling

### 5. LLM Configuration (13 tests)
- [ ] Access LLM settings
- [ ] Configure Ollama (local)
- [ ] Configure Gemini (cloud)
- [ ] Test connection
- [ ] Provider status tracking
- [ ] Model selection (default/vision/text)
- [ ] Provider priority/reordering
- [ ] Enable/disable provider
- [ ] Circuit breaker behavior
- [ ] Provider fallback chain
- [ ] Retry logic with exponential backoff
- [ ] API key validation
- [ ] LLM setup wizard

### 6. Resume Management (14 tests)
- [ ] Upload resume (PDF)
- [ ] Upload DOCX resume
- [ ] Invalid resume handling
- [ ] Delete resume
- [ ] Edit resume metadata
- [ ] Set default resume
- [ ] File size validation
- [ ] Resume text extraction
- [ ] Download resume
- [ ] Resume database storage
- [ ] Multiple resume management

### 7. Cover Letter Management (9 tests)
- [ ] Create cover letter template
- [ ] Delete cover letter template
- [ ] Edit cover letter template
- [ ] Set default template
- [ ] Template variables
- [ ] AI cover letter generation (text-based)
- [ ] AI cover letter generation (multimodal)
- [ ] Download cover letter PDF
- [ ] Cover letter editor in wizard

### 8. Job Application Tracking (12 tests)
- [ ] Create application record
- [ ] Update application status
- [ ] Delete application
- [ ] Edit application
- [ ] Application status workflow (8 statuses)
- [ ] Filter by status
- [ ] Filter by date range
- [ ] Search applications
- [ ] Sort applications
- [ ] Application timeline display
- [ ] Application statistics
- [ ] Conversion wizard (4 steps)

### 9. Application Events (13 tests)
- [ ] Create Applied event
- [ ] Create Contact event
- [ ] Create Phone Screen event
- [ ] Create Interview events
- [ ] Create Follow-Up event
- [ ] Create Offer event
- [ ] Create Rejection event
- [ ] Create Withdrawn event
- [ ] Edit application event
- [ ] Delete application event
- [ ] Contact email validation
- [ ] Follow-up date scheduling
- [ ] Phone number validation

### 10. Data Import/Export (9 tests)
- [ ] Export user data
- [ ] Import user data
- [ ] Export format validation
- [ ] Resume base64 encoding in export
- [ ] Import validation and version checking
- [ ] Import statistics
- [ ] Import transaction rollback
- [ ] Export with large dataset
- [ ] Import duplicate handling

### 11. Background Jobs - Oban (10 tests)
- [ ] Async job scraping
- [ ] Job status tracking
- [ ] Job cancellation
- [ ] Retry logic (max 3 attempts)
- [ ] Queue statistics
- [ ] Nightly backup worker
- [ ] Backup rotation (2 days)
- [ ] Scheduled data export
- [ ] Job queue management
- [ ] Concurrent job processing

### 12. API Endpoints (9 tests)
- [ ] API versioning (v1/v2/legacy)
- [ ] POST /api/v1/scrape_job
- [ ] GET /api/v1/llm/providers
- [ ] GET /api/v1/llm/config
- [ ] Swagger UI documentation
- [ ] ReDoc documentation
- [ ] OpenAPI specification
- [ ] API error responses
- [ ] API rate limiting

### 13. Audit Logging (9 tests)
- [ ] Audit log creation for user actions
- [ ] IP address and user agent tracking
- [ ] Old/new values tracking
- [ ] Status tracking (success/failure)
- [ ] Immutable audit records
- [ ] File operations logging
- [ ] Data export/import logging
- [ ] Configuration change logging
- [ ] API key lifecycle logging

### 14. Help System (6 tests)
- [ ] Tutorial manager
- [ ] Tutorial dismissal
- [ ] Context helper
- [ ] Help interaction tracking
- [ ] Feedback collection
- [ ] Recovery feature usage

### 15. Platform Features (6 tests)
- [ ] Cross-platform database paths
- [ ] Cross-platform upload directories
- [ ] Cross-platform backup directories
- [ ] Tauri desktop app build
- [ ] Desktop app database isolation
- [ ] Desktop app auto-updates

### 16. Database & Health Checks (4 tests)
- [ ] Simple health check
- [ ] Database ready check
- [ ] Diagnostics endpoint
- [ ] Metrics endpoint

### 17. Performance (5 tests)
- [ ] Database connection pool load test
- [ ] Concurrent user test
- [ ] Large dataset performance (500+ records)
- [ ] LLM response time under load
- [ ] File upload performance (large files)

### 18. Security (6 tests)
- [ ] CSRF protection verification
- [ ] Session cookie security (HttpOnly, Secure, SameSite)
- [ ] Password hashing (bcrypt)
- [ ] Input sanitization - XSS prevention
- [ ] SQL injection prevention
- [ ] API key encryption

### 19. Browser DevTools (3 test areas)
- [ ] Network tab checks (no errors, proper methods)
- [ ] Console tab checks (no JS errors)
- [ ] Application tab checks (session cookies)

### 20. Error Scenarios (3 tests)
- [ ] Database error handling
- [ ] Invalid form data
- [ ] Session timeout

### Browser Compatibility
- [ ] Works on Chrome
- [ ] Works on Firefox
- [ ] Works on Safari (if on macOS)
- [ ] Mobile responsive

---

## Test Coverage Summary

**Total Test Cases:** ~180
**Core Feature Coverage:** ~85%
**Critical Paths:** 100%
**Edge Cases & Error Handling:** ~70%
**Security & Performance:** ~75%

**Test Categories:**
- Authentication & User Management: 10 tests
- Job Interest Management: 16 tests
- Job Application Tracking: 12 tests
- Application Events: 13 tests
- Resume & Cover Letter Management: 23 tests
- LLM & AI Features: 22 tests
- Background Jobs: 10 tests
- API Endpoints: 9 tests
- Data Management: 9 tests
- Audit & Help Systems: 15 tests
- Platform & Infrastructure: 10 tests
- Performance & Security: 11 tests
- Health & Monitoring: 4 tests
- Browser & Error Testing: 6 tests

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

# Restart Ollama (if running via Docker profile)
docker-compose restart ollama

# Or if running locally:
# Ensure "ollama serve" is running in a terminal
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
