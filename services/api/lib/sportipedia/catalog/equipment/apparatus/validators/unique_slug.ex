defmodule Sportipedia.Catalog.Equipment.Apparatus.Validators.UniqueSlug do
  use Vex.Validator

  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusInternal

  def validate(value, context) do
    case slug_exists?(value, Map.get(context, :id)) do
      true -> {:error, "slug already exists"}
      false -> :ok
    end
  end

  defp slug_exists?(slug, exclude_id) do
    case ApparatusInternal.apparatus_by_slug(slug) do
      nil -> false
      %{id: ^exclude_id} -> false
      _ -> true
    end
  end
end
