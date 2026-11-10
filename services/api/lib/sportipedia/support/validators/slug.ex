defmodule Sportipedia.Support.Validators.SlugValidator do
  @moduledoc """
  Validates slugs in canonical form: lower-case letters, digits and dashes,
  and never starting with a dash. Slug input that is not canonical is
  rejected at the command boundary — there is nothing to downcase.
  """
  use Vex.Validator

  @slug_pattern ~r/^[a-z0-9][a-z0-9-]*$/

  def validate(value, _options) do
    if valid_slug?(value) do
      :ok
    else
      {:error, :invalid_slug}
    end
  end

  defp valid_slug?(maybe_slug) when is_binary(maybe_slug) do
    Regex.match?(@slug_pattern, maybe_slug)
  end

  defp valid_slug?(_maybe_slug), do: false
end
