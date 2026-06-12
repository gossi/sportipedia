defmodule Sportipedia.Catalog.Equipment.Apparatus.Validators.UniqueSlug do
  @moduledoc """
  Validates that an apparatus slug is unique within the catalog.
  """

  use Vex.Validator

  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusInternal

  @doc """
  Validates the given slug value for uniqueness.
  """
  @spec validate(String.t(), map()) :: :ok | {:error, String.t()}
  def validate(value, _context) do
    case slug_exists?(value) do
      true -> {:error, "slug already exists"}
      false -> :ok
    end
  end

  defp slug_exists?(slug) do
    case ApparatusInternal.apparatus_by_slug(slug) do
      nil -> false
      _ -> true
    end
  end
end
