defmodule Sportipedia.Catalog.Equipment.Router do
  alias Sportipedia.Support.Commanded.Middleware.Identity
  alias Sportipedia.Support.Commanded.Middleware.Validate
  alias Sportipedia.Catalog.Equipment.Instrument.InstrumentAggregate
  alias Sportipedia.Catalog.Equipment.Instrument.Command.CatalogInstrumentHandler
  alias Sportipedia.Catalog.Equipment.Instrument.Command.CatalogInstrument
  alias Sportipedia.Catalog.Equipment.Instrument.Command.ArchiveInstrumentHandler
  alias Sportipedia.Catalog.Equipment.Instrument.Command.ArchiveInstrument
  alias Sportipedia.Catalog.Equipment.Instrument.Command.EditInstrumentHandler
  alias Sportipedia.Catalog.Equipment.Instrument.Command.EditInstrument

  use Commanded.Commands.Router

  middleware Identity
  middleware Validate

  identify InstrumentAggregate, by: :id, prefix: "equipment/instrument/"
  dispatch CatalogInstrument, to: CatalogInstrumentHandler, aggregate: InstrumentAggregate
  dispatch EditInstrument, to: EditInstrumentHandler, aggregate: InstrumentAggregate
  dispatch ArchiveInstrument, to: ArchiveInstrumentHandler, aggregate: InstrumentAggregate
end
