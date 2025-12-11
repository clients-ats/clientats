# Job Posting Scraping Feature

## Overview
A wizard-based interface for adding new job interests that can automatically scrape job posting URLs using Playwright to extract key information like company name, position title, job description, location, etc.

## Features

### Step 1: URL Input
- Simple form with URL input field
- Validate URL format
- Submit button to trigger scraping
- Loading state during scraping

### Step 2: Scraping Process
- Use Playwright to visit the URL
- Extract structured data from common job boards:
  - LinkedIn
  - Indeed
  - Glassdoor
  - Company career pages
- Handle authentication/cookies if needed
- Timeout and error handling

### Step 3: Data Extraction
Extract the following fields when available:
- **Company Name**
- **Position Title**
- **Job Description** (full text)
- **Location** (remote/hybrid/on-site)
- **Work Model** (remote, hybrid, on-site)
- **Salary Range** (min/max)
- **Job Posting Date**
- **Application Deadline**
- **Required Skills/Qualifications**

### Step 4: Review & Edit
- Display extracted data in a form
- Allow user to review and edit any field
- Pre-fill job interest form with scraped data
- Manual override capability

### Step 5: Save
- Create job interest record
- Option to immediately convert to application
- Success confirmation

## Technical Implementation

### Backend
1. **Scraping Service**:
   - Use Playwright via Elixir NPM package or port
   - Headless browser automation
   - Job board specific selectors
   - Error handling and retries

2. **API Endpoint**:
   - `/api/scrape_job` POST endpoint
   - Accepts URL parameter
   - Returns structured JSON data
   - Async processing with timeout

### Frontend
1. **Wizard LiveView**:
   - Multi-step form with navigation
   - Loading states and progress indicators
   - Error handling UI
   - Preview of extracted data

2. **URL Validation**:
   - Basic URL format validation
   - Domain whitelisting for known job boards
   - Security warnings for unknown domains

### Data Structure
```elixir
%{
  url: "https://www.linkedin.com/jobs/view/123456789",
  company_name: "Tech Corp Inc",
  position_title: "Senior Software Engineer",
  job_description: "We're looking for...",
  location: "San Francisco, CA",
  work_model: "hybrid",
  salary_min: 120000,
  salary_max: 150000,
  posting_date: "2024-03-15",
  skills: ["Elixir", "Phoenix", "PostgreSQL", "AWS"],
  source: "linkedin"
}
```

## Supported Job Boards

### Tier 1 (Full Support)
- LinkedIn (with session handling)
- Indeed
- Glassdoor
- AngelList
- Well-known company career pages

### Tier 2 (Basic Support)
- Generic job board detection
- Fallback to meta tags and structured data
- Manual review required

### Tier 3 (Manual Entry)
- Unknown domains
- PDF/Document-based postings
- Image-based postings

## User Experience Flow

1. **Start**: User clicks "Add Job Interest" -> "Import from URL"
2. **Enter URL**: User pastes job posting URL
3. **Scrape**: System processes URL (show loading spinner)
4. **Review**: User sees extracted data with edit options
5. **Save**: User confirms and saves as job interest

## Error Handling

- **Invalid URL**: Clear error message with examples
- **Unsupported site**: Fallback to manual entry with pre-filled URL
- **Scraping failure**: Error details with retry option
- **Rate limiting**: Exponential backoff and user notification
- **Timeout**: Configurable timeout with progress feedback

## Security Considerations

- **URL validation**: Prevent SSRF attacks
- **Domain whitelisting**: Only allow known job boards
- **User agent rotation**: Avoid bot detection
- **Rate limiting**: Prevent abuse
- **Data sanitization**: Clean extracted HTML content

## Future Enhancements

- Browser extension for one-click import
- Email parsing for job postings
- PDF/document parsing
- Multi-language support
- Job board API integration (where available)
- Historical price/salary tracking
- Similar jobs recommendation

## Implementation Priority

1. Core scraping functionality (Playwright integration)
2. Basic wizard UI
3. LinkedIn/Indeed support
4. Error handling and validation
5. Additional job board support
6. Performance optimization
