defmodule ScreenshotMock do
  @moduledoc """
  Mock screenshot generator for testing job import wizard.

  Provides synthetic screenshot data that simulates real job posting pages
  from various job boards with different layouts and HTML structures.
  """

  @doc """
  Generate a mock screenshot file for testing.

  Returns a temporary PNG file path containing test screenshot data.
  In a real scenario, these would be actual screenshots of job boards.
  """
  def generate_mock_screenshot(scenario \\ :generic) do
    filename = "/tmp/clientats_mock_screenshot_#{System.unique_integer()}.png"
    image_data = generate_image_data(scenario)
    File.write!(filename, image_data)
    filename
  end

  @doc """
  Clean up a mock screenshot file.
  """
  def cleanup_screenshot(filename) do
    if File.exists?(filename) do
      File.rm!(filename)
    end
    :ok
  end

  @doc """
  Get HTML content that would be extracted from different job board screenshots.
  """
  def get_screenshot_content(scenario) do
    case scenario do
      :linkedin -> linkedin_job_posting()
      :indeed -> indeed_job_posting()
      :glassdoor -> glassdoor_job_posting()
      :generic -> generic_job_posting()
      :minimal -> minimal_job_posting()
      _ -> generic_job_posting()
    end
  end

  # Private helper functions

  # Generate minimal PNG image data for testing
  # This is a 1x1 pixel transparent PNG
  defp generate_image_data(_scenario) do
    # Minimal valid PNG (1x1 pixel, transparent)
    # PNG signature + IHDR chunk + IDAT chunk + IEND chunk
    <<137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1,
      8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 10, 73, 68, 65, 84, 120, 156, 99, 0, 1, 0,
      0, 5, 0, 1, 13, 10, 45, 180, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130>>
  end

  defp linkedin_job_posting do
    """
    LinkedIn Job Posting

    Senior Software Engineer

    Company: Tech Innovations Inc
    Location: San Francisco, CA (On-site)

    Job Type: Full-time
    Experience Level: Senior level

    About the job:
    We are seeking an experienced Senior Software Engineer to lead the development of our
    next-generation platform. You will work with cutting-edge technologies and mentor junior
    engineers while architecting scalable solutions.

    Responsibilities:
    • Design and implement scalable backend services
    • Lead code reviews and technical discussions
    • Mentor junior engineers
    • Collaborate with product and design teams

    Required skills:
    • 8+ years of software engineering experience
    • Proficiency in one of: Java, Go, Rust, or Python
    • Experience with distributed systems
    • Strong system design skills
    • Excellent communication abilities

    Preferred qualifications:
    • Experience with microservices architecture
    • Cloud platform experience (AWS, GCP, Azure)
    • Open source contributions

    Compensation: $150,000 - $200,000 per year
    Benefits: Health insurance, 401k, equity, remote work options

    Apply now
    """
  end

  defp indeed_job_posting do
    """
    Indeed Job Posting

    Backend Engineer - Python

    Dream Tech Company
    Austin, TX 78701 (Remote)

    $120,000 - $150,000 a year
    Full-time

    Job description:
    Dream Tech Company is hiring a Backend Engineer to join our growing engineering team.
    This is an excellent opportunity to work on challenging problems in the machine learning space.

    What you'll do:
    - Build and maintain Python-based backend services
    - Optimize database queries and system performance
    - Develop APIs for ML model serving
    - Contribute to system design and architecture

    What we're looking for:
    - 5-8 years of backend development experience
    - Strong Python skills
    - Experience with REST APIs
    - Knowledge of SQL databases
    - Problem-solving mindset

    Nice to have:
    - ML/Data pipeline experience
    - Docker/Kubernetes
    - AWS experience
    - Elasticsearch knowledge

    About us:
    Dream Tech Company is an AI-focused startup building tools for enterprise customers.

    Apply
    """
  end

  defp glassdoor_job_posting do
    """
    Glassdoor Job Posting

    Full Stack Software Engineer
    InnovateTech Solutions
    New York, NY

    Job Type: Full-time
    Experience Level: 3-5 years

    Job Description:
    InnovateTech Solutions is looking for a Full Stack Software Engineer to contribute to
    our web platform. You'll work on both frontend React components and backend services.

    Day-to-day:
    • Develop new features for our web application
    • Fix bugs and improve performance
    • Participate in code reviews
    • Collaborate with design and product teams
    • Write unit and integration tests

    You have:
    • 3-5 years of full-stack development experience
    • Proficiency in JavaScript/TypeScript
    • Experience with React and Node.js
    • SQL database knowledge
    • Git version control

    Nice to have:
    • GraphQL experience
    • CI/CD pipeline knowledge
    • Docker containerization
    • Agile development experience

    Salary: $110,000 - $140,000
    Benefits: Health insurance, 401k match, paid time off, professional development budget

    Apply Now
    """
  end

  defp generic_job_posting do
    """
    Software Engineer - Backend Services

    Company: Global Tech Solutions
    Location: Remote

    Position: Full-time Software Engineer
    Experience Required: 5+ years

    About the Role:
    We are seeking a talented Backend Software Engineer to help build our next-generation
    platform. You will have the opportunity to work on high-impact projects and collaborate
    with a diverse team of engineers, product managers, and designers.

    Responsibilities:
    - Develop and maintain backend services in your language of choice
    - Collaborate with frontend engineers and product managers
    - Design scalable solutions for complex problems
    - Participate in code reviews and knowledge sharing
    - Optimize application performance

    Requirements:
    - 5+ years of professional software development experience
    - Strong programming skills (Java, Python, Go, or similar)
    - Understanding of software architecture principles
    - Experience with relational or NoSQL databases
    - Git proficiency
    - Good communication skills

    Preferred:
    - Cloud platform experience (AWS, GCP, Azure)
    - Microservices architecture experience
    - Docker/Kubernetes knowledge
    - Open source contributions

    Compensation & Benefits:
    - Competitive salary: $130,000 - $170,000 per year
    - Comprehensive health insurance
    - 401(k) matching
    - Stock options
    - Flexible work schedule
    - Professional development allowance

    How to Apply:
    Submit your resume and cover letter through this portal.
    """
  end

  defp minimal_job_posting do
    """
    QA Engineer

    Company: TestCo
    Location: Boston, MA

    We're hiring a QA Engineer. Must have 2+ years experience testing web applications.

    Responsibilities:
    - Write test cases
    - Execute tests
    - Report bugs

    Requirements:
    - 2+ years QA experience
    - Knowledge of Selenium or similar tools
    - Attention to detail

    Salary: $70,000 - $85,000
    """
  end
end
