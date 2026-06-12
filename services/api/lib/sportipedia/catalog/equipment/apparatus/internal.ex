defmodule Sportipedia.Catalog.Equipment.Apparatus.ApparatusInternal do
  @moduledoc """
  Internal API for querying apparatus read models within the bounded context.
  """

  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel
  alias Sportipedia.Catalog.Equipment.Apparatus.Queries.ApparatusBySlug
  alias Sportipedia.Catalog.Repo

  import Ecto.Query

  @doc """
  Fetches an apparatus by its ID. Returns nil if not found.
  """
  @spec apparatus_by_id(String.t()) :: ApparatusReadModel.t() | nil
  def apparatus_by_id(id) do
    Repo.get(ApparatusReadModel, id)
  end

  @doc """
  Fetches an apparatus by its ID. Raises if not found.
  """
  @spec apparatus_by_id!(String.t()) :: ApparatusReadModel.t()
  def apparatus_by_id!(id) do
    Repo.get!(ApparatusReadModel, id)
  end

  @doc """
  Fetches an apparatus by its slug. Returns nil if not found.
  """
  @spec apparatus_by_slug(String.t()) :: ApparatusReadModel.t() | nil
  def apparatus_by_slug(slug) do
    slug
    |> String.downcase()
    |> ApparatusBySlug.new()
    |> Repo.one()
  end
end
