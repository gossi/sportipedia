defmodule Sportipedia.Catalog.Equipment.Apparatus do
  alias Sportipedia.Catalog
  alias Sportipedia.Catalog.Repo
  alias Sportipedia.Catalog.Equipment.Apparatus.Command.CatalogApparatus
  alias Sportipedia.Catalog.Equipment.Apparatus.Command.EditApparatus
  alias Sportipedia.Catalog.Equipment.Apparatus.Command.ArchiveApparatus
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusInternal
  alias Sportipedia.Catalog.Equipment.Apparatus.Queries.ListApparatuses

  def list_apparatuses(params) do
    apparatuses =
      params
      |> ListApparatuses.new()
      |> Repo.all()

    {:ok, apparatuses}
  end

  def catalog_apparatus(params) do
    params = Map.put_new(params, :id, UUID.uuid4())

    with {:ok, _aggregate} <- Catalog.dispatch(CatalogApparatus.new(params), consistency: :strong, include_aggregate_version: true) do
      slug = (params[:slug] || params["slug"]) |> String.downcase()

      case ApparatusInternal.apparatus_by_slug(slug) do
        nil -> {:error, :not_found}
        apparatus -> {:ok, apparatus}
      end
    end
  end

  def edit_apparatus(params) do
    try do
      cmd = EditApparatus.new(params)

      with {:ok, _aggregate} <- Catalog.dispatch(cmd, consistency: :strong, include_aggregate_version: true) do
        id = params[:id] || params["id"]

        case ApparatusInternal.apparatus_by_id(id) do
          nil -> {:error, :not_found}
          apparatus -> {:ok, apparatus}
        end
      end
    rescue
      ArgumentError -> {:error, :missing_id}
    end
  end

  def read_apparatus(id_or_slug) do
    with {:ok, apparatus} <- by_id(id_or_slug) do
      {:ok, apparatus}
    else
      :not_found ->
        case ApparatusInternal.apparatus_by_slug(id_or_slug) do
          nil -> {:error, :not_found}
          apparatus -> {:ok, apparatus}
        end

      :invalid_id ->
        case ApparatusInternal.apparatus_by_slug(id_or_slug) do
          nil -> {:error, :not_found}
          apparatus -> {:ok, apparatus}
        end
    end
  end

  defp by_id(id_or_slug) do
    case uuid?(id_or_slug) do
      true ->
        case ApparatusInternal.apparatus_by_id(id_or_slug) do
          nil -> :not_found
          apparatus -> {:ok, apparatus}
        end

      false ->
        :invalid_id
    end
  end

  defp uuid?(value) when is_binary(value) do
    String.match?(value, ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i)
  end

  defp uuid?(_), do: false

  def archive_apparatus(id) when is_nil(id) do
    {:error, :missing_id}
  end

  def archive_apparatus(id) do
    case ApparatusInternal.apparatus_by_id(id) do
      nil -> {:error, :not_found}
      _ ->
        cmd = ArchiveApparatus.new(%{id: id})

        with {:ok, _aggregate} <- Catalog.dispatch(cmd, consistency: :strong, include_aggregate_version: true) do
          :ok
        end
    end
  end
end
