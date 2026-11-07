defmodule Sportipedia.Catalog.Athlete.Router do
  use Commanded.Commands.Router
  alias Sportipedia.Catalog.Athlete.Position.Command.ArchivePosition
  alias Sportipedia.Catalog.Athlete.Position.Command.ArchivePositionHandler
  alias Sportipedia.Catalog.Athlete.Position.Command.CatalogPosition
  alias Sportipedia.Catalog.Athlete.Position.Command.CatalogPositionHandler
  alias Sportipedia.Catalog.Athlete.Position.Command.EditPosition
  alias Sportipedia.Catalog.Athlete.Position.Command.EditPositionHandler
  alias Sportipedia.Catalog.Athlete.Position.PositionAggregate
  alias Sportipedia.Support.Commanded.Middleware.Identity
  alias Sportipedia.Support.Commanded.Middleware.Validate
  middleware Identity
  middleware Validate
  identify PositionAggregate, by: :id, prefix: "athlete/position/"
  dispatch CatalogPosition, to: CatalogPositionHandler, aggregate: PositionAggregate
  dispatch EditPosition, to: EditPositionHandler, aggregate: PositionAggregate
  dispatch ArchivePosition, to: ArchivePositionHandler, aggregate: PositionAggregate
end
