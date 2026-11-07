defmodule Sportipedia.Catalog.Athlete.Position.Queries.ReadPosition do
  @moduledoc """
  Retrieve a single position by its id or slug
  """
  import Ecto.Query

  alias Sportipedia.Catalog.Athlete.Position.PositionReadModel
  alias Sportipedia.Catalog.Athlete.Position.Queries.PositionBySlug
  alias Sportipedia.Support.Validators.UuidValidator

  @doc """
  Creates a query that fetches the single position addressed by an id or a slug:
  the parameter is taken as the position's `id` when it is a UUID and as its
  `slug` otherwise.
  """
  @spec new(String.t()) :: Ecto.Query.t()
  def new(id_or_slug) do
    if UuidValidator.valid_uuid?(id_or_slug) do
      from(r in PositionReadModel, where: r.id == ^id_or_slug)
    else
      id_or_slug |> String.downcase() |> PositionBySlug.new()
    end
  end
end
