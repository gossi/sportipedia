defmodule SportipediaWeb.System.JSONAPI.ValidationErrorFormatter do
  @moduledoc """
  Pure transformation: Vex/Uniqueness errors → JSON:API error map list.
  Does not send responses.
  """
  @doc """
  Formats validation errors into a list of JSON:API error maps.
  Handles flat maps (%{field: ["msg"]}) and nested maps.
  """
  @spec format(map()) :: [map()]
  def format(field_errors) when is_map(field_errors) do
    field_errors
    |> normalize()
    |> Enum.flat_map(fn {field, messages} ->
      Enum.map(List.wrap(messages), &build_error(field, &1))
    end)
  end

  # --- Private ---
  defp normalize(field_errors) when is_map(field_errors) do
    Enum.flat_map(field_errors, fn
      {field, nested} when is_map(nested) ->
        normalize(nested)
        |> Enum.map(fn {subfield, msgs} -> {:"#{field}.#{subfield}", msgs} end)

      {field, messages} ->
        [{field, List.wrap(messages)}]
    end)
  end

  defp build_error(field, message) do
    %{
      title: field,
      detail: message,
      source: %{pointer: "/data/attributes/#{field}"},
      status: "422"
    }
  end
end
