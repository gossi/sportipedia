defmodule Sportipedia.Support.Commanded.TypeProvider do
  alias Commanded.Serialization.ModuleNameTypeProvider

  @behaviour Commanded.EventStore.TypeProvider

  @impl true
  def to_string(struct) do
    ModuleNameTypeProvider.to_string(struct)
    |> String.replace("Elixir.", "")
    |> String.replace("Event.", "")
    |> Macro.underscore()
    |> String.replace("_", "-")
    |> String.replace("/", ".")
  end

  @impl true
  def to_struct(type) do
    module =
      if String.starts_with?(type, "Elixir") do
        type
      else
        type
        |> String.split(".")
        |> List.insert_at(-2, "event")
        |> Enum.map(fn part -> part |> String.replace("-", "_") |> Macro.camelize() end)
        |> List.insert_at(0, "Elixir")
        |> Enum.join(".")
      end

    ModuleNameTypeProvider.to_struct(module)
  end
end
