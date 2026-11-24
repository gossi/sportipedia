defmodule SportipediaWeb.Catalog.Equipment.Widget.Schemas.EditWidgetRequest do
@moduledoc """
OpenAPI schema for documenting the edit-widget request parameters.
"""
require OpenApiSpex
@doc """
Returns the OpenAPI schema for the edit-widget request.
"""
OpenApiSpex.schema(%{
  title: "equipment.EditWidgetRequest",
  type: :object,
  properties: %{
    data: %OpenApiSpex.Schema{type: :object, properties: %{
      type: %OpenApiSpex.Schema{type: :string, description: "The resource type"},
      id: %OpenApiSpex.Schema{type: :string, nullable: true, description: "The id of the resource to update"},
      attributes: %OpenApiSpex.Schema{type: :object, properties: %{
            coach_id: %OpenApiSpex.Schema{type: :string, nullable: true, description: "Owning coach (optional, mutually exclusive with team_id)"},
            description: %OpenApiSpex.Schema{type: :string, nullable: true, description: "Optional description"},
            label: %OpenApiSpex.Schema{type: :string, nullable: true, description: "Short label shown in lists"},
            slug: %OpenApiSpex.Schema{type: :string, nullable: true, description: "URL-friendly unique identifier"},
            team_id: %OpenApiSpex.Schema{type: :string, nullable: true, description: "Owning team (optional, mutually exclusive with coach_id)"},
            title: %OpenApiSpex.Schema{type: :string, nullable: true, description: "Name of the widget"}
          }}
    }, required: [:type, :attributes]}
  },
  required: [:data]
})
end
