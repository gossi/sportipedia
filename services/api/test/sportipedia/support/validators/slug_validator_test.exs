defmodule Sportipedia.Support.Validators.SlugValidatorTest do
  use ExUnit.Case

  alias Sportipedia.Support.Validators.SlugValidator

  @canonical [
    "handstand",
    "ready-stance",
    "lunge-2-position",
    "a",
    "9",
    "trailing-dash-",
    "with--double"
  ]

  @malformed [
    {"Ready-STANCE", "carries upper-case letters"},
    {"READY", "is all upper-case"},
    {"ready stance", "holds a space"},
    {"ready_stance", "holds an underscore"},
    {"ready.stance", "holds a dot"},
    {"ready/stance", "holds a slash"},
    {"élan", "holds non-ASCII letters"},
    {"-ready", "starts with a dash"},
    {"-", "is only a dash"},
    {"", "is blank"},
    {nil, "is nil"},
    {:atom, "is not a string"}
  ]

  describe "validate/2" do
    test "accepts slugs of lower-case letters, digits and dashes" do
      for slug <- @canonical do
        assert :ok == SlugValidator.validate(slug, %{}), "expected #{inspect(slug)} to be valid"
      end
    end

    test "rejects anything else with the invalid_slug atom" do
      for {value, reason} <- @malformed do
        assert {:error, :invalid_slug} == SlugValidator.validate(value, %{}),
               "expected #{inspect(value)} to be rejected: #{reason}"
      end
    end
  end
end
