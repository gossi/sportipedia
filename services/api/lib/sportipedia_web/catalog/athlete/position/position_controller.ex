defmodule SportipediaWeb.Catalog.Athlete.Position.PositionController do
  @moduledoc """
  Handles HTTP requests for position operations.
  """
  use SportipediaWeb, :controller
  use OpenApiSpex.ControllerSpecs
  alias OpenApiSpex.Reference
  alias Sportipedia.Catalog.Athlete.Position
  alias Sportipedia.Catalog.Athlete.Position.PositionReadModel
  alias SportipediaWeb.Catalog.Athlete.Position.PositionView
  alias SportipediaWeb.Catalog.Athlete.Position.Schemas.CatalogPositionRequest
  alias SportipediaWeb.Catalog.Athlete.Position.Schemas.EditPositionRequest
  alias SportipediaWeb.Catalog.Athlete.Position.Schemas.ListPositionsQueryParams
  alias SportipediaWeb.Catalog.Athlete.Position.Schemas.PositionCollectionResponse
  alias SportipediaWeb.Catalog.Athlete.Position.Schemas.PositionResponse
  alias SportipediaWeb.System.FallbackController

  plug Bodyguard.Plug.Authorize,
    policy: Sportipedia.Catalog.Athlete.Position.Policy,
    action: {Phoenix.Controller, :action_name},
    user: {Sportipedia.Auth, :get_user_from_assigns},
    fallback: FallbackController

  plug JSONAPI.QueryParser,
    filter: ~w(title),
    sort: ~w(title slug),
    view: PositionView

  tags ["athlete"]

  @doc """
  Handles the catalog-position request.
  """
  operation :catalog_position,
    summary:
      "Catalogs a new position in the catalog: a body position or stance, optionally bound to one piece of equipment",
    request_body: {"The position attributes", "application/json", CatalogPositionRequest},
    responses: [
      ok: {"The position", "application/vnd.api+json", PositionResponse},
      unprocessable_entity: %Reference{"$ref": "#/components/responses/unprocessable_entity"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"}
    ]

  @spec catalog_position(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def catalog_position(conn, _) do
    with {:ok, position} <- Position.catalog_position(conn.params) do
      conn
      |> put_view(json: PositionView)
      |> render("show.json", %{data: position})
    end
  end

  @doc """
  Handles the archive-position request.
  """
  operation :archive_position,
    summary: "Archives a position",
    responses: [
      no_content: "The position has been archived",
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"}
    ]

  @spec archive_position(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def archive_position(conn, _) do
    case Position.archive_position(conn.params["id"]) do
      :ok ->
        send_resp(conn, :no_content, "")

      {:error, errors} ->
        {:error, errors}
    end
  end

  @doc """
  Handles the edit-position request.
  """
  operation :edit_position,
    summary: "Edit properties of the position",
    request_body: {"The position attributes", "application/json", EditPositionRequest},
    responses: [
      ok: {"The position", "application/vnd.api+json", PositionResponse},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unprocessable_entity: %Reference{"$ref": "#/components/responses/unprocessable_entity"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"}
    ]

  @spec edit_position(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def edit_position(conn, _) do
    with {:ok, position} <- Position.edit_position(conn.params) do
      conn
      |> put_view(json: PositionView)
      |> render("show.json", %{data: position})
    end
  end

  @doc """
  Handles the list-positions request.
  """
  operation :list_positions,
    summary: "List all positions with filtering, sorting, and pagination",
    parameters: [
      query: [in: :query, schema: ListPositionsQueryParams]
    ],
    responses: [
      ok: {"Position collection", "application/vnd.api+json", PositionCollectionResponse}
    ]

  @spec list_positions(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def list_positions(conn, _) do
    case Position.list_positions(conn.assigns.jsonapi_query) do
      {:ok, data} ->
        conn
        |> put_view(json: PositionView)
        |> render("index.json", %{data: data})
    end
  end

  @doc """
  Handles the read-position request.
  """
  operation :read_position,
    summary: "Retrieve a single position by its id or slug",
    parameters: [
      id_or_slug: [in: :path, description: "The position id or slug", type: :string]
    ],
    responses: [
      ok: {"The position", "application/vnd.api+json", PositionResponse},
      not_found: %Reference{"$ref": "#/components/responses/not_found"}
    ]

  @spec read_position(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def read_position(conn, _) do
    case Position.read_position(conn.params["id_or_slug"]) do
      {:ok, %PositionReadModel{} = position} ->
        conn
        |> put_view(json: PositionView)
        |> render("show.json", %{data: position})

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end
end
