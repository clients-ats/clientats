defmodule ClientatsWeb.E2E.ResumeWorkflowsTest do
  use ClientatsWeb.FeatureCase, async: false

  import Wallaby.Query
  import ClientatsWeb.E2E.UserFixtures
  import ClientatsWeb.E2E.DocumentFixtures

  @moduletag :feature

  describe "resume upload" do
    test "successfully uploads a new resume", %{session: session} do
      _user = create_user_and_login(session)

      session
      |> visit("/dashboard/resumes")
      |> click(link("Upload Resume"))
      |> assert_has(css("h2", text: "Upload Resume"))
      |> fill_in(css("input[name='resume[name]']"), with: "Main Resume")
      |> attach_file(css("input[type='file']"), path: "/tmp/test_resume.pdf")
      |> click(button("Upload"))
      |> assert_has(css("h3", text: "Main Resume"))
      |> assert_has(css("p", text: "test_resume.pdf"))
    end

    test "validates resume name is required", %{session: session} do
      _user = create_user_and_login(session)

      session
      |> visit("/dashboard/resumes/new")
      |> click(button("Upload"))
      |> assert_has(css(".phx-form-error", text: "can't be blank"))
    end

    test "validates file is required", %{session: session} do
      _user = create_user_and_login(session)

      session
      |> visit("/dashboard/resumes/new")
      |> fill_in(css("input[name='resume[name]']"), with: "Test Resume")
      |> click(button("Upload"))
      |> assert_has(css(".error-message", text: "Please select a file"))
    end

    test "validates file size limit", %{session: session} do
      _user = create_user_and_login(session)

      session
      |> visit("/dashboard/resumes/new")
      |> fill_in(css("input[name='resume[name]']"), with: "Large Resume")
      |> attach_file(css("input[type='file']"), path: "/tmp/large_resume.pdf")
      |> click(button("Upload"))
      |> assert_has(css(".error-message", text: "File size must be under 5MB"))
    end

    test "validates file type (PDF only)", %{session: session} do
      _user = create_user_and_login(session)

      session
      |> visit("/dashboard/resumes/new")
      |> fill_in(css("input[name='resume[name]']"), with: "Invalid Resume")
      |> attach_file(css("input[type='file']"), path: "/tmp/resume.docx")
      |> click(button("Upload"))
      |> assert_has(css(".error-message", text: "Only PDF files are allowed"))
    end

    test "can upload multiple resumes", %{session: session} do
      _user = create_user_and_login(session)

      # Upload first resume
      session
      |> visit("/dashboard/resumes/new")
      |> fill_in(css("input[name='resume[name]']"), with: "Resume 1")
      |> attach_file(css("input[type='file']"), path: "/tmp/resume1.pdf")
      |> click(button("Upload"))
      |> assert_has(css("h3", text: "Resume 1"))

      # Upload second resume
      session
      |> visit("/dashboard/resumes")
      |> click(link("Upload Resume"))
      |> fill_in(css("input[name='resume[name]']"), with: "Resume 2")
      |> attach_file(css("input[type='file']"), path: "/tmp/resume2.pdf")
      |> click(button("Upload"))
      |> assert_has(css("h3", text: "Resume 1"))
      |> assert_has(css("h3", text: "Resume 2"))
    end

    test "first uploaded resume is set as default", %{session: session} do
      _user = create_user_and_login(session)

      session
      |> visit("/dashboard/resumes/new")
      |> fill_in(css("input[name='resume[name]']"), with: "First Resume")
      |> attach_file(css("input[type='file']"), path: "/tmp/resume.pdf")
      |> click(button("Upload"))
      |> assert_has(css("span.badge", text: "Default"))
    end
  end

  describe "resume management" do
    test "displays all resumes in list view", %{session: session} do
      user = create_user_and_login(session)
      create_resume(user.id, %{name: "Resume A"})
      create_resume(user.id, %{name: "Resume B"})
      create_resume(user.id, %{name: "Resume C"})

      session
      |> visit("/dashboard/resumes")
      |> assert_has(css("h3", text: "Resume A"))
      |> assert_has(css("h3", text: "Resume B"))
      |> assert_has(css("h3", text: "Resume C"))
    end

    test "shows empty state when no resumes", %{session: session} do
      _user = create_user_and_login(session)

      session
      |> visit("/dashboard/resumes")
      |> assert_has(css("p", text: "No resumes uploaded yet"))
      |> assert_has(link("Upload Resume"))
    end

    test "can view resume details", %{session: session} do
      user = create_user_and_login(session)

      resume =
        create_resume(user.id, %{
          name: "Detail Resume",
          original_filename: "my_resume.pdf",
          file_size: 102_400
        })

      session
      |> visit("/dashboard/resumes")
      |> click(css("div[data-resume-id='#{resume.id}']"))
      |> assert_has(css("h2", text: "Detail Resume"))
      |> assert_has(css("p", text: "my_resume.pdf"))
      |> assert_has(css("p", text: "100 KB"))
    end

    test "displays file size in human readable format", %{session: session} do
      user = create_user_and_login(session)
      create_resume(user.id, %{name: "Small Resume", file_size: 1_024})
      create_resume(user.id, %{name: "Medium Resume", file_size: 102_400})
      create_resume(user.id, %{name: "Large Resume", file_size: 1_048_576})

      session
      |> visit("/dashboard/resumes")
      |> assert_has(css("p", text: "1 KB"))
      |> assert_has(css("p", text: "100 KB"))
      |> assert_has(css("p", text: "1 MB"))
    end

    test "can set a resume as default", %{session: session} do
      user = create_user_and_login(session)
      resume1 = create_resume(user.id, %{name: "Resume 1", is_default: true})
      resume2 = create_resume(user.id, %{name: "Resume 2", is_default: false})

      session
      |> visit("/dashboard/resumes")
      |> assert_has(css("div[data-resume-id='#{resume1.id}'] span.badge", text: "Default"))
      |> refute_has(css("div[data-resume-id='#{resume2.id}'] span.badge", text: "Default"))
      |> click(css("div[data-resume-id='#{resume2.id}'] button", text: "Set as Default"))
      |> assert_has(css("div[data-resume-id='#{resume2.id}'] span.badge", text: "Default"))
      |> refute_has(css("div[data-resume-id='#{resume1.id}'] span.badge", text: "Default"))
    end

    test "can edit resume name", %{session: session} do
      user = create_user_and_login(session)
      resume = create_resume(user.id, %{name: "Old Name"})

      session
      |> visit("/dashboard/resumes")
      |> click(css("div[data-resume-id='#{resume.id}'] button", text: "Edit"))
      |> fill_in(css("input[name='resume[name]']"), with: "New Name")
      |> click(button("Save"))
      |> assert_has(css("h3", text: "New Name"))
      |> refute_has(css("h3", text: "Old Name"))
    end

    test "can delete resume", %{session: session} do
      user = create_user_and_login(session)
      resume = create_resume(user.id, %{name: "Delete Me"})

      session
      |> visit("/dashboard/resumes")
      |> assert_has(css("h3", text: "Delete Me"))
      |> click(css("div[data-resume-id='#{resume.id}'] button", text: "Delete"))
      |> refute_has(css("h3", text: "Delete Me"))
      |> assert_has(css("p", text: "No resumes uploaded yet"))
    end

    test "cannot delete the only default resume without warning", %{session: session} do
      user = create_user_and_login(session)
      create_resume(user.id, %{name: "Default Resume", is_default: true})

      session
      |> visit("/dashboard/resumes")
      |> click(button("Delete"))
      |> assert_has(css(".alert-warning", text: "This is your default resume"))
    end
  end

  describe "resume download" do
    test "can download resume", %{session: session} do
      user = create_user_and_login(session)
      resume = create_resume(user.id, %{name: "Download Resume"})

      session
      |> visit("/dashboard/resumes")
      |> click(css("div[data-resume-id='#{resume.id}'] a", text: "Download"))
      # File download is triggered - verify the link exists
      |> assert_has(css("a[href='/dashboard/resumes/#{resume.id}/download']"))
    end

    test "download link contains correct filename", %{session: session} do
      user = create_user_and_login(session)

      resume =
        create_resume(user.id, %{
          name: "My Resume",
          original_filename: "resume_2024.pdf"
        })

      session
      |> visit("/dashboard/resumes")
      |> assert_has(css("a[download='resume_2024.pdf']"))
    end
  end

  describe "resume usage in applications" do
    test "can attach resume to job application", %{session: session} do
      user = create_user_and_login(session)
      resume = create_resume(user.id, %{name: "Application Resume"})

      session
      |> visit("/dashboard/applications/new")
      |> fill_in(css("input[name='job_application[company_name]']"), with: "Tech Corp")
      |> fill_in(css("input[name='job_application[position_title]']"), with: "Engineer")
      |> click(
        css("select[name='job_application[resume_id]'] option", text: "Application Resume")
      )
      |> click(button("Create Application"))
      |> assert_has(css("p", text: "Resume: Application Resume"))
    end

    test "default resume is pre-selected when creating application", %{session: session} do
      user = create_user_and_login(session)
      create_resume(user.id, %{name: "Default Resume", is_default: true})
      create_resume(user.id, %{name: "Other Resume", is_default: false})

      session
      |> visit("/dashboard/applications/new")
      |> assert_has(
        css("select[name='job_application[resume_id]'] option[selected]", text: "Default Resume")
      )
    end

    test "shows message if no resumes available when creating application", %{session: session} do
      _user = create_user_and_login(session)

      session
      |> visit("/dashboard/applications/new")
      |> assert_has(css("p.alert-info", text: "You haven't uploaded any resumes yet"))
      |> assert_has(link("Upload Resume"))
    end
  end

  describe "resume search and filtering" do
    test "can search resumes by name", %{session: session} do
      user = create_user_and_login(session)
      create_resume(user.id, %{name: "Frontend Resume"})
      create_resume(user.id, %{name: "Backend Resume"})

      session
      |> visit("/dashboard/resumes")
      |> fill_in(css("input[name='search']"), with: "Frontend")
      |> assert_has(css("h3", text: "Frontend Resume"))
      |> refute_has(css("h3", text: "Backend Resume"))
    end

    test "can filter to show only default resume", %{session: session} do
      user = create_user_and_login(session)
      create_resume(user.id, %{name: "Default Resume", is_default: true})
      create_resume(user.id, %{name: "Other Resume", is_default: false})

      session
      |> visit("/dashboard/resumes")
      |> click(css("input[name='show_default_only']"))
      |> assert_has(css("h3", text: "Default Resume"))
      |> refute_has(css("h3", text: "Other Resume"))
    end

    test "can sort resumes by date uploaded", %{session: session} do
      user = create_user_and_login(session)
      create_resume(user.id, %{name: "Oldest Resume"})
      :timer.sleep(100)
      create_resume(user.id, %{name: "Newest Resume"})

      session
      |> visit("/dashboard/resumes")
      |> click(css("select[name='sort'] option[value='date_uploaded']"))
      |> assert_has(css("div.resume:first-child h3", text: "Newest Resume"))
    end

    test "can sort resumes alphabetically", %{session: session} do
      user = create_user_and_login(session)
      create_resume(user.id, %{name: "Zebra Resume"})
      create_resume(user.id, %{name: "Alpha Resume"})

      session
      |> visit("/dashboard/resumes")
      |> click(css("select[name='sort'] option[value='name']"))
      |> assert_has(css("div.resume:first-child h3", text: "Alpha Resume"))
    end
  end

  describe "AI-generated resumes" do
    test "can request AI-generated resume", %{session: session} do
      _user = create_user_and_login(session)

      session
      |> visit("/dashboard/resumes")
      |> click(link("Generate with AI"))
      |> assert_has(css("h2", text: "AI Resume Generator"))
      |> fill_in(css("textarea[name='job_description']"),
        with: "Looking for a software engineer..."
      )
      |> fill_in(css("textarea[name='skills']"), with: "Python, Django, PostgreSQL")
      |> click(button("Generate Resume"))
      |> assert_has(css("h3", text: "Generating your resume..."))
    end

    test "AI generation shows progress indicator", %{session: session} do
      _user = create_user_and_login(session)

      session
      |> visit("/dashboard/resumes/generate")
      |> fill_in(css("textarea[name='job_description']"), with: "Senior developer role")
      |> click(button("Generate Resume"))
      |> assert_has(css(".spinner"))
      |> assert_has(css("p", text: "This may take a few moments"))
    end

    test "can preview AI-generated resume before saving", %{session: session} do
      _user = create_user_and_login(session)

      session
      |> visit("/dashboard/resumes/generate")
      |> fill_in(css("textarea[name='job_description']"), with: "Developer position")
      |> click(button("Generate Resume"))
      # Wait for generation
      |> assert_has(css("h3", text: "Preview"))
      |> assert_has(button("Save Resume"))
      |> assert_has(button("Regenerate"))
    end

    test "can save AI-generated resume", %{session: session} do
      _user = create_user_and_login(session)

      session
      |> visit("/dashboard/resumes/generate")
      |> fill_in(css("textarea[name='job_description']"), with: "Engineer role")
      |> click(button("Generate Resume"))
      |> assert_has(css("h3", text: "Preview"))
      |> fill_in(css("input[name='resume[name]']"), with: "AI Generated Resume")
      |> click(button("Save Resume"))
      |> assert_has(css("h1", text: "My Resumes"))
      |> assert_has(css("h3", text: "AI Generated Resume"))
    end
  end

  describe "complete workflow" do
    test "full resume lifecycle: upload -> set default -> use in application -> download", %{
      session: session
    } do
      user = create_user_and_login(session)

      # Upload resume
      session
      |> visit("/dashboard/resumes/new")
      |> fill_in(css("input[name='resume[name]']"), with: "My Professional Resume")
      |> attach_file(css("input[type='file']"), path: "/tmp/resume.pdf")
      |> click(button("Upload"))
      |> assert_has(css("h3", text: "My Professional Resume"))

      # Set as default
      session
      |> click(button("Set as Default"))
      |> assert_has(css("span.badge", text: "Default"))

      # Use in application
      session
      |> visit("/dashboard/applications/new")
      |> fill_in(css("input[name='job_application[company_name]']"), with: "Dream Corp")
      |> fill_in(css("input[name='job_application[position_title]']"), with: "Dream Job")
      |> assert_has(
        css("select[name='job_application[resume_id]'] option[selected]",
          text: "My Professional Resume"
        )
      )
      |> click(button("Create Application"))
      |> assert_has(css("p", text: "Resume: My Professional Resume"))

      # Download resume
      session
      |> visit("/dashboard/resumes")
      |> assert_has(css("a[download='resume.pdf']"))
    end
  end
end
