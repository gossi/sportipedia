defmodule Sportipedia.Catalog.Equipment.Instruments.Validators.UniqueSlug do
  use Vex.Validator

  alias Sportipedia.Catalog.Equipment.Instruments

  def validate(value, _context) do
    case slug_exists?(value) do
      true -> {:error, "slug already exists"}
      false -> :ok
    end
  end

  defp slug_exists?(slug) do
    case Instruments.instrument_by_slug(slug) do
      nil -> false
      _ -> true
    end
  end
end
