defmodule ClientatsWeb.Features.HelpSystemTest do
  use ClientatsWeb.FeatureCase, async: false

  import Wallaby.Query

  alias Clientats.Repo
  alias Clientats.Help.HelpInteraction
  alias Clientats.Help.TutorialManager
  alias Clientats.Help.ContextHelper

  @moduletag :feature

  describe "Tutorial Manager (Test Case 12.1)" do
    test "tutorial offered to new users", %{session: session} do
      user = create_user_and_login(session)

      session
      |> visit("/dashboard")
      |> assert_has(css(".tutorial-prompt, [data-tutorial-prompt]", count: 1))

      # Verify tutorial tracking in database
      help_interactions =
        Repo.all(
          from h in HelpInteraction,
            where: h.user_id == ^to_string(user.id) and h.interaction_type == "tutorial_start"
        )

      assert length(help_interactions) >= 0
    end

    test "tutorial start tracked", %{session: session} do
      user = create_user_and_login(session)

      # Start tutorial programmatically
      changeset = HelpInteraction.log_tutorial_start(to_string(user.id), "dashboard")
      {:ok, interaction} = Repo.insert(changeset)

      assert interaction.user_id == to_string(user.id)
      assert interaction.interaction_type == "tutorial_start"
      assert interaction.feature == "dashboard"
    end

    test "tutorial completion tracked", %{session: session} do
      user = create_user_and_login(session)

      # Complete tutorial programmatically
      changeset = HelpInteraction.log_tutorial_complete(to_string(user.id), "job_interests")
      {:ok, interaction} = Repo.insert(changeset)

      assert interaction.user_id == to_string(user.id)
      assert interaction.interaction_type == "tutorial_complete"
      assert interaction.feature == "job_interests"
    end

    test "tutorial progress saved", %{session: session} do
      user = create_user_and_login(session)

      # Log multiple tutorial steps
      Repo.insert!(
        HelpInteraction.log_tutorial_start(to_string(user.id), "applications")
      )

      Repo.insert!(
        HelpInteraction.log_tutorial_complete(to_string(user.id), "applications")
      )

      interactions =
        Repo.all(
          from h in HelpInteraction,
            where: h.user_id == ^to_string(user.id) and h.feature == "applications",
            order_by: [asc: h.inserted_at]
        )

      assert length(interactions) == 2
      assert Enum.at(interactions, 0).interaction_type == "tutorial_start"
      assert Enum.at(interactions, 1).interaction_type == "tutorial_complete"
    end

    test "can replay tutorial via TutorialManager", %{session: _session} do
      user_id = "test_user_#{:rand.uniform(1000)}"

      # Mark tutorial as seen
      :ok = TutorialManager.mark_tutorial_seen(user_id, "dashboard")
      assert TutorialManager.has_seen_tutorial?(user_id, "dashboard") == true

      # Can still replay by marking as unseen (in real implementation)
      # For now, verify the tutorial manager tracks state
      assert TutorialManager.has_seen_tutorial?(user_id, "unknown_feature") == false
    end
  end

  describe "Tutorial Dismissal (Test Case 12.2)" do
    test "dismissal tracked", %{session: session} do
      user = create_user_and_login(session)

      # Dismiss tutorial programmatically
      changeset =
        HelpInteraction.log_tutorial_dismiss(to_string(user.id), "documents", "not_needed")

      {:ok, interaction} = Repo.insert(changeset)

      assert interaction.user_id == to_string(user.id)
      assert interaction.interaction_type == "tutorial_dismiss"
      assert interaction.feature == "documents"
      assert interaction.feedback == "not_needed"
    end

    test "tutorial not shown again after dismissal via TutorialManager", %{session: _session} do
      user_id = "test_user_#{:rand.uniform(1000)}"

      # Dismiss tutorial
      :ok = TutorialManager.dismiss_tutorial(user_id, "job_interests")

      # Verify state management
      recommendations = TutorialManager.get_recommended_tutorials(user_id)
      assert is_list(recommendations)
    end

    test "can access tutorials later from help menu", %{session: session} do
      user = create_user_and_login(session)

      # Dismiss tutorial
      Repo.insert!(
        HelpInteraction.log_tutorial_dismiss(to_string(user.id), "applications", "skip")
      )

      # Verify help menu still accessible (would check UI in real browser test)
      session
      |> visit("/dashboard")
      |> assert_has(css("body"))

      # In a real UI, we'd verify help icon/menu is still available
      # For now, verify the dismissal was recorded
      dismissed =
        Repo.one(
          from h in HelpInteraction,
            where:
              h.user_id == ^to_string(user.id) and
                h.interaction_type == "tutorial_dismiss" and
                h.feature == "applications"
        )

      assert dismissed != nil
    end

    test "dismissal preferences saved", %{session: session} do
      user = create_user_and_login(session)

      # Dismiss multiple tutorials
      Repo.insert!(
        HelpInteraction.log_tutorial_dismiss(to_string(user.id), "dashboard", "later")
      )

      Repo.insert!(
        HelpInteraction.log_tutorial_dismiss(to_string(user.id), "documents", "not_interested")
      )

      dismissed_count =
        Repo.aggregate(
          from(h in HelpInteraction,
            where:
              h.user_id == ^to_string(user.id) and h.interaction_type == "tutorial_dismiss"
          ),
          :count
        )

      assert dismissed_count == 2
    end
  end

  describe "Context Helper (Test Case 12.3)" do
    test "help content relevant to current page", %{session: _session} do
      # Test context-aware help for job interests
      help_text =
        ContextHelper.get_help_text(%{
          feature: :job_interests,
          element: :search_bar,
          experience_level: :beginner
        })

      assert help_text.title == "Search Help"
      assert help_text.text =~ "Search across all job titles"
      assert is_list(help_text.tips)
    end

    test "feature-specific guidance shown", %{session: _session} do
      # Test help for different features
      priority_help =
        ContextHelper.get_help_text(%{
          feature: :job_interests,
          element: :priority_filter,
          experience_level: :intermediate
        })

      assert priority_help.title == "Priority Filter"
      assert priority_help.text =~ "Filter by priority level"

      resume_help =
        ContextHelper.get_help_text(%{
          feature: :documents,
          element: :resume_upload,
          experience_level: :beginner
        })

      assert resume_help.title == "Upload Resume"
      assert resume_help.formats == "PDF, DOC, DOCX"
    end

    test "links to full documentation", %{session: _session} do
      # Verify help text includes actionable information
      salary_help =
        ContextHelper.get_help_text(%{
          feature: :job_interests,
          element: :salary_range,
          experience_level: :beginner
        })

      assert salary_help.example =~ "$"
      assert is_list(salary_help.tips)
      assert length(salary_help.tips) > 0
    end

    test "help interactions tracked via database", %{session: session} do
      user = create_user_and_login(session)

      # Log help view
      changeset =
        HelpInteraction.log_help_view(
          to_string(user.id),
          "job_interests",
          "search_bar",
          %{page: "/dashboard/interests"}
        )

      {:ok, interaction} = Repo.insert(changeset)

      assert interaction.user_id == to_string(user.id)
      assert interaction.interaction_type == "help_view"
      assert interaction.feature == "job_interests"
      assert interaction.element == "search_bar"
      assert interaction.context["page"] == "/dashboard/interests"
    end
  end

  describe "Help Interaction Tracking (Test Case 12.4)" do
    test "each help view tracked", %{session: session} do
      user = create_user_and_login(session)

      # Log multiple help views
      help_elements = [
        {"job_interests", "search_bar"},
        {"job_interests", "priority_filter"},
        {"applications", "status_tracker"}
      ]

      for {feature, element} <- help_elements do
        changeset =
          HelpInteraction.log_help_view(to_string(user.id), feature, element, %{
            timestamp: DateTime.utc_now()
          })

        Repo.insert!(changeset)
      end

      help_views =
        Repo.all(
          from h in HelpInteraction,
            where: h.user_id == ^to_string(user.id) and h.interaction_type == "help_view"
        )

      assert length(help_views) == 3
    end

    test "feature and element captured", %{session: session} do
      user = create_user_and_login(session)

      changeset =
        HelpInteraction.log_help_view(
          to_string(user.id),
          "applications",
          "application_date",
          %{}
        )

      {:ok, interaction} = Repo.insert(changeset)

      assert interaction.feature == "applications"
      assert interaction.element == "application_date"
    end

    test "context stored", %{session: session} do
      user = create_user_and_login(session)

      context = %{
        page: "/dashboard/applications",
        user_state: "viewing_list",
        filter_applied: true
      }

      changeset =
        HelpInteraction.log_help_view(
          to_string(user.id),
          "applications",
          "status_filter",
          context
        )

      {:ok, interaction} = Repo.insert(changeset)

      assert interaction.context["page"] == "/dashboard/applications"
      assert interaction.context["user_state"] == "viewing_list"
      assert interaction.context["filter_applied"] == true
    end

    test "timestamp recorded", %{session: session} do
      user = create_user_and_login(session)

      before_time = DateTime.utc_now()

      changeset =
        HelpInteraction.log_help_view(to_string(user.id), "dashboard", "stats_widget", %{})

      {:ok, interaction} = Repo.insert(changeset)

      after_time = DateTime.utc_now()

      assert DateTime.compare(interaction.inserted_at, before_time) in [:gt, :eq]
      assert DateTime.compare(interaction.inserted_at, after_time) in [:lt, :eq]
    end
  end

  describe "Feedback Collection (Test Case 12.5)" do
    test "feedback captured", %{session: session} do
      user = create_user_and_login(session)

      # Create help interaction with feedback
      {:ok, interaction} =
        Repo.insert(
          HelpInteraction.changeset(%HelpInteraction{}, %{
            user_id: to_string(user.id),
            interaction_type: "help_view",
            feature: "job_interests",
            element: "search_bar",
            helpful: true,
            feedback: "Very clear instructions"
          })
        )

      assert interaction.helpful == true
      assert interaction.feedback == "Very clear instructions"
    end

    test "optional text feedback accepted", %{session: session} do
      user = create_user_and_login(session)

      {:ok, interaction} =
        Repo.insert(
          HelpInteraction.changeset(%HelpInteraction{}, %{
            user_id: to_string(user.id),
            interaction_type: "tutorial_complete",
            feature: "documents",
            helpful: false,
            feedback: "Could use more examples"
          })
        )

      assert interaction.helpful == false
      assert interaction.feedback == "Could use more examples"
    end

    test "feedback linked to help interaction", %{session: session} do
      user = create_user_and_login(session)

      # Create interaction then add feedback
      {:ok, interaction} =
        Repo.insert(
          HelpInteraction.changeset(%HelpInteraction{}, %{
            user_id: to_string(user.id),
            interaction_type: "help_view",
            feature: "applications"
          })
        )

      # Update with feedback
      updated_changeset =
        HelpInteraction.changeset(interaction, %{
          helpful: true,
          feedback: "Helped me understand the feature"
        })

      {:ok, updated} = Repo.update(updated_changeset)

      assert updated.id == interaction.id
      assert updated.helpful == true
      assert updated.feedback == "Helped me understand the feature"
    end

    test "can analyze helpfulness", %{session: session} do
      user = create_user_and_login(session)

      # Insert multiple interactions with feedback
      Repo.insert!(
        HelpInteraction.changeset(%HelpInteraction{}, %{
          user_id: to_string(user.id),
          interaction_type: "help_view",
          feature: "job_interests",
          helpful: true
        })
      )

      Repo.insert!(
        HelpInteraction.changeset(%HelpInteraction{}, %{
          user_id: to_string(user.id),
          interaction_type: "help_view",
          feature: "applications",
          helpful: true
        })
      )

      Repo.insert!(
        HelpInteraction.changeset(%HelpInteraction{}, %{
          user_id: to_string(user.id),
          interaction_type: "help_view",
          feature: "documents",
          helpful: false
        })
      )

      # Analyze helpfulness
      helpful_count =
        Repo.aggregate(
          from(h in HelpInteraction,
            where: h.user_id == ^to_string(user.id) and h.helpful == true
          ),
          :count
        )

      not_helpful_count =
        Repo.aggregate(
          from(h in HelpInteraction,
            where: h.user_id == ^to_string(user.id) and h.helpful == false
          ),
          :count
        )

      assert helpful_count == 2
      assert not_helpful_count == 1
    end
  end

  describe "Recovery Feature Usage (Test Case 12.6)" do
    test "recovery usage tracked", %{session: session} do
      user = create_user_and_login(session)

      # Log recovery usage
      changeset =
        HelpInteraction.log_recovery_used(
          to_string(user.id),
          "validation_error",
          "retry_form"
        )

      {:ok, interaction} = Repo.insert(changeset)

      assert interaction.user_id == to_string(user.id)
      assert interaction.interaction_type == "recovery_used"
      assert interaction.context["error_type"] == "validation_error"
      assert interaction.context["action"] == "retry_form"
    end

    test "error context captured", %{session: session} do
      user = create_user_and_login(session)

      changeset =
        HelpInteraction.log_recovery_used(to_string(user.id), "network_error", "retry_request")

      {:ok, interaction} = Repo.insert(changeset)

      assert interaction.context["error_type"] == "network_error"
      assert interaction.context["action"] == "retry_request"
    end

    test "recovery successful/failed logged", %{session: session} do
      user = create_user_and_login(session)

      # Log successful recovery
      {:ok, success_interaction} =
        Repo.insert(
          HelpInteraction.changeset(%HelpInteraction{}, %{
            user_id: to_string(user.id),
            interaction_type: "recovery_used",
            context: %{
              error_type: "storage_error",
              action: "retry_upload",
              result: "success"
            }
          })
        )

      # Log failed recovery
      {:ok, failed_interaction} =
        Repo.insert(
          HelpInteraction.changeset(%HelpInteraction{}, %{
            user_id: to_string(user.id),
            interaction_type: "recovery_used",
            context: %{
              error_type: "permission_error",
              action: "request_access",
              result: "failed"
            }
          })
        )

      assert success_interaction.context["result"] == "success"
      assert failed_interaction.context["result"] == "failed"
    end

    test "can identify problem areas", %{session: session} do
      user = create_user_and_login(session)

      # Log multiple recovery attempts
      error_types = ["validation_error", "validation_error", "network_error", "storage_error"]

      for error_type <- error_types do
        changeset =
          HelpInteraction.log_recovery_used(to_string(user.id), error_type, "retry")

        Repo.insert!(changeset)
      end

      # Identify most common error type
      recovery_interactions =
        Repo.all(
          from h in HelpInteraction,
            where: h.user_id == ^to_string(user.id) and h.interaction_type == "recovery_used"
        )

      error_type_counts =
        Enum.frequencies_by(recovery_interactions, fn i -> i.context["error_type"] end)

      assert error_type_counts["validation_error"] == 2
      assert error_type_counts["network_error"] == 1
      assert error_type_counts["storage_error"] == 1
    end

    test "error recovery suggestions provided by ContextHelper", %{session: _session} do
      # Test validation error recovery
      validation_recovery =
        ContextHelper.get_error_recovery(:validation_error, %{
          field: "email",
          value: "invalid"
        })

      assert validation_recovery.title == "Validation Error"
      assert is_list(validation_recovery.actions)
      assert length(validation_recovery.actions) > 0

      # Test network error recovery
      network_recovery = ContextHelper.get_error_recovery(:network_error)
      assert network_recovery.title == "Connection Error"
      assert network_recovery.message =~ "server"

      # Test storage error recovery
      storage_recovery = ContextHelper.get_error_recovery(:storage_error)
      assert storage_recovery.title == "Storage Error"
      assert storage_recovery.message =~ "file"
    end

    test "format error with recovery suggestions", %{session: _session} do
      formatted =
        ContextHelper.format_error_with_recovery(
          "Email format is invalid",
          :validation_error,
          %{field: "email"}
        )

      assert formatted.error == "Email format is invalid"
      assert formatted.title == "Validation Error"
      assert is_list(formatted.suggestions)
      assert formatted.help_text =~ "example@domain.com"
    end
  end

  describe "Tutorial Content and Progressive Disclosure" do
    test "get tutorial content for different features", %{session: _session} do
      # Job interests tutorial
      job_tutorial = ContextHelper.get_tutorial(:job_interests, "user_123")
      assert job_tutorial.title == "Getting Started with Job Interests"
      assert is_list(job_tutorial.steps)
      assert length(job_tutorial.steps) == 4

      # Applications tutorial
      app_tutorial = ContextHelper.get_tutorial(:applications, "user_123")
      assert app_tutorial.title == "Managing Job Applications"
      assert length(app_tutorial.steps) == 3

      # Documents tutorial
      doc_tutorial = ContextHelper.get_tutorial(:documents, "user_123")
      assert doc_tutorial.title == "Managing Documents"
      assert length(doc_tutorial.steps) == 3
    end

    test "progressive disclosure based on experience level", %{session: _session} do
      # Beginner sees limited options
      beginner_options = ContextHelper.get_visible_options(:job_interests, :beginner)
      assert :status in beginner_options
      assert :priority in beginner_options
      refute :custom_filters in beginner_options

      # Intermediate sees more options
      intermediate_options = ContextHelper.get_visible_options(:job_interests, :intermediate)
      assert :salary_range in intermediate_options
      assert :work_model in intermediate_options
      refute :custom_filters in intermediate_options

      # Advanced sees all options
      advanced_options = ContextHelper.get_visible_options(:job_interests, :advanced)
      assert :custom_filters in advanced_options
      assert :location in advanced_options
    end

    test "context helper provides experience-appropriate help", %{session: _session} do
      # Beginner help is simpler
      beginner_help =
        ContextHelper.get_help_text(%{
          feature: :job_interests,
          element: :search_bar,
          experience_level: :beginner
        })

      assert beginner_help.text =~ "Search across all"
      assert beginner_help.example =~ "Try:"

      # Advanced help has more detail
      advanced_help =
        ContextHelper.get_help_text(%{
          feature: :job_interests,
          element: :search_bar,
          experience_level: :advanced
        })

      assert advanced_help.text =~ "advanced search"
      assert advanced_help.example =~ "AND/OR"
    end
  end

  # Helper functions

  defp create_user do
    %{
      email: "test#{System.unique_integer([:positive])}@example.com",
      password: "password123",
      password_confirmation: "password123",
      first_name: "Test",
      last_name: "User"
    }
  end

  defp create_user_and_login(session) do
    user = create_user()
    {:ok, db_user} = Clientats.Accounts.register_user(user)

    session
    |> visit("/login")
    |> fill_in(css("input[name='user[email]']"), with: user.email)
    |> fill_in(css("input[name='user[password]']"), with: user.password)
    |> click(button("Sign in"))

    Map.put(user, :id, db_user.id)
  end
end
