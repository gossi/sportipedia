defmodule Sportipedia.Support.Validators.SlugValidator do
  use Vex.Validator

  @slug_pattern ~r/^[a-z0-9][a-z0-9-]*$/

  def validate(value, _options) do
    if valid_slug?(value) do
      :ok
    else
      {:error, :invalid_slug}
    end
  end

  @doc """
  A slug is canonical when it is already lower-case: lowercase letters, digits
  and dashes, and it must not start with a dash. There is nothing to downcase.
  """
  defp valid_slug?(maybe_slug) when is_binary(maybe_slug) do
    Regex.match?(@slug_pattern, maybe_slug)
  end

  defp valid_slug?(_maybe_slug), do: false
end
