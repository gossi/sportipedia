defmodule SportipediaWeb.Catalog.Equipment.Instrument.Schemas.EditInstrumentRequest do
  @moduledoc """
  OpenAPI schema for documenting the edit-instrument request parameters.
  """

  require OpenApiSpex

  @doc """
  Returns the OpenAPI schema for the edit-instrument request.
  """
  OpenApiSpex.schema(%{
    title: "equipment.EditInstrumentRequest",
    type: :object,
    properties: %{
      id: %OpenApiSpex.Schema{type: :string, description: "The instrument ID"},
      title: %OpenApiSpex.Schema{type: :string, description: "Name of the instrument"},
      slug: %OpenApiSpex.Schema{
        type: :string,
        description: "URL-friendly unique identifier"
      },
      description: %OpenApiSpex.Schema{
        type: :string,
        nullable: true,
        description: "Optional description"
      }
    },
    required: [:id]
  })
end
