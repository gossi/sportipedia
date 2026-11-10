defmodule Sportipedia.TestSupport.Catalog.Equipment do
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel
  alias Sportipedia.Catalog.Repo
  alias Sportipedia.Catalog.Equipment.Instrument.InstrumentReadModel

  @spec new_instrument(InstrumentReadModel.t()) ::
          {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
  def new_instrument(attributes) do
    InstrumentReadModel.insert_changeset(%InstrumentReadModel{}, attributes)
    |> Repo.insert()
  end

  def new_instruments(attribute_collection) do
    Enum.each(attribute_collection, fn elem -> new_instrument(elem) end)
  end

  @spec new_apparatus(ApparatusReadModel.t()) ::
          {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
  def new_apparatus(attributes) do
    ApparatusReadModel.insert_changeset(%ApparatusReadModel{}, attributes)
    |> Repo.insert()
  end

  def new_apparatuses(attribute_collection) do
    Enum.each(attribute_collection, fn elem -> new_apparatus(elem) end)
  end
end
