defmodule SportipediaWeb.Catalog.Equipment.Widget.Schemas.RelabelWidgetRequest do
@moduledoc """
OpenAPI schema for documenting the relabel-widget request parameters.
"""
require OpenApiSpex
@doc """
Returns the OpenAPI schema for the relabel-widget request.
"""
OpenApiSpex.schema(%{
  title: "equipment.RelabelWidgetRequest",
  type: :object,
  properties: %{
    data: %OpenApiSpex.Schema{type: :object, properties: %{
      type: %OpenApiSpex.Schema{type: :string, description: "The resource type"},
      id: %OpenApiSpex.Schema{type: :string, nullable: true, description: "The id of the resource to update"},
      attributes: %OpenApiSpex.Schema{type: :object, properties: %{
            label: %OpenApiSpex.Schema{type: :string, description: "The new short label"}
          },
            required: [:label]}
    }, required: [:type, :attributes]}
  },
  required: [:data]
})
end
