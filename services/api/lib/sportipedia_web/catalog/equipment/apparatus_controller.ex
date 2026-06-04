defmodule SportipediaWeb.Catalog.Equipment.ApparatusController do
  alias OpenApiSpex.Reference
  alias SportipediaWeb.System.FallbackController
  alias Sportipedia.Catalog.Equipment.Apparatus.Policy
  alias Sportipedia.Catalog.Equipment.Apparatus
  alias Sportipedia.Catalog.Equipment.Apparatus.Command.CatalogApparatus
  alias SportipediaWeb.Catalog.Equipment.Schemas.ApparatusResponse
  alias SportipediaWeb.Catalog.Equipment.Schemas.ApparatusListResponse
  alias SportipediaWeb.Catalog.Equipment.Schemas.EditApparatusRequest
  alias SportipediaWeb.Catalog.Equipment.Schemas.ArchiveApparatusRequest
  alias SportipediaWeb.Catalog.Equipment.ApparatusView

  use SportipediaWeb, :controller
  use OpenApiSpex.ControllerSpecs

  plug Bodyguard.Plug.Authorize,
    policy: Policy,
    action: {Phoenix.Controller, :action_name},
    user: {Sportipedia.Auth, :get_user_from_assigns},
    fallback: FallbackController

  plug JSONAPI.QueryParser,
    filter: ~w(title),
    sort: ~w(title),
    view: ApparatusView

  tags ["equipment"]

  operation :read_apparatus,
    summary: "Retrieve a single apparatus by its id or slug",
    parameters: [
      id: [in: :path, description: "ID or slug of the apparatus", type: :string]
    ],
    responses: [
      ok: {"Apparatus", "application/vnd.api+json", ApparatusResponse},
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

  operation :list_apparatuses,
    summary: "List all apparatuses with filtering, sorting, and pagination",
    responses: [
      ok: {"Apparatus collection", "application/vnd.api+json", ApparatusListResponse}
    ]

  def list_apparatuses(conn, _) do
    case Apparatus.list_apparatuses(conn.assigns.jsonapi_query) do
      {:ok, data} ->
        conn
        |> put_view(json: ApparatusView)
        |> render("index.json", %{data: data})
    end
  end

  operation :catalog_apparatus,
    summary: "Catalog an apparatus",
    request_body: {"Apparatus attributes", "application/json", CatalogApparatus},
    responses: [
      created: {"Apparatus", "application/vnd.api+json", ApparatusResponse},
      unprocessable_entity: %Reference{"$ref": "#/components/responses/unprocessable_entity"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"}
    ]

  def catalog_apparatus(conn, _) do
    with {:ok, apparatus} <- Apparatus.catalog_apparatus(conn.params) do
      conn
      |> put_status(:created)
      |> put_view(json: ApparatusView)
      |> render("show.json", %{data: apparatus})
    end
  end

  operation :edit_apparatus,
    summary: "Edit an apparatus",
    request_body: {"Apparatus attributes", "application/json", EditApparatusRequest},
    responses: [
      ok: {"Apparatus", "application/vnd.api+json", ApparatusResponse},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unprocessable_entity: %Reference{"$ref": "#/components/responses/unprocessable_entity"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"}
    ]

  def edit_apparatus(conn, _) do
    case Apparatus.edit_apparatus(conn.params) do
      {:ok, apparatus} ->
        conn
        |> put_view(json: ApparatusView)
        |> render("show.json", %{data: apparatus})

      {:error, _reason} ->
        {:error, :notfound}
    end
  end

  operation :archive_apparatus,
    summary: "Archive an apparatus",
    request_body: {"Apparatus id", "application/json", ArchiveApparatusRequest},
    responses: [
      no_content: "Apparatus archived",
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"}
    ]

  def archive_apparatus(conn, _) do
    case Apparatus.archive_apparatus(conn.params["id"]) do
      :ok ->
        send_resp(conn, :no_content, "")

      {:error, _} ->
        {:error, :notfound}
    end
  end
end
