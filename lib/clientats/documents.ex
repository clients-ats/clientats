defmodule Clientats.Documents do
  import Ecto.Query, warn: false
  alias Clientats.Repo

  alias Clientats.Documents.{Resume, CoverLetterTemplate}

  # Resumes

  def list_resumes(user_id) do
    Resume
    |> where(user_id: ^user_id)
    |> order_by([r], [desc: r.is_default, desc: r.inserted_at])
    |> Repo.all()
  end

  def get_resume!(id), do: Repo.get!(Resume, id)

  def create_resume(attrs \\ %{}) do
    %Resume{}
    |> Resume.changeset(attrs)
    |> Repo.insert()
  end

  def update_resume(%Resume{} = resume, attrs) do
    resume
    |> Resume.changeset(attrs)
    |> Repo.update()
  end

  def delete_resume(%Resume{} = resume) do
    Repo.delete(resume)
  end

  def change_resume(%Resume{} = resume, attrs \\ %{}) do
    Resume.changeset(resume, attrs)
  end

  def set_default_resume(%Resume{} = resume) do
    Repo.transaction(fn ->
      Resume
      |> where(user_id: ^resume.user_id)
      |> Repo.update_all(set: [is_default: false])

      resume
      |> Ecto.Changeset.change(is_default: true)
      |> Repo.update!()
    end)
  end

  # Cover Letter Templates

  def list_cover_letter_templates(user_id) do
    CoverLetterTemplate
    |> where(user_id: ^user_id)
    |> order_by([c], [desc: c.is_default, desc: c.inserted_at])
    |> Repo.all()
  end

  def get_cover_letter_template!(id), do: Repo.get!(CoverLetterTemplate, id)

  def create_cover_letter_template(attrs \\ %{}) do
    %CoverLetterTemplate{}
    |> CoverLetterTemplate.changeset(attrs)
    |> Repo.insert()
  end

  def update_cover_letter_template(%CoverLetterTemplate{} = template, attrs) do
    template
    |> CoverLetterTemplate.changeset(attrs)
    |> Repo.update()
  end

  def delete_cover_letter_template(%CoverLetterTemplate{} = template) do
    Repo.delete(template)
  end

  def change_cover_letter_template(%CoverLetterTemplate{} = template, attrs \\ %{}) do
    CoverLetterTemplate.changeset(template, attrs)
  end

  def set_default_cover_letter_template(%CoverLetterTemplate{} = template) do
    Repo.transaction(fn ->
      CoverLetterTemplate
      |> where(user_id: ^template.user_id)
      |> Repo.update_all(set: [is_default: false])

      template
      |> Ecto.Changeset.change(is_default: true)
      |> Repo.update!()
    end)
  end
end
