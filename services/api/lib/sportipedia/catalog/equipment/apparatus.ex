defmodule Sportipedia.Catalog.Equipment.Apparatus do
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusInternal
  alias Sportipedia.Catalog.Equipment.Apparatus.Command.CatalogApparatus
  alias Sportipedia.Catalog.Equipment.Apparatus.Command.EditApparatus
  alias Sportipedia.Catalog.Equipment.Apparatus.Command.ArchiveApparatus
  alias Sportipedia.Catalog.Equipment.Apparatus.Queries.ListApparatuses
  alias Sportipedia.Catalog.Repo

  def catalog_apparatus(params) do
    id = UUID.uuid4()
    cmd = CatalogApparatus.new(Map.put(params, :id, id))

    with :ok <- Sportipedia.Catalog.dispatch(cmd, consistency: :strong) do
      {:ok, ApparatusInternal.apparatus_by_id(id)}
    end
  end

  def edit_apparatus(params) do
    cmd = EditApparatus.new(params)

    case Sportipedia.Catalog.dispatch(cmd, consistency: :strong) do
      :ok -> {:ok, ApparatusInternal.apparatus_by_id(cmd.id)}
      {:error, :apparatus_not_found} -> {:error, :notfound}
      error -> error
    end
  end

  def archive_apparatus(id) do
    apparatus = ApparatusInternal.apparatus_by_id(id)

    case Sportipedia.Catalog.dispatch(ArchiveApparatus.new(id: id), consistency: :strong) do
      :ok -> {:ok, apparatus}
      {:error, :apparatus_not_found} -> {:error, :notfound}
      error -> error
    end
  end

  @doc """
  Reads a single apparatus by its id or slug.

  Returns `{:ok, apparatus}` if found, `{:error, :not_found}` otherwise.
  """
  @spec read_apparatus(String.t()) :: {:ok, term()} | {:error, :not_found}
  def read_apparatus(id_or_slug) do
    case fetch_apparatus(id_or_slug) do
      nil -> {:error, :not_found}
      apparatus -> {:ok, apparatus}
    end
  end

  defp fetch_apparatus(id_or_slug) do
    if uuid?(id_or_slug) do
      ApparatusInternal.apparatus_by_id(id_or_slug)
    else
      ApparatusInternal.apparatus_by_slug(id_or_slug)
    end
  end

  defp uuid?(value) do
    match?({:ok, _}, UUID.info(value))
  end

  @doc """
  Lists apparatuses with optional filtering, sorting, and pagination.

  ## Params
    - `filter` - map with optional `title` key for case-insensitive partial match
    - `sort` - sort field(s) following JSON:API sort syntax (e.g. `"title"` or `"-title"`)
    - `page` - map with `number` and `size` keys for pagination

  Returns `{:ok, [apparatus]}`.
  """
  @spec list_apparatuses(map()) :: {:ok, [term()]}
  def list_apparatuses(params) do
    {:ok, Repo.all(ListApparatuses.new(params))}
  end
end
