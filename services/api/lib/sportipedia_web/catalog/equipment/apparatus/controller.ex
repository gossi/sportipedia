defmodule SportipediaWeb.Catalog.Equipment.ApparatusController do
  alias OpenApiSpex.Reference
  alias SportipediaWeb.System.FallbackController
  alias Sportipedia.Catalog.Equipment.Apparatus.Policy
  alias Sportipedia.Catalog.Equipment.Apparatus
  alias Sportipedia.Catalog.Equipment.Apparatus.Command.CatalogApparatus
  alias Sportipedia.Catalog.Equipment.Apparatus.Command.EditApparatus
  alias Sportipedia.Catalog.Equipment.Apparatus.Command.ArchiveApparatus
  alias SportipediaWeb.Catalog.Equipment.ApparatusView
  alias SportipediaWeb.Catalog.Equipment.Schemas.ApparatusResponse
  alias SportipediaWeb.Catalog.Equipment.Schemas.ListApparatusesResponse

  use SportipediaWeb, :controller
  use OpenApiSpex.ControllerSpecs

  plug Bodyguard.Plug.Authorize,
    policy: Policy,
    action: {Phoenix.Controller, :action_name},
    user: {Sportipedia.Auth, :get_user_from_assigns},
    fallback: FallbackController

  tags ["equipment"]

  plug JSONAPI.QueryParser,
    filter: ~w(title),
    sort: ~w(title slug description),
    view: ApparatusView

  operation :catalog_apparatus,
    summary: "Catalog a new apparatus",
    request_body:
      {"Parameters for cataloging an apparatus", "application/json", CatalogApparatus},
    responses: [
      ok: {"The cataloged apparatus", "application/vnd.api+json", ApparatusResponse},
      unprocessable_entity: %Reference{"$ref": "#/components/responses/unprocessable_entity"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"}
    ]

  def catalog_apparatus(conn, _) do
    with {:ok, apparatus} <- Apparatus.catalog_apparatus(conn.params) do
      conn
      |> put_view(json: ApparatusView)
      |> render("show.json", %{data: apparatus})
    end
  end

  operation :edit_apparatus,
    summary: "Edit an existing apparatus",
    request_body: {"Parameters for editing an apparatus", "application/json", EditApparatus},
    responses: [
      ok: {"The edited apparatus", "application/vnd.api+json", ApparatusResponse},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unprocessable_entity: %Reference{"$ref": "#/components/responses/unprocessable_entity"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"}
    ]

  def edit_apparatus(conn, _) do
    with {:ok, apparatus} <- Apparatus.edit_apparatus(conn.params) do
      conn
      |> put_view(json: ApparatusView)
      |> render("show.json", %{data: apparatus})
    end
  end

  operation :archive_apparatus,
    summary: "Archive an apparatus",
    request_body: {"Parameters for archiving an apparatus", "application/json", ArchiveApparatus},
    responses: [
      ok: {"The archived apparatus", "application/vnd.api+json", ApparatusResponse},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"}
    ]

  def archive_apparatus(conn, _) do
    case Apparatus.archive_apparatus(conn.params["id"]) do
      {:ok, apparatus} ->
        conn
        |> put_view(json: ApparatusView)
        |> render("show.json", %{data: apparatus})

      {:error, :notfound} ->
        {:error, :notfound}
    end
  end

  operation :list_apparatuses,
    summary: "List all apparatuses",
    responses: [
      ok: {"Apparatus collection", "application/vnd.api+json", ListApparatusesResponse}
    ]

  def list_apparatuses(conn, _) do
    jsonapi_query = conn.assigns.jsonapi_query

    params = %{
      filter: normalize_filter(jsonapi_query.filter),
      sort: jsonapi_query.sort,
      page: jsonapi_query.page
    }

    case Apparatus.list_apparatuses(params) do
      {:ok, data} ->
        conn
        |> put_view(json: ApparatusView)
        |> render("index.json", %{data: data})
    end
  end

  defp normalize_filter([]), do: nil
  defp normalize_filter(filter), do: filter

  operation :read_apparatus,
    summary: "Read a single apparatus",
    parameters: [
      id: [in: :path, description: "The id or slug of the apparatus", type: :string]
    ],
    responses: [
      ok: {"The apparatus", "application/vnd.api+json", ApparatusResponse},
      not_found: %Reference{"$ref": "#/components/responses/not_found"}
    ]

  def read_apparatus(conn, _) do
    case Apparatus.read_apparatus(conn.params["id"]) do
      {:ok, apparatus} ->
        conn
        |> put_view(json: ApparatusView)
        |> render("show.json", %{data: apparatus})

      {:error, :not_found} ->
        {:error, :notfound}
    end
  end
end
