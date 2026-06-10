defmodule SportipediaWeb.Catalog.Equipment.ApparatusController do
  alias OpenApiSpex.Reference
  alias SportipediaWeb.System.FallbackController
  alias Sportipedia.Catalog.Equipment.Apparatus.Policy
  alias Sportipedia.Catalog.Equipment.Apparatus
  alias Sportipedia.Catalog.Equipment.Apparatus.Command.CatalogApparatus
  alias Sportipedia.Catalog.Equipment.Apparatus.Command.EditApparatus
  alias SportipediaWeb.Catalog.Equipment.ApparatusView
  alias SportipediaWeb.Catalog.Equipment.Schemas.ApparatusResponse

  use SportipediaWeb, :controller
  use OpenApiSpex.ControllerSpecs

  plug Bodyguard.Plug.Authorize,
    policy: Policy,
    action: {Phoenix.Controller, :action_name},
    user: {Sportipedia.Auth, :get_user_from_assigns},
    fallback: FallbackController

  tags ["equipment"]

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
end
