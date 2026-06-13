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
  def validate(value, context) do
    with apparatus <- ApparatusInternal.apparatus_by_slug(value),
         false <- is_nil(apparatus),
         false <- slug_belongs_to_apparatus?(apparatus, context) do
      {:error, :slug_exists}
    else
      _ -> :ok
    end
  end

  defp slug_belongs_to_apparatus?(apparatus, context) do
    id = Map.get(context, :id)

    id == apparatus.id
  end
end
