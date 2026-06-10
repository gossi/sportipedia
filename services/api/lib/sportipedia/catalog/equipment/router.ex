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
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusAggregate
  alias Sportipedia.Catalog.Equipment.Apparatus.Command.CatalogApparatusHandler
  alias Sportipedia.Catalog.Equipment.Apparatus.Command.CatalogApparatus
  alias Sportipedia.Catalog.Equipment.Apparatus.Command.EditApparatusHandler
  alias Sportipedia.Catalog.Equipment.Apparatus.Command.EditApparatus
  alias Sportipedia.Catalog.Equipment.Apparatus.Command.ArchiveApparatusHandler
  alias Sportipedia.Catalog.Equipment.Apparatus.Command.ArchiveApparatus

  use Commanded.Commands.Router

  middleware Identity
  middleware Validate

  identify InstrumentAggregate, by: :id, prefix: "equipment/instrument/"
  dispatch CatalogInstrument, to: CatalogInstrumentHandler, aggregate: InstrumentAggregate
  dispatch EditInstrument, to: EditInstrumentHandler, aggregate: InstrumentAggregate
  dispatch ArchiveInstrument, to: ArchiveInstrumentHandler, aggregate: InstrumentAggregate

  identify ApparatusAggregate, by: :id, prefix: "equipment/apparatus/"
  dispatch CatalogApparatus, to: CatalogApparatusHandler, aggregate: ApparatusAggregate
  dispatch EditApparatus, to: EditApparatusHandler, aggregate: ApparatusAggregate
  dispatch ArchiveApparatus, to: ArchiveApparatusHandler, aggregate: ApparatusAggregate
end
