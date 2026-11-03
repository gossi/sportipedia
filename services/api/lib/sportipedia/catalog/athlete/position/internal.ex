defmodule Sportipedia.Catalog.Athlete.Position.PositionInternal do
  @moduledoc """
  Internal API for querying position read models within the bounded context.
  """
  alias Sportipedia.Catalog.Athlete.Position.PositionReadModel
  alias Sportipedia.Catalog.Athlete.Position.Queries.PositionBySlug
  alias Sportipedia.Catalog.Repo

  @doc """
  Fetches a position by its ID. Returns nil if not found.
  """
  @spec position_by_id(String.t()) :: PositionReadModel.t() | nil
  def position_by_id(id) do
    Repo.get(PositionReadModel, id)
  end

  @doc """
  Fetches a position by its slug. Returns nil if not found.
  """
  @spec position_by_slug(String.t()) :: PositionReadModel.t() | nil
  def position_by_slug(slug) do
    slug
    |> String.downcase()
    |> PositionBySlug.new()
    |> Repo.one()
  end
end
