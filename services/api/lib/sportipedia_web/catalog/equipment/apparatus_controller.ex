defmodule SportipediaWeb.Catalog.Equipment.ApparatusController do
  @moduledoc """
  Handles HTTP requests for apparatus operations.
  """

  alias OpenApiSpex.Reference
  alias Sportipedia.Catalog.Equipment.Apparatus
  alias Sportipedia.Catalog.Equipment.Apparatus.Command.CatalogApparatus
  alias SportipediaWeb.Catalog.Equipment.ApparatusView
  alias SportipediaWeb.Catalog.Equipment.Schemas.ApparatusResponse
  alias SportipediaWeb.Catalog.Equipment.Schemas.CatalogApparatusRequest
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
    request_body:
      {"The apparatus attributes", "application/json", CatalogApparatusRequest},
    responses: [
      created:
        {"The cataloged apparatus", "application/vnd.api+json", ApparatusResponse},
      unprocessable_entity:
        %Reference{"$ref": "#/components/responses/unprocessable_entity"},
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
end
