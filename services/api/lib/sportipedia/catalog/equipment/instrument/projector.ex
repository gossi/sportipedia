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
  alias Sportipedia.Catalog.Equipment.Instrument.Event.InstrumentEdited
  alias Sportipedia.Catalog.Equipment.Instrument.InstrumentInternal
  alias Sportipedia.Catalog.Equipment.Instrument.InstrumentReadModel

  project %InstrumentCataloged{} = event, _metadata, fn multi ->
    multi
    |> Ecto.Multi.insert(
      :instrument_cataloged,
      InstrumentReadModel.insert_changeset(%InstrumentReadModel{}, Map.from_struct(event))
    )
  end

  project %InstrumentEdited{} = event, _metadata, fn multi ->
    case InstrumentInternal.instrument_by_id(event.id) do
      nil ->
        multi

      %InstrumentReadModel{} = instrument ->
        attrs = InstrumentEdited.get_changes(event)

        multi
        |> Ecto.Multi.update(
          :instrument_edited,
          InstrumentReadModel.update_changeset(instrument, attrs)
        )
    end
  end
end
