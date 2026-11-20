defmodule Sportipedia.Catalog.Equipment.Router do
  alias Sportipedia.Catalog.Equipment.Gadget.GadgetAggregate

  use Commanded.Commands.Router

  middleware Identity
  middleware Validate

  identify GadgetAggregate, by: :id, prefix: "equipment/gadget/"

  dispatch CreateGadget, to: CreateGadgetHandler, aggregate: GadgetAggregate
end
