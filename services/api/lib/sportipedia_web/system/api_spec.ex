defmodule SportipediaWeb.System.ApiSpec do
  alias OpenApiSpex.Reference
  alias OpenApiSpex.JsonErrorResponse
  alias OpenApiSpex.Response
  alias OpenApiSpex.MediaType
  alias OpenApiSpex.SecurityScheme
  alias OpenApiSpex.{Components, Info, OpenApi, Paths, Server}
  alias SportipediaWeb.{Endpoint, Router}

  @behaviour OpenApi

  @impl OpenApi
  def spec do
    %OpenApi{
      servers: [
        # Populate the Server info from a phoenix endpoint
        Server.from_endpoint(Endpoint)
      ],
      info: %Info{
        title: "Sportipedia",
        version: "1.0"
      },
      components: %Components{
        securitySchemes: %{
          "authorization" => %SecurityScheme{type: "http", scheme: "bearer"}
        },
        schemas: %{
          ErrorResponse: JsonErrorResponse.schema()
        },
        responses: [
          not_found: %Response{
            description: "Resource not found",
            content: %{
              "application/vnd.api+json" => %MediaType{
                schema: %Reference{"$ref": "#/components/schemas/ErrorResponse"}
              }
            }
          },
          unauthorized: %Response{
            description: "Authentication required or token is invalid/expired",
            content: %{
              "application/vnd.api+json" => %MediaType{
                schema: %Reference{"$ref": "#/components/schemas/ErrorResponse"}
              }
            }
          },
          bad_request: %Response{
            description: "Bad request",
            content: %{
              "application/vnd.api+json" => %MediaType{
                schema: %Reference{"$ref": "#/components/schemas/ErrorResponse"}
              }
            }
          },
          unprocessable_entity: %Response{
            description: "Unprocessable Entity - Validation failed",
            content: %{
              "application/vnd.api+json" => %MediaType{
                schema: %Reference{"$ref": "#/components/schemas/ErrorResponse"}
              }
            }
          },
          forbidden: %Response{
            description: "Forbidden - Insufficient permissions",
            content: %{
              "application/vnd.api+json" => %MediaType{
                schema: %Reference{"$ref": "#/components/schemas/ErrorResponse"}
              }
            }
          }
        ]
      },
      # Populate the paths from a phoenix router
      paths: Paths.from_router(Router)
    }
    # Discover request/response schemas from path specs
    |> OpenApiSpex.resolve_schema_modules()
  end
end
