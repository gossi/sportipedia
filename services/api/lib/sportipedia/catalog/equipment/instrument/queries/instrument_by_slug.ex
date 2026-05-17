defmodule Sportipedia.Catalog.Equipment.Instrument.Queries.InstrumentBySlug do
  alias Sportipedia.Catalog.Equipment.Instrument.InstrumentReadModel
  import Ecto.Query

  def new(slug) do
    from(i in InstrumentReadModel,
      where: i.slug == ^slug
    )
  end
end
