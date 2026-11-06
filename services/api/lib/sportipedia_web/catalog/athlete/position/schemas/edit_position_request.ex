defmodule SportipediaWeb.Catalog.Athlete.Position.Schemas.EditPositionRequest do
  @moduledoc """
  OpenAPI schema for documenting the edit-position request parameters.
  """
  require OpenApiSpex

  @doc """
  Returns the OpenAPI schema for the edit-position request.
  """
  OpenApiSpex.schema(%{
    title: "athlete.EditPositionRequest",
    type: :object,
    # The merge rule belongs here, where a client generating code from this
    # document reads it: the fields are marked nullable because a null is
    # accepted, not because a null does anything to the stored value.
    description: """
    Patches an existing position. `id` addresses the position and every other \
    field carries the value it should hold from now on. A field you leave out \
    keeps its stored value — and so does a field you send as `null`: this edit \
    reads an absent value and a null as the same statement, "nothing to change".
    """,
    properties: %{
      id: %OpenApiSpex.Schema{
        type: :string,
        format: "uuid",
        description: "Unique identifier"
      },
      apparatusId: %OpenApiSpex.Schema{
        type: :string,
        format: "uuid",
        nullable: true,
        description: "Reference to apparatus (optional, mutually exclusive with instrumentId)"
      },
      description: %OpenApiSpex.Schema{
        type: :string,
        nullable: true,
        description: "Optional description"
      },
      instrumentId: %OpenApiSpex.Schema{
        type: :string,
        format: "uuid",
        nullable: true,
        description: "Reference to instrument (optional, mutually exclusive with apparatusId)"
      },
      slug: %OpenApiSpex.Schema{
        type: :string,
        nullable: true,
        description: "URL-friendly unique identifier"
      },
      title: %OpenApiSpex.Schema{
        type: :string,
        nullable: true,
        description: "Name of the position"
      }
    },
    required: [:id]
  })
end
