defmodule Sportipedia.Catalog.Athlete.Position.Queries.ReadPosition do
  @moduledoc """
  Retrieve a single position by its id or slug
  """
  import Ecto.Query
  alias Sportipedia.Catalog.Athlete.Position.PositionReadModel
  alias Sportipedia.Support.Validators.UuidValidator

  @doc """
  Creates a new query to fetch positions.

  The parameter is the position's `id` when it is a UUID and its `slug`
  otherwise, so the branch is what keeps a slug out of the uuid column: Postgres
  rejects a non-uuid literal for `id` instead of answering not-found.
  """
  @spec new(String.t()) :: Ecto.Query.t()
  def new(id_or_slug) do
    if UuidValidator.valid_uuid?(id_or_slug) do
      from(r in PositionReadModel, where: r.id == ^id_or_slug)
    else
      # The slug's canonical form is lowercase, so the read meets the stored
      # value by lowering what the caller gave it — the accessor contract in
      # blueprints/backend/domain/examples/unique-slug.md. Nothing else on the
      # read path is normalised.
      slug = String.downcase(id_or_slug)

      from(r in PositionReadModel, where: r.slug == ^slug)
    end
  end
end
