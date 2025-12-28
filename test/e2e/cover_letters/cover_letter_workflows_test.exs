defmodule ClientatsWeb.E2E.CoverLetterWorkflowsTest do
  use ClientatsWeb.FeatureCase, async: false

  import Wallaby.Query
  import ClientatsWeb.E2E.UserFixtures
  import ClientatsWeb.E2E.DocumentFixtures
  import ClientatsWeb.E2E.JobFixtures

  @moduletag :feature

  describe "create cover letter template" do
    test "successfully creates a new template", %{session: session} do
      _user = create_user_and_login(session)

      session
      |> visit("/dashboard/cover-letters")
      |> click(link("Create Template"))
      |> assert_has(css("h2", text: "New Cover Letter Template"))
      |> fill_in(css("input[name='cover_letter_template[name]']"), with: "General Template")
      |> fill_in(css("textarea[name='cover_letter_template[content]']"),
        with:
          "Dear Hiring Manager,\n\nI am writing to express my interest in the {position_title} role at {company_name}."
      )
      |> click(button("Create Template"))
      |> assert_has(css("h3", text: "General Template"))
    end

    test "validates template name is required", %{session: session} do
      _user = create_user_and_login(session)

      session
      |> visit("/dashboard/cover-letters/new")
      |> click(button("Create Template"))
      |> assert_has(css(".phx-form-error", text: "can't be blank"))
    end

    test "validates content is required", %{session: session} do
      _user = create_user_and_login(session)

      session
      |> visit("/dashboard/cover-letters/new")
      |> fill_in(css("input[name='cover_letter_template[name]']"), with: "Empty Template")
      |> click(button("Create Template"))
      |> assert_has(css(".phx-form-error", text: "can't be blank"))
    end

    test "first template is set as default", %{session: session} do
      _user = create_user_and_login(session)

      session
      |> visit("/dashboard/cover-letters/new")
      |> fill_in(css("input[name='cover_letter_template[name]']"), with: "First Template")
      |> fill_in(css("textarea[name='cover_letter_template[content]']"),
        with: "Dear Hiring Manager..."
      )
      |> click(button("Create Template"))
      |> assert_has(css("span.badge", text: "Default"))
    end

    test "can create multiple templates", %{session: session} do
      _user = create_user_and_login(session)

      # First template
      session
      |> visit("/dashboard/cover-letters/new")
      |> fill_in(css("input[name='cover_letter_template[name]']"), with: "Template 1")
      |> fill_in(css("textarea[name='cover_letter_template[content]']"), with: "Content 1")
      |> click(button("Create Template"))

      # Second template
      session
      |> visit("/dashboard/cover-letters")
      |> click(link("Create Template"))
      |> fill_in(css("input[name='cover_letter_template[name]']"), with: "Template 2")
      |> fill_in(css("textarea[name='cover_letter_template[content]']"), with: "Content 2")
      |> click(button("Create Template"))
      |> assert_has(css("h3", text: "Template 1"))
      |> assert_has(css("h3", text: "Template 2"))
    end
  end

  describe "template placeholders" do
    test "template supports company name placeholder", %{session: session} do
      _user = create_user_and_login(session)

      session
      |> visit("/dashboard/cover-letters/new")
      |> fill_in(css("input[name='cover_letter_template[name]']"), with: "Placeholder Test")
      |> fill_in(css("textarea[name='cover_letter_template[content]']"),
        with: "I am interested in working at {company_name}."
      )
      |> click(button("Create Template"))
      |> assert_has(css("p", text: "{company_name}"))
    end

    test "template supports position title placeholder", %{session: session} do
      _user = create_user_and_login(session)

      session
      |> visit("/dashboard/cover-letters/new")
      |> fill_in(css("input[name='cover_letter_template[name]']"), with: "Position Template")
      |> fill_in(css("textarea[name='cover_letter_template[content]']"),
        with: "I am applying for the {position_title} position."
      )
      |> click(button("Create Template"))
      |> assert_has(css("p", text: "{position_title}"))
    end

    test "shows available placeholders in help text", %{session: session} do
      _user = create_user_and_login(session)

      session
      |> visit("/dashboard/cover-letters/new")
      |> assert_has(css(".help-text", text: "{company_name}"))
      |> assert_has(css(".help-text", text: "{position_title}"))
      |> assert_has(css(".help-text", text: "{your_name}"))
    end
  end

  describe "manage templates" do
    test "displays all templates in list view", %{session: session} do
      user = create_user_and_login(session)
      create_cover_letter(user.id, %{name: "Template A"})
      create_cover_letter(user.id, %{name: "Template B"})
      create_cover_letter(user.id, %{name: "Template C"})

      session
      |> visit("/dashboard/cover-letters")
      |> assert_has(css("h3", text: "Template A"))
      |> assert_has(css("h3", text: "Template B"))
      |> assert_has(css("h3", text: "Template C"))
    end

    test "shows empty state when no templates", %{session: session} do
      _user = create_user_and_login(session)

      session
      |> visit("/dashboard/cover-letters")
      |> assert_has(css("p", text: "No cover letter templates yet"))
      |> assert_has(link("Create Template"))
    end

    test "can view template details", %{session: session} do
      user = create_user_and_login(session)

      template =
        create_cover_letter(user.id, %{
          name: "Detail Template",
          content: "This is the template content with {company_name} placeholder."
        })

      session
      |> visit("/dashboard/cover-letters")
      |> click(css("div[data-template-id='#{template.id}']"))
      |> assert_has(css("h2", text: "Detail Template"))
      |> assert_has(css("p", text: "This is the template content"))
      |> assert_has(css("p", text: "{company_name}"))
    end

    test "can set a template as default", %{session: session} do
      user = create_user_and_login(session)
      template1 = create_cover_letter(user.id, %{name: "Template 1", is_default: true})
      template2 = create_cover_letter(user.id, %{name: "Template 2", is_default: false})

      session
      |> visit("/dashboard/cover-letters")
      |> assert_has(css("div[data-template-id='#{template1.id}'] span.badge", text: "Default"))
      |> refute_has(css("div[data-template-id='#{template2.id}'] span.badge", text: "Default"))
      |> click(css("div[data-template-id='#{template2.id}'] button", text: "Set as Default"))
      |> assert_has(css("div[data-template-id='#{template2.id}'] span.badge", text: "Default"))
      |> refute_has(css("div[data-template-id='#{template1.id}'] span.badge", text: "Default"))
    end

    test "can edit template", %{session: session} do
      user = create_user_and_login(session)

      template =
        create_cover_letter(user.id, %{
          name: "Old Template",
          content: "Old content"
        })

      session
      |> visit("/dashboard/cover-letters")
      |> click(css("div[data-template-id='#{template.id}'] button", text: "Edit"))
      |> fill_in(css("input[name='cover_letter_template[name]']"), with: "Updated Template")
      |> fill_in(css("textarea[name='cover_letter_template[content]']"), with: "Updated content")
      |> click(button("Save Template"))
      |> assert_has(css("h3", text: "Updated Template"))
      |> refute_has(css("h3", text: "Old Template"))
    end

    test "can delete template", %{session: session} do
      user = create_user_and_login(session)
      template = create_cover_letter(user.id, %{name: "Delete Me"})

      session
      |> visit("/dashboard/cover-letters")
      |> assert_has(css("h3", text: "Delete Me"))
      |> click(css("div[data-template-id='#{template.id}'] button", text: "Delete"))
      |> refute_has(css("h3", text: "Delete Me"))
      |> assert_has(css("p", text: "No cover letter templates yet"))
    end

    test "can duplicate template", %{session: session} do
      user = create_user_and_login(session)

      template =
        create_cover_letter(user.id, %{
          name: "Original Template",
          content: "Original content"
        })

      session
      |> visit("/dashboard/cover-letters")
      |> click(css("div[data-template-id='#{template.id}'] button", text: "Duplicate"))
      |> assert_has(css("h3", text: "Original Template"))
      |> assert_has(css("h3", text: "Original Template (Copy)"))
    end
  end

  describe "generate cover letter from template" do
    test "can generate cover letter for a job application", %{session: session} do
      user = create_user_and_login(session)

      template =
        create_cover_letter(user.id, %{
          name: "Application Template",
          content:
            "Dear Hiring Manager,\n\nI am excited about the {position_title} role at {company_name}."
        })

      application =
        create_job_application(user.id, %{
          company_name: "Tech Corp",
          position_title: "Software Engineer"
        })

      session
      |> visit("/dashboard/applications/#{application.id}")
      |> click(button("Generate Cover Letter"))
      |> click(css("select[name='template_id'] option", text: "Application Template"))
      |> click(button("Generate"))
      |> assert_has(css("h3", text: "Generated Cover Letter"))
      |> assert_has(css("p", text: "I am excited about the Software Engineer role at Tech Corp"))
    end

    test "placeholders are replaced with actual values", %{session: session} do
      user = create_user_and_login(session)

      create_cover_letter(user.id, %{
        name: "Full Template",
        content: "Dear {company_name} team,\n\nI am {your_name} applying for {position_title}.",
        is_default: true
      })

      application =
        create_job_application(user.id, %{
          company_name: "Acme Inc",
          position_title: "Developer"
        })

      session
      |> visit("/dashboard/applications/#{application.id}")
      |> click(button("Generate Cover Letter"))
      |> click(button("Generate"))
      |> assert_has(css("p", text: "Dear Acme Inc team"))
      |> assert_has(css("p", text: "applying for Developer"))
      |> refute_has(css("p", text: "{company_name}"))
      |> refute_has(css("p", text: "{position_title}"))
    end

    test "can preview before saving generated cover letter", %{session: session} do
      user = create_user_and_login(session)

      create_cover_letter(user.id, %{
        name: "Preview Template",
        content: "Preview content for {company_name}.",
        is_default: true
      })

      application = create_job_application(user.id, %{company_name: "Preview Corp"})

      session
      |> visit("/dashboard/applications/#{application.id}")
      |> click(button("Generate Cover Letter"))
      |> click(button("Generate"))
      |> assert_has(css("h3", text: "Preview"))
      |> assert_has(button("Save Cover Letter"))
      |> assert_has(button("Edit"))
    end

    test "can edit generated cover letter before saving", %{session: session} do
      user = create_user_and_login(session)

      create_cover_letter(user.id, %{
        name: "Edit Template",
        content: "Initial content.",
        is_default: true
      })

      application = create_job_application(user.id)

      session
      |> visit("/dashboard/applications/#{application.id}")
      |> click(button("Generate Cover Letter"))
      |> click(button("Generate"))
      |> click(button("Edit"))
      |> fill_in(css("textarea[name='content']"), with: "Modified content for this application.")
      |> click(button("Save Cover Letter"))
      |> assert_has(css("p", text: "Modified content for this application"))
    end

    test "generated cover letter is attached to application", %{session: session} do
      user = create_user_and_login(session)

      create_cover_letter(user.id, %{
        name: "Attach Template",
        content: "Cover letter content.",
        is_default: true
      })

      application = create_job_application(user.id)

      session
      |> visit("/dashboard/applications/#{application.id}")
      |> click(button("Generate Cover Letter"))
      |> click(button("Generate"))
      |> click(button("Save Cover Letter"))
      |> assert_has(css("div.cover-letter-attached"))
      |> assert_has(button("Download Cover Letter"))
    end
  end

  describe "AI-generated cover letters" do
    test "can generate cover letter with AI", %{session: session} do
      user = create_user_and_login(session)

      application =
        create_job_application(user.id, %{
          company_name: "AI Corp",
          position_title: "AI Engineer"
        })

      session
      |> visit("/dashboard/applications/#{application.id}")
      |> click(button("Generate Cover Letter"))
      |> click(link("Generate with AI"))
      |> assert_has(css("h3", text: "AI Cover Letter Generator"))
      |> fill_in(css("textarea[name='additional_info']"),
        with: "I have 5 years of experience in machine learning."
      )
      |> click(button("Generate with AI"))
      |> assert_has(css("p", text: "Generating cover letter..."))
    end

    test "AI generation uses application details", %{session: session} do
      user = create_user_and_login(session)

      application =
        create_job_application(user.id, %{
          company_name: "Smart Corp",
          position_title: "ML Engineer"
        })

      session
      |> visit("/dashboard/applications/#{application.id}")
      |> click(button("Generate Cover Letter"))
      |> click(link("Generate with AI"))
      |> assert_has(css("p", text: "Generating for ML Engineer at Smart Corp"))
    end

    test "can preview AI-generated cover letter", %{session: session} do
      user = create_user_and_login(session)
      application = create_job_application(user.id)

      session
      |> visit("/dashboard/applications/#{application.id}")
      |> click(button("Generate Cover Letter"))
      |> click(link("Generate with AI"))
      |> click(button("Generate with AI"))
      # Wait for generation
      |> assert_has(css("h3", text: "Preview"))
      |> assert_has(button("Save Cover Letter"))
      |> assert_has(button("Regenerate"))
    end

    test "shows generation progress", %{session: session} do
      user = create_user_and_login(session)
      application = create_job_application(user.id)

      session
      |> visit("/dashboard/applications/#{application.id}")
      |> click(button("Generate Cover Letter"))
      |> click(link("Generate with AI"))
      |> click(button("Generate with AI"))
      |> assert_has(css(".spinner"))
      |> assert_has(css("p", text: "This may take up to 30 seconds"))
    end
  end

  describe "download cover letters" do
    test "can download generated cover letter as PDF", %{session: session} do
      user = create_user_and_login(session)

      application =
        create_job_application(user.id, %{
          company_name: "Download Corp",
          position_title: "Engineer"
        })

      create_cover_letter(user.id, %{content: "Letter content", is_default: true})

      session
      |> visit("/dashboard/applications/#{application.id}")
      |> click(button("Generate Cover Letter"))
      |> click(button("Generate"))
      |> click(button("Save Cover Letter"))
      |> assert_has(button("Download Cover Letter"))
      |> click(button("Download Cover Letter"))
      |> assert_has(
        css("a[href='/dashboard/applications/#{application.id}/download-cover-letter']")
      )
    end

    test "downloaded file has correct naming format", %{session: session} do
      user = create_user_and_login(session)

      application =
        create_job_application(user.id, %{
          company_name: "File Corp",
          position_title: "Developer"
        })

      create_cover_letter(user.id, %{content: "Content", is_default: true})

      session
      |> visit("/dashboard/applications/#{application.id}")
      |> click(button("Generate Cover Letter"))
      |> click(button("Generate"))
      |> click(button("Save Cover Letter"))
      |> assert_has(css("a[download='cover_letter_File_Corp_Developer.pdf']"))
    end
  end

  describe "search and filtering" do
    test "can search templates by name", %{session: session} do
      user = create_user_and_login(session)
      create_cover_letter(user.id, %{name: "Technical Template"})
      create_cover_letter(user.id, %{name: "General Template"})

      session
      |> visit("/dashboard/cover-letters")
      |> fill_in(css("input[name='search']"), with: "Technical")
      |> assert_has(css("h3", text: "Technical Template"))
      |> refute_has(css("h3", text: "General Template"))
    end

    test "can search templates by content", %{session: session} do
      user = create_user_and_login(session)
      create_cover_letter(user.id, %{name: "Template A", content: "Python experience"})
      create_cover_letter(user.id, %{name: "Template B", content: "Java experience"})

      session
      |> visit("/dashboard/cover-letters")
      |> fill_in(css("input[name='search']"), with: "Python")
      |> assert_has(css("h3", text: "Template A"))
      |> refute_has(css("h3", text: "Template B"))
    end

    test "can filter to show only default template", %{session: session} do
      user = create_user_and_login(session)
      create_cover_letter(user.id, %{name: "Default Template", is_default: true})
      create_cover_letter(user.id, %{name: "Other Template", is_default: false})

      session
      |> visit("/dashboard/cover-letters")
      |> click(css("input[name='show_default_only']"))
      |> assert_has(css("h3", text: "Default Template"))
      |> refute_has(css("h3", text: "Other Template"))
    end
  end

  describe "complete workflow" do
    test "full lifecycle: create template -> generate for application -> edit -> save -> download",
         %{session: session} do
      user = create_user_and_login(session)

      # Create template
      session
      |> visit("/dashboard/cover-letters/new")
      |> fill_in(css("input[name='cover_letter_template[name]']"), with: "Professional Template")
      |> fill_in(css("textarea[name='cover_letter_template[content]']"),
        with:
          "Dear Hiring Manager at {company_name},\n\nI am excited to apply for {position_title}."
      )
      |> click(button("Create Template"))

      # Create application
      application =
        create_job_application(user.id, %{
          company_name: "Dream Corp",
          position_title: "Senior Engineer"
        })

      # Generate cover letter
      session
      |> visit("/dashboard/applications/#{application.id}")
      |> click(button("Generate Cover Letter"))
      |> click(css("select[name='template_id'] option", text: "Professional Template"))
      |> click(button("Generate"))

      # Edit
      session
      |> click(button("Edit"))
      |> fill_in(css("textarea[name='content']"),
        with:
          "Dear Hiring Manager at Dream Corp,\n\nI am excited to apply for Senior Engineer.\n\nAdditional custom content."
      )

      # Save
      session
      |> click(button("Save Cover Letter"))
      |> assert_has(css("p", text: "Additional custom content"))

      # Download
      session
      |> click(button("Download Cover Letter"))
      |> assert_has(css("a[download='cover_letter_Dream_Corp_Senior_Engineer.pdf']"))
    end
  end
end
