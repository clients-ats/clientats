defmodule ClientatsWeb.JobApplicationController do
  use ClientatsWeb, :controller
  alias Clientats.Jobs
  alias Clientats.Browser

  def download_cover_letter(conn, %{"id" => id}) do
    application = 
      id 
      |> Jobs.get_job_application!()
      |> Clientats.Repo.preload(:user)
    
    # Simple HTML template for the cover letter
    html = """
    <!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body {
      font-family: serif;
      line-height: 1.6;
      color: #333;
      max-width: 800px;
      margin: 0 auto;
      padding: 20px;
    }
    .header {
      margin-bottom: 40px;
    }
    .date {
      margin-bottom: 20px;
    }
    .content {
      white-space: pre-wrap;
    }
  </style>
</head>
<body>
  <div class="header">
    <strong>#{application.user.first_name} #{application.user.last_name}</strong><br>
    #{application.user.email}
  </div>
  
  <div class="date">
    #{Date.utc_today() |> Calendar.strftime("%B %d, %Y")}
  </div>

  <div class="content">
    #{application.cover_letter_content || "No content provided."} 
  </div>
</body>
</html>
"""

    case Browser.generate_pdf(html) do
      {:ok, path} ->
        conn
        |> put_resp_content_type("application/pdf")
        |> put_resp_header("content-disposition", "attachment; filename=\"cover_letter_#{application.company_name |> String.downcase() |> String.replace(" ", "_")}.pdf\"")
        |> send_file(200, path)
        
      {:error, reason} ->
        conn
        |> put_flash(:error, "Failed to generate PDF: #{inspect(reason)}")
        |> redirect(to: ~p"/dashboard/applications/#{id}")
    end
  end
end
