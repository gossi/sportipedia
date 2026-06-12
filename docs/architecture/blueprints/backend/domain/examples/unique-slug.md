# Unique Slug: Validator and Queries

This example covers a fairly common concept of checking for slug uniqueness.
It explains where to locate the individual parts.

Make a [query](../query.md) (ideally this is found in the domain model, too) and call it as part of implementation details:

```elixir
defmodule Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Queries.<DomainObject>BySlug do
  @moduledoc """
  Query to fetch a <domain_object> by its slug.
  """

  alias Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>ReadModel
  import Ecto.Query

  @doc """
  Creates a new query to fetch a <domain_object> by slug.
  """
  def new(slug) do
    from(r in <DomainObject>ReadModel,
      where: r.slug == ^slug
    )
  end
end
```

Use that query in the [internal API](../internal-api.md)

```elixir
defmodule Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Internal do
  @moduledoc """
  Internal API for querying <domain_object> read models within the bounded context.
  """

  alias Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Queries.<DomainObject>BySlug

  @doc """
  Fetches a <domain_object> by its slug. Returns nil if not found.
  """
  def <_domain_object>_by_slug(slug) do
    slug
    |> String.downcase()
    |> <DomainObject>BySlug.new()
    |> Repo.one()
  end
end
```

Use from [Validator](../validator.md)

```elixir
defmodule Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Validators.UniqueSlug do
  @moduledoc """
  Validates that a <domain_object> slug is unique within the catalog.
  """

  use Vex.Validator

  alias Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Internal

  @doc """
  Validates the given slug value for uniqueness.
  """
  def validate(value, _context) do
    case slug_exists?(value) do
      true -> {:error, "slug already exists"}
      false -> :ok
    end
  end

  defp slug_exists?(slug) do
    case <DomainObject>Internal.instrument_by_slug(slug) do
      nil -> false
      _ -> true
    end
  end
end
```
