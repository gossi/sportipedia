defmodule SportipediaWeb.Catalog.Equipment.ApparatusController do
  @moduledoc """
  Handles HTTP requests for apparatus operations.
  """

  alias OpenApiSpex.Reference
  alias Sportipedia.Catalog.Equipment.Apparatus
  alias SportipediaWeb.Catalog.Equipment.ApparatusView
  alias SportipediaWeb.Catalog.Equipment.Schemas.ApparatusResponse
  alias SportipediaWeb.Catalog.Equipment.Schemas.CatalogApparatusRequest
  alias SportipediaWeb.Catalog.Equipment.Schemas.EditApparatusRequest
  alias SportipediaWeb.System.FallbackController

  use SportipediaWeb, :controller
  use OpenApiSpex.ControllerSpecs

  plug Bodyguard.Plug.Authorize,
    policy: Sportipedia.Catalog.Equipment.Apparatus.Policy,
    action: {Phoenix.Controller, :action_name},
    user: {Sportipedia.Auth, :get_user_from_assigns},
    fallback: FallbackController

  tags ["equipment"]

  @doc """
  Handles the catalog-apparatus request.
  """
  operation :catalog_apparatus,
    summary: "Catalogs a new apparatus",
    request_body: {"The apparatus attributes", "application/json", CatalogApparatusRequest},
    responses: [
      created: {"The cataloged apparatus", "application/vnd.api+json", ApparatusResponse},
      unprocessable_entity: %Reference{"$ref": "#/components/responses/unprocessable_entity"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"}
    ]

  @spec catalog_apparatus(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def catalog_apparatus(conn, _) do
    with {:ok, apparatus} <- Apparatus.catalog_apparatus(conn.params) do
      conn
      |> put_status(:created)
      |> put_view(json: ApparatusView)
      |> render("show.json", %{data: apparatus})
    end
  end

  @doc """
  Handles the edit-apparatus request.
  """
  operation :edit_apparatus,
    summary: "Edits an existing apparatus",
    request_body: {"The apparatus attributes to edit", "application/json", EditApparatusRequest},
    responses: [
      ok: {"The edited apparatus", "application/vnd.api+json", ApparatusResponse},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unprocessable_entity: %Reference{"$ref": "#/components/responses/unprocessable_entity"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"}
    ]

  @spec edit_apparatus(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def edit_apparatus(conn, _) do
    params =
      conn.params
      |> Map.take(["id", "title", "slug", "description"])

    with {:ok, apparatus} <- Apparatus.edit_apparatus(params),
          true <- apparatus != nil || {:error, :notfound} do
      conn
      |> put_view(json: ApparatusView)
      |> render("show.json", %{data: apparatus})
    end
  end

  @doc """
  Handles the archive-apparatus request.
  """
  operation :archive_apparatus,
    summary: "Archives an apparatus",
    responses: [
      no_content: "The apparatus has been archived",
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"}
    ]

  @spec archive_apparatus(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def archive_apparatus(conn, _) do
    case Apparatus.archive_apparatus(conn.params["id"]) do
      :ok ->
        send_resp(conn, :no_content, "")

      {:error, _} ->
        {:error, :notfound}
    end
  end
end
