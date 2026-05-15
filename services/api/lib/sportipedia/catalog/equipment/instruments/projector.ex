defmodule Sportipedia.Catalog.Equipment.Instruments.Projectors.InstrumentProjector do
  alias Sportipedia.Catalog.Equipment.Instruments
  alias Sportipedia.Catalog.Equipment.Instruments.Event.InstrumentArchived
  alias Sportipedia.Catalog.Equipment.Instruments.Event.InstrumentEdited
  alias Sportipedia.Catalog.Equipment.Instruments.Event.InstrumentCataloged
  alias Sportipedia.Catalog.Equipment.Instruments.ReadModel.Instrument

  use Commanded.Projections.Ecto,
    application: Sportipedia.Catalog,
    repo: Sportipedia.Catalog.Repo,
    name: "equipment.instrument_projection",
    schema_prefix: "catalog",
    consistency: :strong

  project %InstrumentCataloged{} = event, _metadata, fn multi ->
    multi
    |> Ecto.Multi.insert(:catalog_instrument, Instrument.insert_changeset(Map.from_struct(event)))
  end

  project %InstrumentEdited{} = event, metadata, fn multi ->
    case Instruments.instrument_by_id(event.id) do
      nil ->
        multi

      %Instrument{} = instrument ->
        attrs = InstrumentEdited.get_changes(event)

        multi
        |> Ecto.Multi.update(:edit_instrument, Instrument.update_changeset(instrument, attrs))
    end
  end

  project %InstrumentArchived{} = event, _metadata, fn multi ->
    case Instruments.instrument_by_id(event.id) do
      nil ->
        multi

      %Instrument{} = instrument ->
        multi
        |> Ecto.Multi.delete(:archive_instrument, instrument)
    end
  end
end
