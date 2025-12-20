defmodule Clientats.DataExport do
  @moduledoc """
  Context module for exporting and importing user data.
  """

  import Ecto.Query
  alias Clientats.Repo
  alias Clientats.Accounts.User
  alias Clientats.Jobs.{JobInterest, JobApplication, ApplicationEvent}
  alias Clientats.Documents.{Resume, CoverLetterTemplate}

  @doc """
  Exports all data for a given user as a map ready for JSON encoding.
  """
  def export_user_data(user_id) do
    %{
      version: "1.0",
      exported_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      user: export_user(user_id),
      job_interests: export_job_interests(user_id),
      job_applications: export_job_applications(user_id),
      resumes: export_resumes(user_id),
      cover_letter_templates: export_cover_letter_templates(user_id)
    }
  end

  @doc """
  Imports user data from a parsed JSON map.
  Returns {:ok, stats} on success or {:error, reason} on failure.
  """
  def import_user_data(user_id, data) do
    validate_import_data(data)
    |> case do
      :ok -> perform_import(user_id, data)
      error -> error
    end
  end

  # Private functions for export

  defp export_user(user_id) do
    user = Repo.get!(User, user_id)

    %{
      email: user.email,
      first_name: user.first_name,
      last_name: user.last_name
    }
  end

  defp export_job_interests(user_id) do
    JobInterest
    |> where(user_id: ^user_id)
    |> order_by([j], desc: j.inserted_at)
    |> Repo.all()
    |> Enum.map(&serialize_job_interest/1)
  end

  defp export_job_applications(user_id) do
    JobApplication
    |> where(user_id: ^user_id)
    |> preload(:application_events)
    |> order_by([j], desc: j.application_date)
    |> Repo.all()
    |> Enum.map(&serialize_job_application/1)
  end

  defp export_resumes(user_id) do
    Resume
    |> where(user_id: ^user_id)
    |> order_by([r], desc: r.inserted_at)
    |> Repo.all()
    |> Enum.map(&serialize_resume/1)
  end

  defp export_cover_letter_templates(user_id) do
    CoverLetterTemplate
    |> where(user_id: ^user_id)
    |> order_by([c], desc: c.inserted_at)
    |> Repo.all()
    |> Enum.map(&serialize_cover_letter_template/1)
  end

  # Serialization helpers

  defp serialize_job_interest(job_interest) do
    %{
      company_name: job_interest.company_name,
      position_title: job_interest.position_title,
      job_description: job_interest.job_description,
      job_url: job_interest.job_url,
      location: job_interest.location,
      work_model: job_interest.work_model,
      salary_min: job_interest.salary_min,
      salary_max: job_interest.salary_max,
      status: job_interest.status,
      priority: job_interest.priority,
      notes: job_interest.notes,
      inserted_at: DateTime.to_iso8601(job_interest.inserted_at),
      updated_at: DateTime.to_iso8601(job_interest.updated_at)
    }
  end

  defp serialize_job_application(job_application) do
    %{
      company_name: job_application.company_name,
      position_title: job_application.position_title,
      job_description: job_application.job_description,
      job_url: job_application.job_url,
      location: job_application.location,
      work_model: job_application.work_model,
      salary_min: job_application.salary_min,
      salary_max: job_application.salary_max,
      application_date: date_to_string(job_application.application_date),
      status: job_application.status,
      cover_letter_path: job_application.cover_letter_path,
      resume_path: job_application.resume_path,
      notes: job_application.notes,
      application_events:
        Enum.map(job_application.application_events, &serialize_application_event/1),
      inserted_at: DateTime.to_iso8601(job_application.inserted_at),
      updated_at: DateTime.to_iso8601(job_application.updated_at)
    }
  end

  defp serialize_application_event(event) do
    %{
      event_type: event.event_type,
      event_date: date_to_string(event.event_date),
      contact_person: event.contact_person,
      contact_email: event.contact_email,
      contact_phone: event.contact_phone,
      notes: event.notes,
      follow_up_date: date_to_string(event.follow_up_date),
      inserted_at: DateTime.to_iso8601(event.inserted_at),
      updated_at: DateTime.to_iso8601(event.updated_at)
    }
  end

  defp serialize_resume(resume) do
    %{
      name: resume.name,
      description: resume.description,
      file_path: resume.file_path,
      original_filename: resume.original_filename,
      file_size: resume.file_size,
      is_default: resume.is_default,
      inserted_at: DateTime.to_iso8601(resume.inserted_at),
      updated_at: DateTime.to_iso8601(resume.updated_at)
    }
  end

  defp serialize_cover_letter_template(template) do
    %{
      name: template.name,
      description: template.description,
      content: template.content,
      is_default: template.is_default,
      inserted_at: DateTime.to_iso8601(template.inserted_at),
      updated_at: DateTime.to_iso8601(template.updated_at)
    }
  end

  defp date_to_string(nil), do: nil
  defp date_to_string(date), do: Date.to_iso8601(date)

  # Private functions for import

  defp validate_import_data(data) do
    cond do
      not is_map(data) ->
        {:error, "Invalid data format: expected a map"}

      not Map.has_key?(data, "version") ->
        {:error, "Invalid data format: missing version field"}

      data["version"] != "1.0" ->
        {:error, "Unsupported data version: #{data["version"]}"}

      true ->
        :ok
    end
  end

  defp perform_import(user_id, data) do
    Repo.transaction(fn ->
      stats = %{
        job_interests: 0,
        job_applications: 0,
        application_events: 0,
        resumes: 0,
        cover_letter_templates: 0
      }

      stats = import_job_interests(user_id, data["job_interests"] || [], stats)
      stats = import_job_applications(user_id, data["job_applications"] || [], stats)
      stats = import_resumes(user_id, data["resumes"] || [], stats)
      stats = import_cover_letter_templates(user_id, data["cover_letter_templates"] || [], stats)

      stats
    end)
  end

  defp import_job_interests(user_id, interests, stats) do
    count =
      Enum.reduce(interests, 0, fn interest, acc ->
        case create_job_interest(user_id, interest) do
          {:ok, _} -> acc + 1
          {:error, _} -> acc
        end
      end)

    Map.put(stats, :job_interests, count)
  end

  defp import_job_applications(user_id, applications, stats) do
    {app_count, event_count} =
      Enum.reduce(applications, {0, 0}, fn application, {a_acc, e_acc} ->
        case create_job_application(user_id, application) do
          {:ok, job_app} ->
            events = application["application_events"] || []

            event_created =
              Enum.count(events, fn event ->
                case create_application_event(job_app.id, event) do
                  {:ok, _} -> true
                  {:error, _} -> false
                end
              end)

            {a_acc + 1, e_acc + event_created}

          {:error, _} ->
            {a_acc, e_acc}
        end
      end)

    stats
    |> Map.put(:job_applications, app_count)
    |> Map.put(:application_events, event_count)
  end

  defp import_resumes(user_id, resumes, stats) do
    count =
      Enum.reduce(resumes, 0, fn resume, acc ->
        case create_resume(user_id, resume) do
          {:ok, _} -> acc + 1
          {:error, _} -> acc
        end
      end)

    Map.put(stats, :resumes, count)
  end

  defp import_cover_letter_templates(user_id, templates, stats) do
    count =
      Enum.reduce(templates, 0, fn template, acc ->
        case create_cover_letter_template(user_id, template) do
          {:ok, _} -> acc + 1
          {:error, _} -> acc
        end
      end)

    Map.put(stats, :cover_letter_templates, count)
  end

  # Record creation helpers

  defp create_job_interest(user_id, attrs) do
    %JobInterest{}
    |> JobInterest.changeset(Map.put(attrs, "user_id", user_id))
    |> Repo.insert()
  end

  defp create_job_application(user_id, attrs) do
    %JobApplication{}
    |> JobApplication.changeset(Map.put(attrs, "user_id", user_id))
    |> Repo.insert()
  end

  defp create_application_event(job_application_id, attrs) do
    %ApplicationEvent{}
    |> ApplicationEvent.changeset(Map.put(attrs, "job_application_id", job_application_id))
    |> Repo.insert()
  end

  defp create_resume(user_id, attrs) do
    %Resume{}
    |> Resume.changeset(Map.put(attrs, "user_id", user_id))
    |> Repo.insert()
  end

  defp create_cover_letter_template(user_id, attrs) do
    %CoverLetterTemplate{}
    |> CoverLetterTemplate.changeset(Map.put(attrs, "user_id", user_id))
    |> Repo.insert()
  end
end
