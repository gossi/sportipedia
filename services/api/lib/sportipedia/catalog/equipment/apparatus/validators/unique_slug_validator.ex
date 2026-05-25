defmodule Sportipedia.Catalog.Equipment.Apparatus.Validators.UniqueSlugValidator do
  use Vex.Validator

  alias Sportipedia.Catalog.Equipment.Apparatus.Queries.FindApparatusBySlugQuery
  alias Sportipedia.Catalog.Repo

  def validate(nil, _context), do: :ok

  def validate(slug, _context) do
    case slug_exists?(slug) do
      true -> {:error, "slug already exists"}
      false -> :ok
    end
  end

  defp slug_exists?(slug) do
    case Repo.one(FindApparatusBySlugQuery.new(slug)) do
      nil -> false
      _ -> true
    end
  end
end
