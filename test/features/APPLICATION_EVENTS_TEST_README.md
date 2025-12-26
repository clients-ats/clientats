# Application Events & Timeline E2E Test Suite

## Overview

This test suite provides comprehensive end-to-end testing for the Application Events & Timeline feature in ClientATS, following the specifications outlined in the E2E Testing Guide (sections 7A.1-7A.13).

**Test File:** `/home/jsightler/project/clientats/test/features/application_events_test.exs`

**Beads Issue:** clientats-7h33

## Test Coverage

The test suite covers all 13 test cases specified in the E2E Testing Guide:

### Event Type Testing (Test Cases 7A.1 - 7A.8)

1. **Applied Event** (7A.1) - Create a basic application event
2. **Contact Event** (7A.2) - Create contact with email and phone validation
3. **Phone Screen Event** (7A.3) - Create phone screen with follow-up date
4. **Technical Screen Event** (7A.4) - Create technical interview event
5. **Onsite Interview Event** (7A.4) - Create onsite interview event
6. **Follow-Up Event** (7A.5) - Create follow-up with next action date
7. **Offer Event** (7A.6) - Create offer event
8. **Rejection Event** (7A.7) - Create rejection event
9. **Withdrawn Event** (7A.8) - Create withdrawn event

### Event Management (Test Cases 7A.9 - 7A.10)

10. **Edit Event** (7A.9) - Update existing event details
11. **Delete Event** (7A.10) - Remove event from timeline

### Validation Testing (Test Cases 7A.11 - 7A.13)

12. **Email Validation** (7A.11) - Validate contact email format
13. **Phone Validation** (7A.13) - Accept various phone number formats
14. **Follow-Up Scheduling** (7A.12) - Schedule future follow-up dates

### Additional Tests

15. **Timeline Display** - Verify chronological event ordering
16. **Multiple Event Types** - Display all event types in timeline
17. **Invalid Application ID** - Verify error handling for non-existent applications
18. **Required Field Validation** - Verify required fields are enforced

## Test Structure

### Test Setup

Each test follows this pattern:

```elixir
test "test description", %{session: session} do
  user = create_user_and_login(session)
  application = create_job_application(user.id)

  # Test actions and assertions
end
```

### Helper Functions

1. **create_user()** - Generates unique user data
2. **create_user_and_login(session)** - Creates user and logs into the application
3. **create_job_application(user_id)** - Creates a test job application
4. **create_application_event(application_id, attrs)** - Creates an event programmatically

## Running the Tests

### Prerequisites

The tests require a properly configured test environment with:

- Wallaby for browser automation
- ChromeDriver or compatible WebDriver
- Test database configured
- No conflicting processes on port 4002

### Execute Tests

```bash
# Run all application events tests
mix test --only feature test/features/application_events_test.exs

# Run a specific test
mix test --only feature test/features/application_events_test.exs:9

# Run with verbose output
mix test --only feature test/features/application_events_test.exs --trace
```

### Troubleshooting

**Port Already in Use:**
```bash
# Kill process on port 4002
lsof -ti:4002 | xargs kill -9

# Wait and retry
sleep 2
mix test --only feature test/features/application_events_test.exs
```

**Wallaby Driver Issues:**
```bash
# Ensure ChromeDriver is installed and in PATH
chromedriver --version

# Or use alternative driver configuration in test/support/feature_case.ex
```

**Database Issues:**
```bash
# Reset test database
MIX_ENV=test mix ecto.reset

# Or just drop and recreate
MIX_ENV=test mix ecto.drop
MIX_ENV=test mix ecto.create
MIX_ENV=test mix ecto.migrate
```

## Test Scenarios Covered

### 1. Event Creation Flow

Each event type test verifies:
- Navigation to application detail page
- Opening the event form ("Add Activity" button)
- Selecting event type from dropdown
- Filling in event-specific fields
- Saving the event
- Verifying event appears in timeline

### 2. Validation Testing

**Email Validation:**
- Valid format: `user@domain.com`
- Invalid format: `invalid-email` (should show error)

**Phone Validation:**
- Format 1: `(555) 123-4567`
- Format 2: `555-123-4567`
- Format 3: `5551234567`

**Required Fields:**
- Event type must be selected
- Event date must be provided
- Form should not submit with missing required fields

### 3. Data Integrity

**Timeline Display:**
- Events displayed in chronological order
- All event types visible with correct labels
- Event counts accurate

**Event Updates:**
- Modified events reflect new values
- Old values no longer visible after update

**Event Deletion:**
- Deleted events removed from timeline
- No orphaned data

## Form Field Mappings

The tests interact with the following form fields:

```elixir
select[name='event_type']        # Event type dropdown
input[name='event_date']          # Event date picker
input[name='contact_person']      # Contact person name
input[name='contact_email']       # Contact email address
input[name='contact_phone']       # Contact phone number
input[name='follow_up_date']      # Follow-up date picker
textarea[name='notes']            # Event notes
```

## Expected Event Types

The following event types are supported and tested:

```elixir
- "applied"             # Applied
- "contact"             # Contact
- "phone_screen"        # Phone Screen
- "technical_screen"    # Technical Screen
- "interview_onsite"    # Onsite Interview
- "follow_up"           # Follow-up
- "offer"               # Offer
- "rejection"           # Rejection
- "withdrawn"           # Withdrawn
```

## Timeline Display Expectations

Events should display with:
- Event type label (formatted, e.g., "Phone Screen")
- Event date
- Contact person (if provided)
- Contact email (if provided)
- Contact phone (if provided)
- Follow-up date (if provided)
- Notes

## Assertions Used

The tests use Wallaby assertions:

- `assert_has/2` - Verify element exists with text
- `refute_has/2` - Verify element does not exist
- `click/2` - Click button or link
- `fill_in/3` - Fill in form field
- `visit/2` - Navigate to page

## Test Execution Notes

1. **Async:** Tests run with `async: false` to prevent database conflicts
2. **Feature Tag:** Tests are tagged with `@moduletag :feature`
3. **Database Sandbox:** Each test runs in a transaction, rolled back after completion
4. **Unique Users:** Each test creates a unique user to avoid conflicts

## CI/CD Integration

These tests can be integrated into CI/CD pipelines:

```yaml
# GitHub Actions example
- name: Run Application Events E2E Tests
  run: |
    mix ecto.reset
    mix test --only feature test/features/application_events_test.exs
```

## Maintenance

When updating the application:

1. **Form Changes:** Update field selectors if form HTML changes
2. **New Event Types:** Add test cases for new event types
3. **Validation Rules:** Update validation tests if rules change
4. **UI Labels:** Update button text if labels change (e.g., "Add Activity")

## Related Files

- **Schema:** `lib/clientats/jobs/application_event.ex`
- **Context:** `lib/clientats/jobs.ex`
- **LiveView:** `lib/clientats_web/live/job_application_live/show.ex`
- **Migration:** `priv/repo/migrations/20251113052704_create_application_events.exs`
- **E2E Guide:** `docs/E2E_TESTING_GUIDE.md` (sections 7A.1-7A.13)

## Success Criteria

All 18 tests should pass, verifying:

- All 9 event types can be created
- Events display correctly in timeline
- Email and phone validation works
- Follow-up dates can be scheduled
- Events can be edited and deleted
- Timeline displays events chronologically
- Required field validation is enforced

## Test Metrics

- **Total Tests:** 18
- **Event Types Covered:** 9
- **Validation Tests:** 3
- **Management Tests:** 2
- **Display Tests:** 2
- **Error Handling Tests:** 2
- **Code Coverage Target:** 100% of event management code paths
