defmodule ClientatsWeb.APIDocsController do
  @moduledoc """
  Controller for serving API documentation.

  Provides:
  - OpenAPI 3.0 JSON specification
  - Interactive Swagger UI
  - ReDoc alternative documentation
  """

  use ClientatsWeb, :controller

  @doc """
  Serve OpenAPI specification as JSON.
  """
  def openapi(conn, _params) do
    spec = ClientatsWeb.OpenAPISpec.spec()

    conn
    |> put_resp_header("content-type", "application/json; charset=utf-8")
    |> json(spec)
  end

  @doc """
  Serve Swagger UI for interactive API exploration.
  """
  def swagger_ui(conn, _params) do
    html = """
    <!DOCTYPE html>
    <html>
      <head>
        <title>ClientATS API Documentation</title>
        <meta charset="utf-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/swagger-ui/4.15.5/swagger-ui.min.css">
        <style>
          html {
            box-sizing: border-box;
            overflow: -moz-scrollbars-vertical;
            overflow-y: scroll;
          }

          *, *:before, *:after {
            box-sizing: inherit;
          }

          body {
            margin: 0;
            background: #fafafa;
            font-family: sans-serif;
          }
        </style>
      </head>

      <body>
        <div id="swagger-ui"></div>

        <script src="https://cdnjs.cloudflare.com/ajax/libs/swagger-ui/4.15.5/swagger-ui.min.js" charset="UTF-8"></script>
        <script src="https://cdnjs.cloudflare.com/ajax/libs/swagger-ui/4.15.5/swagger-ui-bundle.min.js" charset="UTF-8"></script>
        <script src="https://cdnjs.cloudflare.com/ajax/libs/swagger-ui/4.15.5/swagger-ui-standalone-preset.min.js" charset="UTF-8"></script>
        <script>
          window.onload = function() {
            const ui = SwaggerUIBundle({
              url: "/api-docs/openapi.json",
              dom_id: '#swagger-ui',
              deepLinking: true,
              presets: [
                SwaggerUIBundle.presets.apis,
                SwaggerUIStandalonePreset
              ],
              plugins: [
                SwaggerUIBundle.plugins.DownloadUrl
              ],
              layout: "BaseLayout",
              tryItOutEnabled: true,
              requestInterceptor: (request) => {
                // Modify requests if needed (e.g., add auth headers)
                return request;
              },
              responseInterceptor: (response) => {
                // Modify responses if needed
                return response;
              }
            })
            window.ui = ui
          }
        </script>
      </body>
    </html>
    """

    conn
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> send_resp(200, html)
  end

  @doc """
  Serve ReDoc alternative documentation.
  """
  def redoc_ui(conn, _params) do
    html = """
    <!DOCTYPE html>
    <html>
      <head>
        <title>ClientATS API Documentation - ReDoc</title>
        <meta charset="utf-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <link href="https://fonts.googleapis.com/css?family=Montserrat:300,400,700|Roboto:300,400,700" rel="stylesheet">
        <style>
          body {
            margin: 0;
            padding: 0;
          }
        </style>
      </head>
      <body>
        <redoc spec-url='/api-docs/openapi.json'></redoc>
        <script src="https://cdn.jsdelivr.net/npm/redoc@next/bundles/redoc.standalone.js"> </script>
      </body>
    </html>
    """

    conn
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> send_resp(200, html)
  end

  @doc """
  Serve API documentation index page.
  """
  def index(conn, _params) do
    html = """
    <!DOCTYPE html>
    <html>
      <head>
        <title>ClientATS API Documentation</title>
        <meta charset="utf-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
          body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
            line-height: 1.6;
            max-width: 900px;
            margin: 0 auto;
            padding: 20px;
            background: #f5f5f5;
          }

          .container {
            background: white;
            border-radius: 8px;
            padding: 40px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
          }

          h1 {
            color: #333;
            border-bottom: 2px solid #007bff;
            padding-bottom: 10px;
          }

          h2 {
            color: #555;
            margin-top: 30px;
          }

          .doc-link {
            display: inline-block;
            padding: 12px 24px;
            margin: 10px 10px 10px 0;
            background: #007bff;
            color: white;
            text-decoration: none;
            border-radius: 4px;
            transition: background 0.3s;
          }

          .doc-link:hover {
            background: #0056b3;
          }

          .doc-link.alt {
            background: #6c757d;
          }

          .doc-link.alt:hover {
            background: #5a6268;
          }

          .info-box {
            background: #e7f3ff;
            border-left: 4px solid #007bff;
            padding: 15px;
            margin: 20px 0;
            border-radius: 4px;
          }

          code {
            background: #f4f4f4;
            padding: 2px 6px;
            border-radius: 3px;
            font-family: 'Courier New', monospace;
          }

          .endpoint-list {
            background: #f9f9f9;
            padding: 20px;
            border-radius: 4px;
            border: 1px solid #ddd;
          }

          .endpoint {
            margin: 15px 0;
            padding: 15px;
            background: white;
            border-left: 4px solid #007bff;
            border-radius: 4px;
          }

          .endpoint-method {
            display: inline-block;
            padding: 4px 8px;
            border-radius: 3px;
            font-weight: bold;
            font-size: 12px;
            margin-right: 10px;
          }

          .method-post { background: #ff9800; color: white; }
          .method-get { background: #2196f3; color: white; }
          .method-put { background: #ff5722; color: white; }
          .method-delete { background: #f44336; color: white; }

          .endpoint-path {
            font-family: 'Courier New', monospace;
            color: #333;
          }

          footer {
            text-align: center;
            margin-top: 40px;
            padding-top: 20px;
            border-top: 1px solid #ddd;
            color: #666;
            font-size: 12px;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <h1>📚 ClientATS API Documentation</h1>

          <div class="info-box">
            <strong>Welcome to the ClientATS API!</strong>
            <p>
              ClientATS provides a comprehensive REST API for job application tracking and management.
              Use the interactive documentation below to explore all available endpoints.
            </p>
          </div>

          <h2>📖 Documentation Viewers</h2>

          <p>Choose your preferred documentation format:</p>

          <div>
            <a href="/api-docs/swagger-ui" class="doc-link">
              🎯 Swagger UI (Interactive)
            </a>
            <a href="/api-docs/redoc" class="doc-link alt">
              📋 ReDoc (Alternative View)
            </a>
            <a href="/api-docs/openapi.json" class="doc-link alt">
              {} OpenAPI Spec (JSON)
            </a>
          </div>

          <h2>🚀 Quick Start</h2>

          <h3>Authentication</h3>
          <p>All API requests require authentication. Include your token in the Authorization header:</p>
          <code>Authorization: Bearer YOUR_AUTH_TOKEN</code>

          <h3>Base URL</h3>
          <p>API endpoints are available at:</p>
          <code>https://api.clientats.example.com/api/v1</code>

          <h3>Example Request</h3>
          <p>Extract job data from a URL:</p>
          <pre><code>curl -X POST https://api.clientats.example.com/api/v1/scrape_job \\
  -H "Authorization: Bearer YOUR_TOKEN" \\
  -H "Content-Type: application/json" \\
  -d '{
    "url": "https://linkedin.com/jobs/view/123456",
    "mode": "generic",
    "save": false
  }'</code></pre>

          <h2>📡 Available Endpoints</h2>

          <div class="endpoint-list">
            <div class="endpoint">
              <span class="endpoint-method method-post">POST</span>
              <span class="endpoint-path">/scrape_job</span>
              <p>Extract job data from a URL using AI/LLM services</p>
            </div>

            <div class="endpoint">
              <span class="endpoint-method method-get">GET</span>
              <span class="endpoint-path">/llm/providers</span>
              <p>Get list of available LLM providers and their status</p>
            </div>

            <div class="endpoint">
              <span class="endpoint-method method-get">GET</span>
              <span class="endpoint-path">/llm/config</span>
              <p>Get your LLM configuration</p>
            </div>
          </div>

          <h2>ℹ️ API Information</h2>

          <h3>Versioning</h3>
          <ul>
            <li><strong>Current Version:</strong> v1</li>
            <li><strong>Status:</strong> Stable</li>
            <li><strong>Supported Versions:</strong> v1, v2-beta</li>
          </ul>

          <h3>Response Format</h3>
          <p>All responses are in JSON format with the following structure:</p>
          <pre><code>{
  "success": true,
  "data": { /* Response data */ },
  "message": "Human-readable message",
  "_api": {
    "version": "1.0.0",
    "supported_versions": ["1.0.0", "2.0.0-beta"]
  }
}</code></pre>

          <h3>Error Handling</h3>
          <p>Errors include appropriate HTTP status codes and detailed error messages:</p>
          <ul>
            <li><strong>400</strong> - Bad Request</li>
            <li><strong>401</strong> - Unauthorized</li>
            <li><strong>429</strong> - Rate Limited</li>
            <li><strong>500</strong> - Server Error</li>
          </ul>

          <h2>🔐 Security</h2>

          <ul>
            <li>All endpoints require authentication</li>
            <li>Use HTTPS only in production</li>
            <li>Never expose your authentication tokens</li>
            <li>Rate limiting is in effect to protect service stability</li>
          </ul>

          <h2>💬 Support</h2>

          <p>For questions or issues with the API, please contact support:</p>
          <ul>
            <li>Email: support@clientats.example.com</li>
            <li>Documentation: https://docs.clientats.example.com</li>
          </ul>

          <footer>
            <p>ClientATS API v1.0.0 | Last Updated: December 2025</p>
          </footer>
        </div>
      </body>
    </html>
    """

    conn
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> send_resp(200, html)
  end
end
