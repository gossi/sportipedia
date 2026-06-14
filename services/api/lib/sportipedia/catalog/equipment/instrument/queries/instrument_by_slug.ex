defmodule Sportipedia.Catalog.Equipment.Instrument.Queries.InstrumentBySlug do
  @moduledoc """
  Query to fetch an instrument by its slug.
  """

  alias Sportipedia.Catalog.Equipment.Instrument.InstrumentReadModel
  import Ecto.Query

  @doc """
  Creates a new query to fetch an instrument by slug.
  """
  def new(slug) do
    from(r in InstrumentReadModel,
      where: r.slug == ^slug
    )
  end
end
