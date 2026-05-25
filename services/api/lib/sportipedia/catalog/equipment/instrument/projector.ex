defmodule Sportipedia.Catalog.Equipment.Instrument.InstrumentProjector do
  alias Sportipedia.Catalog.Equipment.Instrument
  alias Sportipedia.Catalog.Equipment.Instrument.Event.InstrumentArchived
  alias Sportipedia.Catalog.Equipment.Instrument.Event.InstrumentEdited
  alias Sportipedia.Catalog.Equipment.Instrument.Event.InstrumentCataloged
  alias Sportipedia.Catalog.Equipment.Instrument.InstrumentReadModel

  use Commanded.Projections.Ecto,
    application: Sportipedia.Catalog,
    repo: Sportipedia.Catalog.Repo,
    name: "equipment.instrument_projection",
    schema_prefix: "catalog",
    consistency: :strong

  project %InstrumentCataloged{} = event, _metadata, fn multi ->
    multi
    |> Ecto.Multi.insert(
      :catalog_instrument,
      InstrumentReadModel.insert_changeset(Map.from_struct(event))
    )
  end

  project %InstrumentEdited{} = event, _metadata, fn multi ->
    case Instrument.instrument_by_id(event.id) do
      nil ->
        multi

      %InstrumentReadModel{} = instrument ->
        attrs = InstrumentEdited.get_changes(event)

        multi
        |> Ecto.Multi.update(
          :edit_instrument,
          InstrumentReadModel.update_changeset(instrument, attrs)
        )
    end
  end

  project %InstrumentArchived{} = event, _metadata, fn multi ->
    case Instrument.instrument_by_id(event.id) do
      nil ->
        multi

      %InstrumentReadModel{} = instrument ->
        multi
        |> Ecto.Multi.delete(:archive_instrument, instrument)
    end
  end
end
