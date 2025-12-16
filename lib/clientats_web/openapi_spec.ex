defmodule ClientatsWeb.OpenAPISpec do
  @moduledoc """
  OpenAPI 3.0 specification generator for ClientATS API.

  Generates comprehensive API documentation including:
  - All endpoint definitions
  - Request/response schemas
  - Authentication requirements
  - Error responses
  - Example requests and responses
  """

  def spec do
    %{
      "openapi" => "3.0.0",
      "info" => %{
        "title" => "ClientATS API",
        "description" => """
        ClientATS - Comprehensive job application tracking and management system.

        The ClientATS API provides endpoints for:
        - Extracting job data from URLs using AI/LLM services
        - Managing LLM provider configurations
        - Job interest and application tracking

        ## Authentication
        All API endpoints require authentication. Include your authentication token in the Authorization header:
        ```
        Authorization: Bearer YOUR_AUTH_TOKEN
        ```

        ## Versioning
        The API is versioned using URL prefixes. Current version: v1
        - `/api/v1` - Current stable version
        - `/api/v2` - Beta features (coming soon)
        - `/api` - Legacy endpoint (redirects to v1)

        ## Rate Limiting
        API requests are rate limited to protect service stability.
        Rate limit headers are included in all responses.

        ## Error Handling
        All errors follow a consistent JSON format with status codes and error messages.
        """,
        "version" => "1.0.0",
        "contact" => %{
          "name" => "ClientATS Support",
          "email" => "support@clientats.example.com"
        },
        "license" => %{
          "name" => "MIT"
        }
      },
      "servers" => [
        %{
          "url" => "http://localhost:4000/api/v1",
          "description" => "Development server"
        },
        %{
          "url" => "https://api.clientats.example.com/api/v1",
          "description" => "Production server"
        }
      ],
      "paths" => paths(),
      "components" => components(),
      "tags" => tags(),
      "externalDocs" => %{
        "description" => "ClientATS Documentation",
        "url" => "https://docs.clientats.example.com"
      }
    }
  end

  defp paths do
    %{
      "/scrape_job" => %{
        "post" => %{
          "summary" => "Scrape job data from URL",
          "description" => """
          Extract structured job information from a job posting URL using AI/LLM services.

          Supports multiple extraction modes and LLM providers for flexibility.
          """,
          "operationId" => "scrapeJob",
          "tags" => ["Job Scraping"],
          "requestBody" => %{
            "required" => true,
            "content" => %{
              "application/json" => %{
                "schema" => %{"$ref" => "#/components/schemas/ScrapeJobRequest"},
                "examples" => %{
                  "basic" => %{
                    "summary" => "Basic job scraping",
                    "value" => %{
                      "url" => "https://linkedin.com/jobs/view/123456",
                      "mode" => "generic"
                    }
                  },
                  "advanced" => %{
                    "summary" => "Advanced with specific provider",
                    "value" => %{
                      "url" => "https://indeed.com/viewjob?jk=abc123",
                      "mode" => "specific",
                      "provider" => "openai",
                      "save" => true
                    }
                  }
                }
              }
            }
          },
          "responses" => %{
            "200" => %{
              "description" => "Job data successfully extracted",
              "content" => %{
                "application/json" => %{
                  "schema" => %{"$ref" => "#/components/schemas/ScrapeJobResponse"},
                  "examples" => %{
                    "success" => %{
                      "summary" => "Successful extraction",
                      "value" => %{
                        "success" => true,
                        "data" => %{
                          "company_name" => "Acme Corp",
                          "position_title" => "Senior Software Engineer",
                          "location" => "San Francisco, CA",
                          "salary_min" => 150_000,
                          "salary_max" => 200_000,
                          "job_description" => "We are looking for...",
                          "work_model" => "hybrid",
                          "extracted_at" => "2025-12-16T12:00:00Z"
                        },
                        "message" => "Job data extracted successfully",
                        "_api" => %{
                          "version" => "1.0.0",
                          "supported_versions" => ["1.0.0", "2.0.0-beta"]
                        }
                      }
                    }
                  }
                }
              }
            },
            "400" => %{
              "description" => "Invalid request or extraction failed",
              "content" => %{
                "application/json" => %{
                  "schema" => %{"$ref" => "#/components/schemas/ErrorResponse"}
                }
              }
            },
            "401" => %{
              "description" => "Authentication required",
              "content" => %{
                "application/json" => %{
                  "schema" => %{"$ref" => "#/components/schemas/ErrorResponse"}
                }
              }
            },
            "429" => %{
              "description" => "Rate limit exceeded",
              "content" => %{
                "application/json" => %{
                  "schema" => %{"$ref" => "#/components/schemas/ErrorResponse"}
                }
              }
            },
            "500" => %{
              "description" => "Server error",
              "content" => %{
                "application/json" => %{
                  "schema" => %{"$ref" => "#/components/schemas/ErrorResponse"}
                }
              }
            }
          },
          "security" => [%{"BearerAuth" => []}]
        }
      },
      "/llm/providers" => %{
        "get" => %{
          "summary" => "Get available LLM providers",
          "description" => """
          Retrieve list of available LLM providers and their current status.

          Returns provider names, capabilities, and availability status.
          """,
          "operationId" => "getProviders",
          "tags" => ["LLM Configuration"],
          "parameters" => [
            %{
              "name" => "include_status",
              "in" => "query",
              "description" => "Include provider status",
              "required" => false,
              "schema" => %{
                "type" => "boolean",
                "default" => true
              }
            }
          ],
          "responses" => %{
            "200" => %{
              "description" => "List of available providers",
              "content" => %{
                "application/json" => %{
                  "schema" => %{"$ref" => "#/components/schemas/ProvidersResponse"},
                  "examples" => %{
                    "success" => %{
                      "summary" => "Available providers",
                      "value" => %{
                        "success" => true,
                        "data" => %{
                          "providers" => [
                            %{
                              "name" => "openai",
                              "available" => true,
                              "capabilities" => ["text", "vision"],
                              "models" => ["gpt-4", "gpt-3.5-turbo"]
                            },
                            %{
                              "name" => "ollama",
                              "available" => true,
                              "capabilities" => ["text"],
                              "models" => ["llama2", "mistral"]
                            }
                          ]
                        }
                      }
                    }
                  }
                }
              }
            },
            "401" => %{
              "description" => "Authentication required",
              "content" => %{
                "application/json" => %{
                  "schema" => %{"$ref" => "#/components/schemas/ErrorResponse"}
                }
              }
            }
          },
          "security" => [%{"BearerAuth" => []}]
        }
      },
      "/llm/config" => %{
        "get" => %{
          "summary" => "Get LLM configuration",
          "description" => """
          Retrieve current LLM provider configuration for the authenticated user.

          Shows all configured providers, API keys (masked), and status.
          """,
          "operationId" => "getConfig",
          "tags" => ["LLM Configuration"],
          "responses" => %{
            "200" => %{
              "description" => "LLM configuration",
              "content" => %{
                "application/json" => %{
                  "schema" => %{"$ref" => "#/components/schemas/ConfigResponse"}
                }
              }
            },
            "401" => %{
              "description" => "Authentication required",
              "content" => %{
                "application/json" => %{
                  "schema" => %{"$ref" => "#/components/schemas/ErrorResponse"}
                }
              }
            }
          },
          "security" => [%{"BearerAuth" => []}]
        }
      }
    }
  end

  defp components do
    %{
      "schemas" => %{
        "ScrapeJobRequest" => %{
          "type" => "object",
          "required" => ["url"],
          "properties" => %{
            "url" => %{
              "type" => "string",
              "format" => "uri",
              "description" => "Job posting URL to scrape",
              "example" => "https://linkedin.com/jobs/view/123456"
            },
            "mode" => %{
              "type" => "string",
              "enum" => ["specific", "generic"],
              "default" => "generic",
              "description" => "Extraction mode - specific for known job boards, generic for any content"
            },
            "provider" => %{
              "type" => "string",
              "enum" => ["openai", "anthropic", "mistral", "ollama", "google"],
              "description" => "LLM provider to use (uses default if not specified)"
            },
            "save" => %{
              "type" => "boolean",
              "default" => false,
              "description" => "Automatically save extracted data as job interest"
            }
          }
        },
        "ScrapeJobResponse" => %{
          "type" => "object",
          "properties" => %{
            "success" => %{
              "type" => "boolean",
              "description" => "Request success status"
            },
            "data" => %{
              "type" => "object",
              "properties" => %{
                "company_name" => %{"type" => "string"},
                "position_title" => %{"type" => "string"},
                "location" => %{"type" => "string"},
                "work_model" => %{"type" => "string", "enum" => ["remote", "hybrid", "on-site"]},
                "salary_min" => %{"type" => "integer"},
                "salary_max" => %{"type" => "integer"},
                "job_description" => %{"type" => "string"},
                "extracted_at" => %{"type" => "string", "format" => "date-time"}
              }
            },
            "message" => %{
              "type" => "string"
            },
            "_api" => %{
              "type" => "object",
              "properties" => %{
                "version" => %{"type" => "string"},
                "supported_versions" => %{"type" => "array", "items" => %{"type" => "string"}}
              }
            }
          }
        },
        "ProvidersResponse" => %{
          "type" => "object",
          "properties" => %{
            "success" => %{"type" => "boolean"},
            "data" => %{
              "type" => "object",
              "properties" => %{
                "providers" => %{
                  "type" => "array",
                  "items" => %{"$ref" => "#/components/schemas/Provider"}
                }
              }
            }
          }
        },
        "Provider" => %{
          "type" => "object",
          "properties" => %{
            "name" => %{"type" => "string"},
            "available" => %{"type" => "boolean"},
            "capabilities" => %{
              "type" => "array",
              "items" => %{"type" => "string"},
              "example" => ["text", "vision"]
            },
            "models" => %{
              "type" => "array",
              "items" => %{"type" => "string"}
            },
            "status" => %{
              "type" => "string",
              "enum" => ["connected", "configured", "unconfigured", "error"]
            }
          }
        },
        "ConfigResponse" => %{
          "type" => "object",
          "properties" => %{
            "success" => %{"type" => "boolean"},
            "data" => %{
              "type" => "object",
              "properties" => %{
                "providers" => %{
                  "type" => "array",
                  "items" => %{
                    "type" => "object",
                    "properties" => %{
                      "provider" => %{"type" => "string"},
                      "enabled" => %{"type" => "boolean"},
                      "status" => %{"type" => "string"},
                      "model" => %{"type" => "string"}
                    }
                  }
                }
              }
            }
          }
        },
        "ErrorResponse" => %{
          "type" => "object",
          "properties" => %{
            "success" => %{
              "type" => "boolean",
              "example" => false
            },
            "error" => %{
              "type" => "string",
              "description" => "Error code/type"
            },
            "message" => %{
              "type" => "string",
              "description" => "Human-readable error message"
            },
            "details" => %{
              "type" => "object",
              "description" => "Additional error details"
            }
          }
        }
      },
      "securitySchemes" => %{
        "BearerAuth" => %{
          "type" => "http",
          "scheme" => "bearer",
          "bearerFormat" => "JWT",
          "description" => "Enter your authentication token"
        }
      }
    }
  end

  defp tags do
    [
      %{
        "name" => "Job Scraping",
        "description" => "Job data extraction from URLs using LLM services"
      },
      %{
        "name" => "LLM Configuration",
        "description" => "LLM provider management and configuration"
      }
    ]
  end
end
