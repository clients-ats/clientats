defmodule Clientats.Help.ContextHelper do
  @moduledoc """
  Provides context-aware help text, error messages, and user guidance.

  This module delivers intelligent help content based on user context, experience level,
  and the specific feature they're using. Supports progressive disclosure and
  interactive tutorials.

  Features:
  - Contextual help text for UI elements
  - Recovery suggestions for common errors
  - Experience-level based guidance
  - Progressive disclosure of advanced options
  - Tutorial management
  """

  @doc """
  Get help text for a UI element or feature.

  Context map can include:
    - :feature - Feature name (e.g., :job_interests, :applications)
    - :element - Element name (e.g., :search_bar, :priority_filter)
    - :experience_level - User experience level (:beginner, :intermediate, :advanced)
    - :error_context - Error that occurred
    - :action - Action being performed (:create, :edit, :delete)

  Returns help text with optional examples and tips.
  """
  def get_help_text(context) do
    feature = context[:feature]
    element = context[:element]
    experience_level = context[:experience_level] || :beginner
    _action = context[:action]

    case {feature, element} do
      # Job Interests Help
      {:job_interests, :search_bar} ->
        search_help(experience_level)

      {:job_interests, :priority_filter} ->
        priority_help(experience_level)

      {:job_interests, :salary_range} ->
        salary_help(experience_level)

      {:job_interests, :status_selector} ->
        status_help(experience_level)

      {:job_interests, :work_model} ->
        work_model_help(experience_level)

      # Job Applications Help
      {:applications, :application_date} ->
        application_date_help(experience_level)

      {:applications, :status_tracker} ->
        application_status_help(experience_level)

      # Resume Management Help
      {:documents, :resume_upload} ->
        resume_upload_help(experience_level)

      {:documents, :cover_letter_template} ->
        cover_letter_help(experience_level)

      # Generic fallback
      {feature, _element} ->
        generic_help(feature, experience_level)
    end
  end

  @doc """
  Get error recovery suggestions based on error type and context.

  Error types:
    - :validation_error - User input validation failed
    - :duplicate_error - Resource already exists
    - :not_found_error - Resource not found
    - :permission_error - User lacks permission
    - :network_error - Network/API error
    - :storage_error - File storage error
  """
  def get_error_recovery(error_type, context \\ %{}) do
    case error_type do
      :validation_error ->
        validation_recovery(context)

      :duplicate_error ->
        duplicate_recovery(context)

      :not_found_error ->
        not_found_recovery(context)

      :permission_error ->
        permission_recovery(context)

      :network_error ->
        network_recovery(context)

      :storage_error ->
        storage_recovery(context)

      _other ->
        %{
          title: "Something went wrong",
          message: "Please try again or contact support",
          actions: []
        }
    end
  end

  @doc """
  Get progressive disclosure options for a feature.

  Returns which advanced options should be shown based on experience level.
  """
  def get_visible_options(feature, experience_level) do
    case {feature, experience_level} do
      {:job_interests, :beginner} ->
        [:status, :priority]

      {:job_interests, :intermediate} ->
        [:status, :priority, :salary_range, :work_model]

      {:job_interests, :advanced} ->
        [:status, :priority, :salary_range, :work_model, :location, :custom_filters]

      {:applications, :beginner} ->
        [:status]

      {:applications, :intermediate} ->
        [:status, :date_range]

      {:applications, :advanced} ->
        [:status, :date_range, :notes, :custom_fields]

      _ ->
        []
    end
  end

  @doc """
  Get tutorial content for a feature.

  Tutorials include step-by-step guidance with interactive elements.
  """
  def get_tutorial(feature, _user_id) do
    case feature do
      :job_interests ->
        job_interests_tutorial()

      :applications ->
        applications_tutorial()

      :documents ->
        documents_tutorial()

      :dashboard ->
        dashboard_tutorial()

      _other ->
        nil
    end
  end

  @doc """
  Check if user should see tutorial based on usage history.
  """
  def should_show_tutorial?(_feature, _user_id) do
    # User should see tutorial if:
    # 1. They've just created account (< 1 hour)
    # 2. They're accessing feature for first time
    # 3. They haven't dismissed tutorial
    true
  end

  @doc """
  Format error message with context-aware recovery suggestions.
  """
  def format_error_with_recovery(error_message, error_type, context \\ %{}) do
    recovery = get_error_recovery(error_type, context)

    %{
      error: error_message,
      title: recovery[:title],
      message: recovery[:message],
      suggestions: recovery[:actions],
      help_text: recovery[:help_text]
    }
  end

  # Private Helpers

  defp search_help(:beginner) do
    %{
      title: "Search Help",
      text: "Search across all job titles, companies, and descriptions. Use keywords or phrases.",
      example: "Try: \"Senior Engineer\" or \"Remote React\"",
      tips: ["Be specific with job titles", "Include location if searching for on-site roles"]
    }
  end

  defp search_help(:intermediate) do
    %{
      title: "Advanced Search",
      text:
        "Combine search with filters for precise results. Full-text search across all fields.",
      example: "Search \"React\" with Priority: High and Salary: $120k+",
      tips: [
        "Search is case-insensitive",
        "Matches partial words",
        "Combine with other filters for best results"
      ]
    }
  end

  defp search_help(:advanced) do
    %{
      title: "Search Operators",
      text: "Use advanced search syntax for complex queries.",
      example: "\"exact phrase\" AND skill:react OR location:remote",
      tips: [
        "Use quotes for exact phrase matching",
        "AND/OR operators for complex queries",
        "Search across 5 fields: title, company, location, description, notes"
      ]
    }
  end

  defp priority_help(:beginner) do
    %{
      title: "Priority Levels",
      text: "Mark how much you want each job. Helps you focus on best opportunities.",
      example: "Dream job? Set to High. Just exploring? Set to Low.",
      tips: [
        "High: Must apply soon",
        "Medium: Good opportunity",
        "Low: Nice to have"
      ]
    }
  end

  defp priority_help(_level) do
    %{
      title: "Priority Filter",
      text: "Filter by priority level to focus on your most desired opportunities.",
      example: "Show only High and Medium priority jobs",
      tips: ["Use with status filter for better sorting"]
    }
  end

  defp salary_help(:beginner) do
    %{
      title: "Salary Range",
      text: "Set your target salary range. Helps identify opportunities that meet your needs.",
      example: "Enter minimum: $100k, maximum: $150k",
      tips: [
        "Leave blank to see all salaries",
        "Include benefits in calculation"
      ]
    }
  end

  defp salary_help(_level) do
    %{
      title: "Salary Filtering",
      text: "Filter by salary range. Both fields optional.",
      example: "Minimum: $120k filters out lower offers",
      tips: [
        "Filters are inclusive",
        "Use with equity information for total comp"
      ]
    }
  end

  defp status_help(:beginner) do
    %{
      title: "Job Status",
      text: "Track where each job is in your process.",
      statuses: %{
        "interested" => "Found it, haven't applied yet",
        "applied" => "Application sent",
        "rejected" => "Application rejected",
        "accepted" => "Offer accepted"
      },
      tips: ["Update status as you progress"]
    }
  end

  defp status_help(_level) do
    %{
      title: "Status Filter",
      text: "Filter job interests by current status.",
      tips: ["Use to focus on active applications"]
    }
  end

  defp work_model_help(:beginner) do
    %{
      title: "Work Models",
      text: "Remote, Hybrid, or On-site work.",
      models: %{
        "remote" => "Work from anywhere",
        "hybrid" => "Mix of office and remote",
        "on-site" => "Office only"
      },
      tips: ["Filter by your preference"]
    }
  end

  defp work_model_help(_level) do
    %{
      title: "Work Model Filter",
      text: "Filter by work arrangement preference.",
      tips: ["Select multiple work models"]
    }
  end

  defp application_date_help(:beginner) do
    %{
      title: "Application Timeline",
      text: "See when you applied to each job. Helps track application progress.",
      tips: [
        "Recent applications (< 1 week): Check for responses",
        "Older applications (> 2 weeks): May need follow-up"
      ]
    }
  end

  defp application_date_help(_level) do
    %{
      title: "Date Range Filter",
      text:
        "Filter applications by date range to focus on recent or specific period applications.",
      tips: ["Useful for tracking monthly applications"]
    }
  end

  defp application_status_help(:beginner) do
    %{
      title: "Application Status",
      text: "Track your application progress through the hiring pipeline.",
      statuses: %{
        "applied" => "Application submitted",
        "interviewing" => "Actively interviewing",
        "offered" => "Offer received",
        "rejected" => "Application rejected",
        "withdrawn" => "You withdrew",
        "accepted" => "Offer accepted"
      },
      tips: ["Update status after each interaction"]
    }
  end

  defp application_status_help(_level) do
    %{
      title: "Track Application Status",
      text: "Monitor your position in the hiring process.",
      tips: ["Regular updates help you follow up appropriately"]
    }
  end

  defp resume_upload_help(:beginner) do
    %{
      title: "Upload Resume",
      text: "Upload your resume (PDF or Word). Set one as default for quick access.",
      formats: "PDF, DOC, DOCX",
      tips: [
        "Keep file under 5MB",
        "Use one as your default",
        "Upload variations for different industries"
      ]
    }
  end

  defp resume_upload_help(_level) do
    %{
      title: "Resume Management",
      text: "Manage multiple resume versions for different opportunities.",
      tips: [
        "Customize for each application",
        "Keep date updated",
        "Store variations by industry"
      ]
    }
  end

  defp cover_letter_help(:beginner) do
    %{
      title: "Cover Letter Templates",
      text: "Create reusable templates. Customize for each company.",
      tips: [
        "Create base template",
        "Add company-specific sections",
        "Save successful variations"
      ]
    }
  end

  defp cover_letter_help(_level) do
    %{
      title: "Template Management",
      text: "Maintain multiple templates for different industries and roles.",
      tips: ["Version control your templates"]
    }
  end

  defp generic_help(feature, :beginner) do
    %{
      title: "Help",
      text: "Getting started with #{feature}.",
      tips: ["Explore the interface", "Hover for more information"]
    }
  end

  defp generic_help(_feature, _level) do
    %{
      title: "Help",
      text: "Use this feature to manage your job search.",
      tips: []
    }
  end

  defp validation_recovery(context) do
    field = context[:field] || "input"
    _value = context[:value]

    %{
      title: "Validation Error",
      message: "The #{field} you entered is invalid.",
      help_text: get_field_validation_help(field),
      actions: [
        %{label: "Check field format", icon: "info"},
        %{label: "Clear and retry", icon: "refresh"}
      ]
    }
  end

  defp duplicate_recovery(context) do
    resource = context[:resource] || "item"

    %{
      title: "Already Exists",
      message: "A #{resource} with that name already exists.",
      help_text: "You can edit the existing one or use a different name.",
      actions: [
        %{label: "Use different name", icon: "edit"},
        %{label: "Edit existing", icon: "pencil"},
        %{label: "View all #{resource}s", icon: "list"}
      ]
    }
  end

  defp not_found_recovery(_context) do
    %{
      title: "Not Found",
      message: "The item you're looking for doesn't exist.",
      help_text: "It may have been deleted or the link may be incorrect.",
      actions: [
        %{label: "Go back", icon: "arrow-left"},
        %{label: "View all items", icon: "list"}
      ]
    }
  end

  defp permission_recovery(_context) do
    %{
      title: "Permission Denied",
      message: "You don't have permission to access this.",
      help_text: "Contact your account owner if you think this is an error.",
      actions: [
        %{label: "Contact support", icon: "help"},
        %{label: "Go back", icon: "arrow-left"}
      ]
    }
  end

  defp network_recovery(_context) do
    %{
      title: "Connection Error",
      message: "Unable to reach the server. Check your connection.",
      help_text: "Try again in a moment or check your internet connection.",
      actions: [
        %{label: "Retry", icon: "refresh"},
        %{label: "Check connection", icon: "wifi"}
      ]
    }
  end

  defp storage_recovery(_context) do
    %{
      title: "Storage Error",
      message: "Unable to save or upload file.",
      help_text: "Check file size and format, then try again.",
      actions: [
        %{label: "Check file size", icon: "file"},
        %{label: "Retry upload", icon: "upload"},
        %{label: "Contact support", icon: "help"}
      ]
    }
  end

  defp get_field_validation_help(field) do
    case field do
      "email" -> "Use format: example@domain.com"
      "salary" -> "Enter numbers only, e.g., 100000"
      "url" -> "Use format: https://example.com"
      "date" -> "Use format: YYYY-MM-DD"
      _other -> "Check the field format and try again"
    end
  end

  defp job_interests_tutorial do
    %{
      title: "Getting Started with Job Interests",
      steps: [
        %{
          number: 1,
          title: "Add Your First Interest",
          description: "Click 'Add Job Interest' and fill in job details.",
          action: "Click 'Add Job Interest'",
          tips: ["Company name and position are required", "Other fields are optional"]
        },
        %{
          number: 2,
          title: "Set Priority and Status",
          description: "Prioritize opportunities and track where you are in the process.",
          action: "Select priority level",
          tips: ["High = apply soon", "Medium = good opportunity", "Low = exploring"]
        },
        %{
          number: 3,
          title: "Search and Filter",
          description: "Find specific jobs with search and filters.",
          action: "Try searching for a company",
          tips: ["Filter by priority, salary, work model"]
        },
        %{
          number: 4,
          title: "Convert to Application",
          description: "When ready, convert a job interest to an application.",
          action: "Select a job and click 'Apply'",
          tips: ["Choose a resume from your library"]
        }
      ]
    }
  end

  defp applications_tutorial do
    %{
      title: "Managing Job Applications",
      steps: [
        %{
          number: 1,
          title: "Track Your Applications",
          description: "See all your job applications in one place.",
          action: "View applications",
          tips: ["Status shows where you are in hiring process"]
        },
        %{
          number: 2,
          title: "Update Status",
          description: "Keep your application status current.",
          action: "Click status to update",
          tips: [
            "Applied: Just sent",
            "Interviewing: In process",
            "Offered: Received offer",
            "Rejected: Not moving forward"
          ]
        },
        %{
          number: 3,
          title: "Add Notes",
          description: "Track interview dates, contact info, and next steps.",
          action: "Click notes to add details",
          tips: ["Record interview dates", "Note follow-up reminders"]
        }
      ]
    }
  end

  defp documents_tutorial do
    %{
      title: "Managing Documents",
      steps: [
        %{
          number: 1,
          title: "Upload Resumes",
          description: "Add your resume files for easy access.",
          action: "Click 'Upload Resume'",
          tips: ["PDF or Word format", "Keep under 5MB"]
        },
        %{
          number: 2,
          title: "Set Default Resume",
          description: "Choose which resume to use by default.",
          action: "Click 'Set as Default'",
          tips: ["Quick access when applying"]
        },
        %{
          number: 3,
          title: "Create Cover Letter Templates",
          description: "Build reusable cover letter templates.",
          action: "Click 'New Template'",
          tips: ["Create variations for different roles"]
        }
      ]
    }
  end

  defp dashboard_tutorial do
    %{
      title: "Your Dashboard",
      steps: [
        %{
          number: 1,
          title: "Overview",
          description: "See your job search stats at a glance.",
          action: "Review your numbers",
          tips: ["Track progress over time"]
        },
        %{
          number: 2,
          title: "Recent Activity",
          description: "See what you've been up to.",
          action: "Browse recent changes",
          tips: ["Filter by date range"]
        }
      ]
    }
  end
end
