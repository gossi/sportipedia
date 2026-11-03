defmodule Sportipedia.Catalog.Athlete.Position.Validators.UniqueSlug do
  @moduledoc """
  Validates that a position slug is unique within the athlete.
  """
  use Vex.Validator
  alias Sportipedia.Catalog.Athlete.Position.PositionInternal

  @doc """
  Validates the given slug value.
  """
  @spec validate(String.t(), map()) :: :ok | {:error, term()}
  def validate(value, context) do
    with position <- PositionInternal.position_by_slug(value),
         false <- is_nil(position),
         false <- slug_belongs_to_position?(position, context) do
      {:error, :slug_exists}
    else
      _ -> :ok
    end
  end

  defp slug_belongs_to_position?(position, context) do
    id = Map.get(context, :id)

    id == position.id
  end
end
