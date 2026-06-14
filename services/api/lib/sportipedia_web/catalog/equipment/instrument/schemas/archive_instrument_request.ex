defmodule SportipediaWeb.Catalog.Equipment.Instrument.Schemas.ArchiveInstrumentRequest do
  @moduledoc """
  OpenAPI schema for documenting archive-instrument request parameters.
  """

  require OpenApiSpex

  @doc """
  Returns the OpenAPI schema for the archive-instrument request.
  """
  OpenApiSpex.schema(%{
    title: "equipment.ArchiveInstrumentRequest",
    type: :object,
    properties: %{
      id: %OpenApiSpex.Schema{
        type: :string,
        description: "Unique identifier of the instrument to archive"
      }
    },
    required: [:id]
  })
end
