defmodule Sportipedia.Catalog.Equipment.Widget.Validators.AtMostOneOwner do
@moduledoc """
Validates the 'at-most-one-owner' rule: A widget is owned by at most one coach (either coach_id or team_id, not both)
"""
use Vex.Validator
@doc """
Validates the given coach_id value.
"""
@spec validate(String.t(), map()) :: :ok | {:error, term()}
def validate(_value, _context) do
  raise "TODO: implement the at-most-one-owner validator (see the domain model rule)"
end
end
