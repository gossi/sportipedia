defmodule Sportipedia.Catalog.Equipment.Apparatus.Validators.UniqueSlug do
  use Vex.Validator

  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusInternal

  def validate(nil, _context), do: :ok
  def validate(value, _context) do
    case slug_exists?(value) do
      true -> {:error, "slug already exists"}
      false -> :ok
    end
  end

  defp slug_exists?(slug) do
    case ApparatusInternal.apparatus_by_slug(slug) do
      nil -> false
      _ -> true
    end
  end
end
