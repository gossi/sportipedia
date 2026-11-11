defmodule Sportipedia.Catalog.Athlete.Position.Queries.ReadPosition do
  @moduledoc """
  Retrieve a single position by its id or slug
  """
  import Ecto.Query

  alias Sportipedia.Catalog.Athlete.Position.PositionReadModel
  alias Sportipedia.Support.Validators.UuidValidator

  @doc """
  Creates a new query to fetch positions.
  """
  @spec new(String.t()) :: Ecto.Query.t()
  def new(id_or_slug) do
    lookup_field = if UuidValidator.valid_uuid?(id_or_slug), do: :id, else: :slug

    from(position in PositionReadModel, where: field(position, ^lookup_field) == ^id_or_slug)
  end
end
