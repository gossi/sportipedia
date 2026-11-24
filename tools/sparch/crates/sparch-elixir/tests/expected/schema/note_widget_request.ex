defmodule SportipediaWeb.Catalog.Equipment.Widget.Schemas.NoteWidgetRequest do
@moduledoc """
OpenAPI schema for documenting the note-widget request parameters.
"""
require OpenApiSpex
@doc """
Returns the OpenAPI schema for the note-widget request.
"""
OpenApiSpex.schema(%{
  title: "equipment.NoteWidgetRequest",
  type: :object,
  properties: %{
    data: %OpenApiSpex.Schema{type: :object, properties: %{
      type: %OpenApiSpex.Schema{type: :string, description: "The resource type"},
      id: %OpenApiSpex.Schema{type: :string, nullable: true, description: "The id of the resource to update"},
      attributes: %OpenApiSpex.Schema{type: :object, properties: %{
            comment: %OpenApiSpex.Schema{type: :string, description: "What was observed"}
          },
            required: [:comment]}
    }, required: [:type, :attributes]}
  },
  required: [:data]
})
end
