defmodule Sportipedia.Catalog.Athlete.Position.Validators.PositionExists do
  @moduledoc """
  Validates that a position exists.

  The rule is asked of an address: only a value that can denote a
  position is looked up. A malformed id addresses nothing, so no
  position can hold it, and the answer is the one the pattern gives
  for an unknown id. An absent or blank id is not this rule's to answer —
  `presence` owns it, and the command's `validates` line keeps this validator
  off it.
  """
  use Vex.Validator
  alias Sportipedia.Catalog.Athlete.Position.PositionInternal
  alias Sportipedia.Support.Validators.UuidValidator

  @doc """
  Validates the given id value.
  """
  # `term()`, not `String.t()`: the value reaches here straight off the request,
  # and a request can name an id with anything at all.
  @spec validate(term(), map()) :: :ok | {:error, :not_found}
  def validate(id, _context) do
    # The existence check is a round trip on the primary key, and `Repo.get/2`
    # raises on a value it cannot put in that clause: nil, a blank string, an
    # id of the wrong shape. A raise here reaches the client as 500. A
    # value that cannot denote the resource denotes no resource — the pattern's
    # own verdict for an unknown id, given without leaving the process.
    if UuidValidator.valid_uuid?(id) do
      case PositionInternal.position_by_id(id) do
        nil -> {:error, :not_found}
        _position -> :ok
      end
    else
      {:error, :not_found}
    end
  end
end
