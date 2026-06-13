defmodule Sportipedia.Catalog.Equipment.Apparatus.Validators.ApparatusExists do
  @moduledoc """
  Validates that an apparatus exists.
  """

  use Vex.Validator

  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusInternal

  @doc """
  Validates the given id exists
  """
  @spec validate(String.t(), map()) :: :ok | {:error, String.t()}
  def validate(id, _options) do
    case ApparatusInternal.apparatus_by_id(id) do
      nil -> {:error, :not_found}
      _ -> :ok
    end
  end
end
