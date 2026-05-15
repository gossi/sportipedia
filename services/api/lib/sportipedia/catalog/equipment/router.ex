defmodule Sportipedia.Catalog.Equipment.Router do
  alias Sportipedia.Support.Commanded.Middleware.Identity
  alias Sportipedia.Support.Commanded.Middleware.Validate
  alias Sportipedia.Catalog.Equipment.Instruments.Aggregate.Instrument
  alias Sportipedia.Catalog.Equipment.Instruments.Command.CatalogInstrumentHandler
  alias Sportipedia.Catalog.Equipment.Instruments.Command.CatalogInstrument
  alias Sportipedia.Catalog.Equipment.Instruments.Command.ArchiveInstrumentHandler
  alias Sportipedia.Catalog.Equipment.Instruments.Command.ArchiveInstrument
  alias Sportipedia.Catalog.Equipment.Instruments.Command.EditInstrumentHandler
  alias Sportipedia.Catalog.Equipment.Instruments.Command.EditInstrument

  use Commanded.Commands.Router

  middleware Identity
  middleware Validate

  identify Instrument, by: :id, prefix: "equipment/instrument/"
  dispatch CatalogInstrument, to: CatalogInstrumentHandler, aggregate: Instrument
  dispatch EditInstrument, to: EditInstrumentHandler, aggregate: Instrument
  dispatch ArchiveInstrument, to: ArchiveInstrumentHandler, aggregate: Instrument
end
