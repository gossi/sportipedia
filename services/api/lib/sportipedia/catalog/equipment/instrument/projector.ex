defmodule Sportipedia.Catalog.Equipment.Instrument.InstrumentProjector do
  @moduledoc """
  Projects instrument events to the instrument read model.
  """

  use Commanded.Projections.Ecto,
    application: Sportipedia.Catalog,
    repo: Sportipedia.Catalog.Repo,
    name: "equipment.instrument_projection",
    schema_prefix: "catalog",
    consistency: :strong

  alias Sportipedia.Catalog.Equipment.Instrument.Event.InstrumentCataloged
  alias Sportipedia.Catalog.Equipment.Instrument.InstrumentReadModel

  project %InstrumentCataloged{} = event, _metadata, fn multi ->
    multi
    |> Ecto.Multi.insert(
      :instrument_cataloged,
      InstrumentReadModel.insert_changeset(%InstrumentReadModel{}, Map.from_struct(event))
    )
  end
end
