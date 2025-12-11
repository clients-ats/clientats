# Contacts Feature

## Overview
Added the ability to manage contacts (recruiters, hiring managers, etc.) directly from the job application detail view.

## What's New

### Contact Management on Application Page
When viewing a job application at `/dashboard/applications/:id`, you'll now see a **Contacts** section that allows you to:

- **View all contacts** associated with the application
- **Add new contacts** with their information
- **Delete contacts** you no longer need

## Features

### Contact Information
Each contact can include:
- **Name** (required)
- **Email** (optional, clickable mailto link)
- **Phone** (optional, clickable tel link)
- **Role/Title** (optional, e.g., "Hiring Manager", "Recruiter")

### Visual Design

#### Empty State
When no contacts exist:
- User-friendly icon and message
- Clear call-to-action to add first contact

#### Contact Cards
Each contact is displayed in a card with:
- **Avatar circle** with first letter of name
- **Name and role** prominently displayed
- **Contact details** (email, phone) with icons and clickable links
- **Date added** timestamp
- **Delete button** for quick removal

#### Add Contact Form
Clean, inline form with:
- Name and Email fields (top row)
- Phone and Role/Title fields (bottom row)
- Toggle button to show/hide form
- Changes to "Cancel" when form is visible

### User Experience

1. **View contacts**: Automatically loaded when viewing application
2. **Add contact**: Click "Add Contact" button
3. **Fill form**: Enter contact details in the inline form
4. **Save**: Click "Save Contact" button
5. **Delete**: Click trash icon on any contact card

### Technical Implementation

#### Backend
- Uses existing `ApplicationEvent` schema with `event_type: "contact"`
- Leverages `Jobs.create_application_event/1` for persistence
- Filters events by type to show only contacts

#### Frontend
- LiveView for real-time updates
- No page refresh needed when adding/deleting
- Form validation (name required, email format validated)
- Responsive grid layout (1 column mobile, 2 columns desktop)

### Styling
- Consistent with existing Clientats design
- Card-based layout for easy scanning
- Hover effects for interactivity
- Icon integration using Heroicons
- Color-coded elements (blue for primary, red for delete)

## Location in App

Navigate to any job application:
1. Go to Dashboard
2. Click on any application in "Applications" section
3. Scroll down to see the new "Contacts" section

## Example Use Cases

1. **Recruiter contact**: Store recruiter's email/phone for follow-up
2. **Hiring manager**: Track the decision-maker's contact info
3. **Internal referral**: Keep contact details for the person who referred you
4. **Multiple touchpoints**: Track different people you've interacted with

## Database
No migration needed - uses existing `application_events` table with these fields:
- `event_type` = "contact"
- `contact_person` - name
- `contact_email` - email address
- `contact_phone` - phone number
- `notes` - role/title
- `event_date` - when contact was added

## Future Enhancements (Ideas)
- Edit contact inline
- Link contacts to specific interview rounds
- Add contact photo/avatar
- Export contacts list
- Filter/search contacts
- Contact activity timeline
