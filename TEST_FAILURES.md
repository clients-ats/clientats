# Test Failure Report

**Generated:** 2025-12-18
**Total Failures:** 456 tests
**Total Passed:** 234 tests
**Excluded:** 4 tests

## Summary by Module

| Module | Failures | Beads Task |
|--------|----------|-----------|
| JobManagementLiveViewTest | 17 | clientats-xw2 |
| DocumentManagementLiveViewTest | 15 | clientats-zuv |
| JobInterestLive.ScrapeTest | 14 | clientats-26z |
| AuthenticationLiveViewTest | 14 | clientats-58e |
| CoverLetterLiveTest | 10 | clientats-b7d |
| AccountsTest | 9 | clientats-395 |
| LLM.IntegrationTest | 7 | clientats-jjq |
| UserSessionControllerTest | 6 | clientats-cyg |
| UserLoginLiveTest | 3 | clientats-mn2 |
| LLM.ServiceTest | 3 | clientats-ae8 |
| LLM.GeminiServiceTest | 1 | clientats-9a3 |

## Detailed Failures

### JobManagementLiveViewTest (17 failures) - clientats-xw2

1. test Edge cases and error handling handles non-existent job interest
2. test JobInterestLive.Show shows accessible heading
3. test JobInterestLive.New validates salary range
4. test Edge cases and error handling prevents viewing other users' interests
5. test JobInterestLive.Edit updates job interest
6. test Job interest to application conversion converts interest to application
7. test JobInterestLive.New creates job interest with valid data
8. test Accessibility in job management status badges are accessible
9. test Accessibility in job management job list has accessible table structure
10. test JobInterestLive.New form has accessible structure
11. test JobInterestLive.New validates required fields
12. test JobInterestLive.Edit edit form validates same as create
13. test Edge cases and error handling handles very long job descriptions
14. test DashboardLive filtering toggle shows/hides closed applications
15. test Edge cases and error handling handles concurrent edits gracefully
16. test JobInterestLive.Show deletes interest with confirmation
17. test JobInterestLive.New allows optional fields to be empty

### DocumentManagementLiveViewTest (15 failures) - clientats-zuv

1. test CoverLetterLive.New form is accessible
2. test ResumeLive.Index sets resume as default
3. test CoverLetterLive.Edit updates template
4. test Edge cases handles very long template content
5. test ResumeLive.New upload form is accessible
6. test ResumeLive.Index displays empty state when no resumes
7. test ResumeLive.Index resume list is accessible
8. test CoverLetterLive.Index deletes template with confirmation
9. test ResumeLive.Index deletes resume with confirmation
10. test Edge cases prevents setting non-default as default when already has default
11. test CoverLetterLive.New creates template with valid data
12. test ResumeLive.Index provides delete button
13. test CoverLetterLive.Index sets template as default
14. test ResumeLive.New uploads resume with file validation
15. test CoverLetterLive.Edit updates cover letter

### JobInterestLive.ScrapeTest (14 failures) - clientats-26z

1. test Job Scrape LiveView shows provider selection by default
2. test Job Scrape LiveView shows URL validation errors
3. test Provider Selection UI shows all provider options
4. test Provider Selection UI shows provider descriptions
5. test Ollama Integration disables import button when checking Ollama
6. test Ollama Integration shows Ollama unavailable error
7. test Job URL validation validates LinkedIn URLs
8. test Job URL validation validates Indeed URLs
9. test Job URL validation validates generic job board URLs
10. test Job URL validation validates Glassdoor URLs
11. test Error handling shows generic error for network issues
12. test Error handling shows user-friendly error messages
13. test Form interactions submits valid URL for extraction
14. test Form interactions shows loading state during extraction

### AuthenticationLiveViewTest (14 failures) - clientats-58e

1. test UserRegistrationLive redirects authenticated users to dashboard
2. test UserRegistrationLive renders registration form
3. test UserRegistrationLive submits valid registration form
4. test UserLoginLive displays error for invalid credentials
5. test UserRegistrationLive validates email format in real-time
6. test Form accessibility edge cases registration form handles special characters
7. test UserLoginLive renders login form
8. test UserLoginLive displays login form with accessible labels
9. test UserRegistrationLive provides link to login page
10. test UserRegistrationLive registration form has accessible structure
11. test UserLoginLive redirects authenticated users to dashboard
12. test UserLoginLive submits login form
13. test UserRegistrationLive validates password confirmation matches
14. test Form accessibility edge cases registration form handles long input values

### CoverLetterLiveTest (10 failures) - clientats-b7d

1. test CoverLetterLive.Index displays cover letters
2. test CoverLetterLive.New creates cover letter
3. test CoverLetterLive.Edit edits cover letter
4. test CoverLetterLive.Show displays cover letter details
5. test CoverLetterLive.Delete deletes cover letter
6. test Cover letter template selection shows available templates
7. test Cover letter customization allows custom content
8. test Cover letter export generates document
9. test Cover letter accessibility maintains accessibility standards
10. test Cover letter validation validates required fields

### AccountsTest (9 failures) - clientats-395

1. test User registration creates user with valid data
2. test User login authenticates valid credentials
3. test User password reset updates password
4. test User profile updates user information
5. test User email verification verifies email address
6. test User account deletion removes user
7. test User permissions enforces access control
8. test User roles assigns correct roles
9. test User sessions manages user sessions

### LLM.IntegrationTest (7 failures) - clientats-jjq

1. test Error handling and edge cases handles invalid provider specification
2. test Error handling and edge cases handles empty content
3. test Full workflow integration extracts job data and creates job interest
4. test Prompt generation and parsing generates valid prompts for different scenarios
5. test Full workflow integration handles different extraction modes
6. test Error handling and edge cases handles very long URLs
7. test Cache functionality cache stores and retrieves data correctly

### UserSessionControllerTest (6 failures) - clientats-cyg

1. test Login creates user session
2. test Logout destroys user session
3. test Session timeout expires old sessions
4. test Concurrent sessions prevents multiple concurrent sessions
5. test Session security validates session tokens
6. test Session recovery recovers from session errors

### UserLoginLiveTest (3 failures) - clientats-mn2

1. test UserLoginLive form submission handles valid credentials
2. test UserLoginLive error display shows login errors
3. test UserLoginLive form reset clears form fields

### LLM.ServiceTest (3 failures) - clientats-ae8

1. test get_config/0 configuration contains expected keys
2. test extract_job_data/1 processes job extraction
3. test handle_extraction_response/1 processes LLM response

### LLM.GeminiServiceTest (1 failure) - clientats-9a3

1. test Gemini provider integration Gemini env defaults are properly configured

## Common Issues

Based on the test failures, there appear to be several categories of issues:

1. **LiveView Integration Issues** - Many LiveView tests are failing, suggesting issues with:
   - Component rendering
   - Event handling
   - Form submission
   - Navigation and redirects

2. **Authentication Flow Problems** - Registration and login tests failing:
   - Session management
   - User creation
   - Credential validation

3. **LLM Integration Issues** - Integration tests for LLM services failing:
   - Service configuration
   - Data extraction
   - Response handling

4. **Document Management** - Resume and cover letter tests failing:
   - Upload functionality
   - Template management
   - File handling

5. **Job Interest Management** - Tests for job scraping and interest tracking:
   - URL validation
   - Data extraction
   - UI interactions

## Next Steps

1. Start with the highest-impact modules (most failures):
   - clientats-xw2 (17 failures) - Job Management
   - clientats-zuv (15 failures) - Document Management
   - clientats-26z (14 failures) - Job Scraping
   - clientats-58e (14 failures) - Authentication

2. Run tests in isolation to identify root causes
3. Fix common patterns (likely to fix multiple tests)
4. Verify fixes don't introduce regressions
