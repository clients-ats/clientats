defmodule Clientats.Jobs.Search do
  @moduledoc """
  Advanced search and filtering for job interests and applications.

  Provides:
  - Full-text search across multiple fields
  - Complex filtering with multiple criteria
  - Sorting by various columns
  - Pagination support
  - Performance-optimized queries
  """

  import Ecto.Query

  alias Clientats.Repo
  alias Clientats.Jobs.{JobInterest, JobApplication}

  @doc """
  Search and filter job interests with advanced options.

  Options:
    - :search - Full-text search term
    - :status - Filter by status (interested, applied, rejected, accepted)
    - :priority - Filter by priority (low, medium, high)
    - :min_salary - Minimum salary
    - :max_salary - Maximum salary
    - :work_model - Work model (remote, hybrid, on-site)
    - :location - Search in location
    - :sort_by - Sort column (company, position, priority, created_at)
    - :sort_order - asc or desc
    - :limit - Results per page (default: 50)
    - :offset - Pagination offset (default: 0)
  """
  def search_job_interests(user_id, opts \\ []) do
    search_term = opts[:search]
    status = opts[:status]
    priority = opts[:priority]
    min_salary = opts[:min_salary]
    max_salary = opts[:max_salary]
    work_model = opts[:work_model]
    location = opts[:location]
    sort_by = opts[:sort_by] || :created_at
    sort_order = opts[:sort_order] || :desc
    limit = opts[:limit] || 50
    offset = opts[:offset] || 0

    JobInterest
    |> where([j], j.user_id == ^user_id)
    |> maybe_search(search_term)
    |> maybe_filter_status(status)
    |> maybe_filter_priority(priority)
    |> maybe_filter_salary_min(min_salary)
    |> maybe_filter_salary_max(max_salary)
    |> maybe_filter_work_model(work_model)
    |> maybe_filter_location(location)
    |> order_by_column(sort_by, sort_order)
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
  end

  @doc """
  Count job interests matching search criteria.
  """
  def count_job_interests(user_id, opts \\ []) do
    search_term = opts[:search]
    status = opts[:status]
    priority = opts[:priority]
    min_salary = opts[:min_salary]
    max_salary = opts[:max_salary]
    work_model = opts[:work_model]
    location = opts[:location]

    JobInterest
    |> where([j], j.user_id == ^user_id)
    |> maybe_search(search_term)
    |> maybe_filter_status(status)
    |> maybe_filter_priority(priority)
    |> maybe_filter_salary_min(min_salary)
    |> maybe_filter_salary_max(max_salary)
    |> maybe_filter_work_model(work_model)
    |> maybe_filter_location(location)
    |> Repo.aggregate(:count)
  end

  @doc """
  Search and filter job applications.

  Options:
    - :search - Full-text search term
    - :status - Filter by status (applied, interviewing, offered, rejected, withdrawn, accepted)
    - :from_date - Applications from date
    - :to_date - Applications to date
    - :sort_by - Sort column (company, position, applied_date, status)
    - :sort_order - asc or desc
    - :limit - Results per page (default: 50)
    - :offset - Pagination offset (default: 0)
  """
  def search_job_applications(user_id, opts \\ []) do
    search_term = opts[:search]
    status = opts[:status]
    from_date = opts[:from_date]
    to_date = opts[:to_date]
    sort_by = opts[:sort_by] || :application_date
    sort_order = opts[:sort_order] || :desc
    limit = opts[:limit] || 50
    offset = opts[:offset] || 0

    JobApplication
    |> where([a], a.user_id == ^user_id)
    |> maybe_search_application(search_term)
    |> maybe_filter_app_status(status)
    |> maybe_filter_date_range(from_date, to_date)
    |> order_by_app_column(sort_by, sort_order)
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
  end

  @doc """
  Count job applications matching search criteria.
  """
  def count_job_applications(user_id, opts \\ []) do
    search_term = opts[:search]
    status = opts[:status]
    from_date = opts[:from_date]
    to_date = opts[:to_date]

    JobApplication
    |> where([a], a.user_id == ^user_id)
    |> maybe_search_application(search_term)
    |> maybe_filter_app_status(status)
    |> maybe_filter_date_range(from_date, to_date)
    |> Repo.aggregate(:count)
  end

  @doc """
  Get aggregate statistics for job interests.
  """
  def get_interest_stats(user_id) do
    JobInterest
    |> where([j], j.user_id == ^user_id)
    |> select([j], %{
      total: count(j.id),
      avg_salary_min: avg(j.salary_min),
      avg_salary_max: avg(j.salary_max)
    })
    |> Repo.one()
  rescue
    _e -> %{total: 0}
  end

  @doc """
  Get aggregate statistics for job applications.
  """
  def get_application_stats(user_id) do
    JobApplication
    |> where([a], a.user_id == ^user_id)
    |> select([a], %{
      total: count(a.id),
      oldest_application: min(a.application_date),
      newest_application: max(a.application_date)
    })
    |> Repo.one()
  rescue
    _e -> %{total: 0}
  end

  # Private search and filter helpers

  defp maybe_search(query, nil), do: query
  defp maybe_search(query, ""), do: query
  defp maybe_search(query, search_term) do
    search_pattern = "%#{search_term}%"

    query
    |> where(
      [j],
      ilike(j.company_name, ^search_pattern) or
        ilike(j.position_title, ^search_pattern) or
        ilike(j.location, ^search_pattern) or
        ilike(j.job_description, ^search_pattern) or
        ilike(j.notes, ^search_pattern)
    )
  end

  defp maybe_search_application(query, nil), do: query
  defp maybe_search_application(query, ""), do: query
  defp maybe_search_application(query, search_term) do
    search_pattern = "%#{search_term}%"

    query
    |> where(
      [a],
      ilike(a.company_name, ^search_pattern) or
        ilike(a.position_title, ^search_pattern) or
        ilike(a.job_description, ^search_pattern) or
        ilike(a.notes, ^search_pattern)
    )
  end

  defp maybe_filter_status(query, nil), do: query
  defp maybe_filter_status(query, status) do
    where(query, [j], j.status == ^status)
  end

  defp maybe_filter_app_status(query, nil), do: query
  defp maybe_filter_app_status(query, status) do
    where(query, [a], a.status == ^status)
  end

  defp maybe_filter_priority(query, nil), do: query
  defp maybe_filter_priority(query, priority) do
    where(query, [j], j.priority == ^priority)
  end

  defp maybe_filter_salary_min(query, nil), do: query
  defp maybe_filter_salary_min(query, min_salary) do
    where(query, [j], j.salary_min >= ^min_salary)
  end

  defp maybe_filter_salary_max(query, nil), do: query
  defp maybe_filter_salary_max(query, max_salary) do
    where(query, [j], j.salary_max <= ^max_salary)
  end

  defp maybe_filter_work_model(query, nil), do: query
  defp maybe_filter_work_model(query, work_model) do
    where(query, [j], j.work_model == ^work_model)
  end

  defp maybe_filter_location(query, nil), do: query
  defp maybe_filter_location(query, ""), do: query
  defp maybe_filter_location(query, location) do
    search_pattern = "%#{location}%"
    where(query, [j], ilike(j.location, ^search_pattern))
  end

  defp maybe_filter_date_range(query, nil, nil), do: query
  defp maybe_filter_date_range(query, from_date, nil) do
    where(query, [a], a.application_date >= ^from_date)
  end
  defp maybe_filter_date_range(query, nil, to_date) do
    where(query, [a], a.application_date <= ^to_date)
  end
  defp maybe_filter_date_range(query, from_date, to_date) do
    where(query, [a], a.application_date >= ^from_date and a.application_date <= ^to_date)
  end

  defp order_by_column(query, :company, order), do: order_by(query, [j], {^order, j.company_name})
  defp order_by_column(query, :position, order), do: order_by(query, [j], {^order, j.position_title})
  defp order_by_column(query, :priority, order), do: order_by(query, [j], {^order, j.priority})
  defp order_by_column(query, :created_at, order), do: order_by(query, [j], {^order, j.inserted_at})
  defp order_by_column(query, :salary, order), do: order_by(query, [j], {^order, j.salary_max})
  defp order_by_column(query, _, order), do: order_by(query, [j], {^order, j.inserted_at})

  defp order_by_app_column(query, :company, order), do: order_by(query, [a], {^order, a.company_name})
  defp order_by_app_column(query, :position, order), do: order_by(query, [a], {^order, a.position_title})
  defp order_by_app_column(query, :applied_date, order), do: order_by(query, [a], {^order, a.application_date})
  defp order_by_app_column(query, :status, order), do: order_by(query, [a], {^order, a.status})
  defp order_by_app_column(query, _, order), do: order_by(query, [a], {^order, a.application_date})
end
