defmodule Sportipedia.TestSupport.Catalog.Athlete do
  @moduledoc """
  Test-support factories for the athlete composite — they turn
  fixtures (or plain attribute maps) into persisted read models.
  Generated `new_*` units append per read model; the file is a ledger.
  """
  alias Sportipedia.Catalog.Athlete.Position.PositionReadModel
  alias Sportipedia.Catalog.Repo

  @spec new_position(PositionReadModel.t() | map()) ::
          {:ok, PositionReadModel.t()} | {:error, Ecto.Changeset.t()}
  def new_position(%PositionReadModel{} = fixture) do
    new_position(Map.from_struct(fixture))
  end

  def new_position(attributes) when is_map(attributes) do
    %PositionReadModel{}
    |> PositionReadModel.insert_changeset(attributes)
    |> Repo.insert()
  end

  @spec new_positions([PositionReadModel.t() | map()]) :: [PositionReadModel.t()]
  def new_positions(attribute_collection) do
    Enum.map(attribute_collection, fn attributes ->
      case new_position(attributes) do
        {:ok, position} ->
          position

        {:error, changeset} ->
          raise "seeding position fixture failed: #{inspect(changeset.errors)}"
      end
    end)
  end
end
