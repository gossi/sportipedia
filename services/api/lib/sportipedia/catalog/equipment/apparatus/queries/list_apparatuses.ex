defmodule Sportipedia.Catalog.Equipment.Apparatus.Queries.ListApparatuses do
  import Ecto.Query

  alias Sportipedia.Support.JSONAPI.QueryBuilder
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel

  def new(%JSONAPI.Config{} = config) do
    QueryBuilder.build(config, ApparatusReadModel)
  end

  def new(_params) do
    from(a in ApparatusReadModel, order_by: a.title)
  end
end
