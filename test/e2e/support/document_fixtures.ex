defmodule ClientatsWeb.E2E.DocumentFixtures do
  @moduledoc """
  Shared document fixtures for E2E tests (resumes and cover letters).
  """

  alias Clientats.Documents

  @doc """
  Create a resume in the database.
  """
  def create_resume(user_id, attrs \\ %{}) do
    {:ok, resume} =
      attrs
      |> Enum.into(%{
        user_id: user_id,
        name: "Main Resume",
        file_path: "/uploads/resume-#{System.unique_integer([:positive])}.pdf",
        original_filename: "resume.pdf",
        file_size: 102_400,
        is_default: true
      })
      |> Documents.create_resume()

    resume
  end

  @doc """
  Create a cover letter template in the database.
  """
  def create_cover_letter(user_id, attrs \\ %{}) do
    {:ok, template} =
      attrs
      |> Enum.into(%{
        user_id: user_id,
        name: "Default Template",
        content: "Dear {company_name},\n\nI am interested in the {position_title} role...",
        is_default: true
      })
      |> Documents.create_cover_letter_template()

    template
  end
end
