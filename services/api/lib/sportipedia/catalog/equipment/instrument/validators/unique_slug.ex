defmodule Sportipedia.Catalog.Equipment.Instrument.Validators.UniqueSlug do
  use Vex.Validator

  alias Sportipedia.Catalog.Equipment.Instrument

  def validate(value, _context) do
    case slug_exists?(value) do
      true -> {:error, "slug already exists"}
      false -> :ok
    end
  end

  defp slug_exists?(slug) do
    case Instrument.instrument_by_slug(slug) do
      nil -> false
      _ -> true
    end
  end
end
