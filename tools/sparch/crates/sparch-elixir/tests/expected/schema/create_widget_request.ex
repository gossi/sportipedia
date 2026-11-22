defmodule SportipediaWeb.Catalog.Equipment.Widget.Schemas.CreateWidgetRequest do
@moduledoc """
OpenAPI schema for documenting the create-widget request parameters.
"""
require OpenApiSpex
@doc """
Returns the OpenAPI schema for the create-widget request.
"""
OpenApiSpex.schema(%{
  title: "equipment.CreateWidgetRequest",
  type: :object,
  properties: %{
    data: %OpenApiSpex.Schema{type: :object, properties: %{
      type: %OpenApiSpex.Schema{type: :string, description: "The resource type"},
      id: %OpenApiSpex.Schema{type: :string, nullable: true, description: "The id of the resource to update"},
      attributes: %OpenApiSpex.Schema{type: :object, properties: %{
            title: %OpenApiSpex.Schema{type: :string, description: "Name of the widget"},
            slug: %OpenApiSpex.Schema{type: :string, description: "URL-friendly unique identifier"},
            coach_id: %OpenApiSpex.Schema{type: :string, nullable: true, description: "Owning coach (optional, mutually exclusive with team_id)"},
            description: %OpenApiSpex.Schema{type: :string, nullable: true, description: "Optional description"},
            label: %OpenApiSpex.Schema{type: :string, nullable: true, description: "Short label shown in lists"},
            team_id: %OpenApiSpex.Schema{type: :string, nullable: true, description: "Owning team (optional, mutually exclusive with coach_id)"}
          },
            required: [:title, :slug]}
    }, required: [:type, :attributes]}
  },
  required: [:data]
})
end
