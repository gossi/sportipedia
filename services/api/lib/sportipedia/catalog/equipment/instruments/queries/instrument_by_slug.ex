defmodule Sportipedia.Catalog.Equipment.Instruments.Queries.InstrumentBySlug do
  alias Sportipedia.Catalog.Equipment.Instruments.InstrumentReadModel
  import Ecto.Query

  def new(slug) do
    from(i in Instrument,
      where: i.slug == ^slug
    )
  end
end
