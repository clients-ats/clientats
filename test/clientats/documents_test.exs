defmodule Clientats.DocumentsTest do
  use Clientats.DataCase

  alias Clientats.Documents

  describe "resumes" do
    test "list_resumes/1 returns all resumes for a user" do
      user = user_fixture()
      resume1 = resume_fixture(user_id: user.id)
      resume2 = resume_fixture(user_id: user.id)
      other_user = user_fixture()
      _other_resume = resume_fixture(user_id: other_user.id)

      resumes = Documents.list_resumes(user.id)
      resume_ids = Enum.map(resumes, & &1.id)

      assert length(resumes) == 2
      assert resume1.id in resume_ids
      assert resume2.id in resume_ids
    end

    test "list_resumes/1 orders by default first" do
      user = user_fixture()
      _resume1 = resume_fixture(user_id: user.id, name: "First", is_default: false)
      _resume2 = resume_fixture(user_id: user.id, name: "Default", is_default: true)
      _resume3 = resume_fixture(user_id: user.id, name: "Third", is_default: false)

      resumes = Documents.list_resumes(user.id)

      assert Enum.at(resumes, 0).name == "Default"
      assert Enum.at(resumes, 0).is_default
    end

    test "get_resume!/1 returns the resume with given id" do
      user = user_fixture()
      resume = resume_fixture(user_id: user.id)
      assert Documents.get_resume!(resume.id).id == resume.id
    end

    test "create_resume/1 with valid data creates a resume" do
      user = user_fixture()

      valid_attrs = %{
        user_id: user.id,
        name: "Software Engineer 2024",
        description: "Tailored for backend positions",
        file_path: "/uploads/resumes/test.pdf",
        original_filename: "resume.pdf",
        file_size: 1024
      }

      assert {:ok, resume} = Documents.create_resume(valid_attrs)
      assert resume.name == "Software Engineer 2024"
      assert resume.file_path == "/uploads/resumes/test.pdf"
    end

    test "create_resume/1 requires name" do
      user = user_fixture()

      invalid_attrs = %{
        user_id: user.id,
        file_path: "/uploads/resumes/test.pdf",
        original_filename: "resume.pdf"
      }

      assert {:error, changeset} = Documents.create_resume(invalid_attrs)
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "update_resume/2 with valid data updates the resume" do
      user = user_fixture()
      resume = resume_fixture(user_id: user.id)
      update_attrs = %{name: "Updated Resume", description: "New description"}

      assert {:ok, updated} = Documents.update_resume(resume, update_attrs)
      assert updated.name == "Updated Resume"
      assert updated.description == "New description"
    end

    test "delete_resume/1 deletes the resume" do
      user = user_fixture()
      resume = resume_fixture(user_id: user.id)
      assert {:ok, _} = Documents.delete_resume(resume)
      assert_raise Ecto.NoResultsError, fn -> Documents.get_resume!(resume.id) end
    end

    test "set_default_resume/1 sets resume as default and unsets others" do
      user = user_fixture()
      resume1 = resume_fixture(user_id: user.id, is_default: true)
      resume2 = resume_fixture(user_id: user.id, is_default: false)

      assert {:ok, _} = Documents.set_default_resume(resume2)

      updated1 = Documents.get_resume!(resume1.id)
      updated2 = Documents.get_resume!(resume2.id)

      refute updated1.is_default
      assert updated2.is_default
    end
  end

  describe "cover_letter_templates" do
    test "list_cover_letter_templates/1 returns all templates for a user" do
      user = user_fixture()
      template1 = cover_letter_fixture(user_id: user.id)
      template2 = cover_letter_fixture(user_id: user.id)
      other_user = user_fixture()
      _other_template = cover_letter_fixture(user_id: other_user.id)

      templates = Documents.list_cover_letter_templates(user.id)
      template_ids = Enum.map(templates, & &1.id)

      assert length(templates) == 2
      assert template1.id in template_ids
      assert template2.id in template_ids
    end

    test "list_cover_letter_templates/1 orders by default first" do
      user = user_fixture()
      _template1 = cover_letter_fixture(user_id: user.id, name: "First", is_default: false)
      _template2 = cover_letter_fixture(user_id: user.id, name: "Default", is_default: true)
      _template3 = cover_letter_fixture(user_id: user.id, name: "Third", is_default: false)

      templates = Documents.list_cover_letter_templates(user.id)

      assert Enum.at(templates, 0).name == "Default"
      assert Enum.at(templates, 0).is_default
    end

    test "get_cover_letter_template!/1 returns the template with given id" do
      user = user_fixture()
      template = cover_letter_fixture(user_id: user.id)
      assert Documents.get_cover_letter_template!(template.id).id == template.id
    end

    test "create_cover_letter_template/1 with valid data creates a template" do
      user = user_fixture()

      valid_attrs = %{
        user_id: user.id,
        name: "General Software Engineer",
        description: "For backend positions",
        content: "Dear Hiring Manager,\n\nI am writing..."
      }

      assert {:ok, template} = Documents.create_cover_letter_template(valid_attrs)
      assert template.name == "General Software Engineer"
      assert template.content =~ "Dear Hiring Manager"
    end

    test "create_cover_letter_template/1 requires content" do
      user = user_fixture()

      invalid_attrs = %{
        user_id: user.id,
        name: "Template"
      }

      assert {:error, changeset} = Documents.create_cover_letter_template(invalid_attrs)
      assert %{content: ["can't be blank"]} = errors_on(changeset)
    end

    test "update_cover_letter_template/2 with valid data updates the template" do
      user = user_fixture()
      template = cover_letter_fixture(user_id: user.id)
      update_attrs = %{name: "Updated Template", content: "New content"}

      assert {:ok, updated} = Documents.update_cover_letter_template(template, update_attrs)
      assert updated.name == "Updated Template"
      assert updated.content == "New content"
    end

    test "delete_cover_letter_template/1 deletes the template" do
      user = user_fixture()
      template = cover_letter_fixture(user_id: user.id)
      assert {:ok, _} = Documents.delete_cover_letter_template(template)
      assert_raise Ecto.NoResultsError, fn -> Documents.get_cover_letter_template!(template.id) end
    end

    test "set_default_cover_letter_template/1 sets template as default and unsets others" do
      user = user_fixture()
      template1 = cover_letter_fixture(user_id: user.id, is_default: true)
      template2 = cover_letter_fixture(user_id: user.id, is_default: false)

      assert {:ok, _} = Documents.set_default_cover_letter_template(template2)

      updated1 = Documents.get_cover_letter_template!(template1.id)
      updated2 = Documents.get_cover_letter_template!(template2.id)

      refute updated1.is_default
      assert updated2.is_default
    end
  end

  defp user_fixture(attrs \\ %{}) do
    default_attrs = %{
      email: "user#{System.unique_integer([:positive])}@example.com",
      password: "password123",
      password_confirmation: "password123",
      first_name: "Test",
      last_name: "User"
    }

    attrs = Enum.into(attrs, default_attrs)
    {:ok, user} = Clientats.Accounts.register_user(attrs)
    user
  end

  defp resume_fixture(attrs \\ %{}) do
    default_attrs = %{
      name: "Test Resume",
      file_path: "/uploads/resumes/test-#{System.unique_integer([:positive])}.pdf",
      original_filename: "resume.pdf",
      is_default: false
    }

    attrs = Enum.into(attrs, default_attrs)
    {:ok, resume} = Documents.create_resume(attrs)
    resume
  end

  defp cover_letter_fixture(attrs \\ %{}) do
    default_attrs = %{
      name: "Test Template",
      content: "Dear Hiring Manager,\n\nI am writing to express my interest...",
      is_default: false
    }

    attrs = Enum.into(attrs, default_attrs)
    {:ok, template} = Documents.create_cover_letter_template(attrs)
    template
  end
end
