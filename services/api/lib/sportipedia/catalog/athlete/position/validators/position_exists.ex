defmodule Sportipedia.Catalog.Athlete.Position.Validators.PositionExists do
  @moduledoc """
  Validates that a position exists.
  """
  use Vex.Validator
  alias Sportipedia.Catalog.Athlete.Position.PositionInternal

  @doc """
  Validates the given id value.
  """
  @spec validate(String.t(), map()) :: :ok | {:error, term()}
  def validate(id, _context) do
    case PositionInternal.position_by_id(id) do
      nil -> {:error, :not_found}
      _ -> :ok
    end
  end
end
