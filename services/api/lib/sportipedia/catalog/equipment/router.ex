defmodule Sportipedia.Catalog.Equipment.Router do
  alias Sportipedia.Support.Commanded.Middleware.Identity
  alias Sportipedia.Support.Commanded.Middleware.Validate
  alias Sportipedia.Catalog.Equipment.Instruments.InstrumentAggregate
  alias Sportipedia.Catalog.Equipment.Instruments.Command.CatalogInstrumentHandler
  alias Sportipedia.Catalog.Equipment.Instruments.Command.CatalogInstrument
  alias Sportipedia.Catalog.Equipment.Instruments.Command.ArchiveInstrumentHandler
  alias Sportipedia.Catalog.Equipment.Instruments.Command.ArchiveInstrument
  alias Sportipedia.Catalog.Equipment.Instruments.Command.EditInstrumentHandler
  alias Sportipedia.Catalog.Equipment.Instruments.Command.EditInstrument

  use Commanded.Commands.Router

  middleware Identity
  middleware Validate

  identify InstrumentAggregate, by: :id, prefix: "equipment/instrument/"
  dispatch CatalogInstrument, to: CatalogInstrumentHandler, aggregate: InstrumentAggregate
  dispatch EditInstrument, to: EditInstrumentHandler, aggregate: InstrumentAggregate
  dispatch ArchiveInstrument, to: ArchiveInstrumentHandler, aggregate: InstrumentAggregate
end
