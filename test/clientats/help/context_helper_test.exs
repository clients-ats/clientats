defmodule Clientats.Help.ContextHelperTest do
  use ExUnit.Case

  alias Clientats.Help.ContextHelper

  describe "get_help_text/1" do
    test "returns search bar help for beginners" do
      help =
        ContextHelper.get_help_text(%{
          feature: :job_interests,
          element: :search_bar,
          experience_level: :beginner
        })

      assert help.title == "Search Help"
      assert is_list(help.tips)
    end

    test "returns advanced search help for advanced users" do
      help =
        ContextHelper.get_help_text(%{
          feature: :job_interests,
          element: :search_bar,
          experience_level: :advanced
        })

      assert help.title == "Search Operators"
      assert is_list(help.tips)
    end

    test "returns priority filter help" do
      help =
        ContextHelper.get_help_text(%{
          feature: :job_interests,
          element: :priority_filter
        })

      assert help.title == "Priority Levels"
      assert is_list(help.tips)
    end

    test "returns salary range help" do
      help =
        ContextHelper.get_help_text(%{
          feature: :job_interests,
          element: :salary_range
        })

      assert help.title == "Salary Range"
      assert is_list(help.tips)
    end

    test "returns application date help" do
      help =
        ContextHelper.get_help_text(%{
          feature: :applications,
          element: :application_date
        })

      assert help.title == "Application Timeline"
      assert is_list(help.tips)
    end

    test "returns resume upload help" do
      help =
        ContextHelper.get_help_text(%{
          feature: :documents,
          element: :resume_upload
        })

      assert help.title == "Upload Resume"
      assert is_list(help.tips)
    end

    test "returns generic help for unknown elements" do
      help =
        ContextHelper.get_help_text(%{
          feature: :unknown_feature
        })

      assert is_map(help)
    end
  end

  describe "get_error_recovery/2" do
    test "returns validation error recovery" do
      recovery = ContextHelper.get_error_recovery(:validation_error, %{field: "email"})

      assert recovery.title == "Validation Error"
      assert String.contains?(recovery.message, ["invalid", "Invalid"])
      assert is_list(recovery.actions)
    end

    test "returns duplicate error recovery" do
      recovery = ContextHelper.get_error_recovery(:duplicate_error, %{resource: "job interest"})

      assert recovery.title == "Already Exists"
      assert is_list(recovery.actions)
    end

    test "returns not found error recovery" do
      recovery = ContextHelper.get_error_recovery(:not_found_error)

      assert recovery.title == "Not Found"
      assert is_list(recovery.actions)
    end

    test "returns permission error recovery" do
      recovery = ContextHelper.get_error_recovery(:permission_error)

      assert recovery.title == "Permission Denied"
      assert is_list(recovery.actions)
    end

    test "returns network error recovery" do
      recovery = ContextHelper.get_error_recovery(:network_error)

      assert recovery.title == "Connection Error"
      assert recovery.actions |> Enum.map(& &1.label) |> Enum.any?(&String.contains?(&1, "Retry"))
    end

    test "returns storage error recovery" do
      recovery = ContextHelper.get_error_recovery(:storage_error)

      assert recovery.title == "Storage Error"
      assert is_list(recovery.actions)
    end
  end

  describe "get_visible_options/2" do
    test "returns basic options for beginners" do
      options = ContextHelper.get_visible_options(:job_interests, :beginner)

      assert :status in options
      assert :priority in options
      refute :custom_filters in options
    end

    test "returns intermediate options for intermediate users" do
      options = ContextHelper.get_visible_options(:job_interests, :intermediate)

      assert :status in options
      assert :salary_range in options
      assert :work_model in options
    end

    test "returns all options for advanced users" do
      options = ContextHelper.get_visible_options(:job_interests, :advanced)

      assert :status in options
      assert :custom_filters in options
    end

    test "returns minimal options for application filters" do
      options = ContextHelper.get_visible_options(:applications, :beginner)

      assert options == [:status]
    end
  end

  describe "get_tutorial/2" do
    test "returns job interests tutorial" do
      tutorial = ContextHelper.get_tutorial(:job_interests, "user_123")

      assert tutorial.title == "Getting Started with Job Interests"
      assert is_list(tutorial.steps)
      assert length(tutorial.steps) > 0
    end

    test "returns applications tutorial" do
      tutorial = ContextHelper.get_tutorial(:applications, "user_123")

      assert tutorial.title == "Managing Job Applications"
      assert is_list(tutorial.steps)
    end

    test "returns documents tutorial" do
      tutorial = ContextHelper.get_tutorial(:documents, "user_123")

      assert tutorial.title == "Managing Documents"
      assert is_list(tutorial.steps)
    end

    test "returns nil for unknown feature" do
      tutorial = ContextHelper.get_tutorial(:unknown, "user_123")

      assert is_nil(tutorial)
    end

    test "tutorial steps have required fields" do
      tutorial = ContextHelper.get_tutorial(:job_interests, "user_123")

      Enum.each(tutorial.steps, fn step ->
        assert Map.has_key?(step, :number)
        assert Map.has_key?(step, :title)
        assert Map.has_key?(step, :description)
        assert Map.has_key?(step, :tips)
      end)
    end
  end

  describe "format_error_with_recovery/3" do
    test "formats error with recovery suggestions" do
      result =
        ContextHelper.format_error_with_recovery(
          "Invalid email format",
          :validation_error,
          %{field: "email"}
        )

      assert result.error == "Invalid email format"
      assert result.title == "Validation Error"
      assert is_list(result.suggestions)
      assert result.help_text
    end

    test "includes help text for recovery" do
      result =
        ContextHelper.format_error_with_recovery(
          "Connection failed",
          :network_error
        )

      assert result.suggestions
             |> Enum.map(& &1.label)
             |> Enum.any?(&String.contains?(&1, "Retry"))
    end
  end

  describe "should_show_tutorial?/2" do
    test "returns true for new users" do
      # Simplified - in real implementation would check user creation time
      assert ContextHelper.should_show_tutorial?(:job_interests, "new_user_123")
    end
  end
end
