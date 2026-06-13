defmodule SportipediaWeb.Catalog.Equipment.InstrumentController do
  @moduledoc """
  Handles HTTP requests for instrument operations.
  """

  alias OpenApiSpex.Reference
  alias Sportipedia.Catalog.Equipment.Instrument
  alias SportipediaWeb.Catalog.Equipment.Instrument.InstrumentView
  alias SportipediaWeb.Catalog.Equipment.Instrument.Schemas.ArchiveInstrumentRequest
  alias SportipediaWeb.Catalog.Equipment.Instrument.Schemas.CatalogInstrumentRequest
  alias SportipediaWeb.Catalog.Equipment.Instrument.Schemas.EditInstrumentRequest
  alias SportipediaWeb.Catalog.Equipment.Instrument.Schemas.InstrumentResponse
  alias SportipediaWeb.System.FallbackController

  use SportipediaWeb, :controller
  use OpenApiSpex.ControllerSpecs

  plug Bodyguard.Plug.Authorize,
    policy: Sportipedia.Catalog.Equipment.Instrument.Policy,
    action: {Phoenix.Controller, :action_name},
    user: {Sportipedia.Auth, :get_user_from_assigns},
    fallback: FallbackController

  tags ["equipment"]

  @doc """
  Handles the catalog-instrument request.
  """
  operation :catalog_instrument,
    summary: "Catalogs a new instrument",
    request_body: {"The instrument attributes", "application/json", CatalogInstrumentRequest},
    responses: [
      created: {"The cataloged instrument", "application/vnd.api+json", InstrumentResponse},
      unprocessable_entity: %Reference{"$ref": "#/components/responses/unprocessable_entity"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"}
    ]

  @spec catalog_instrument(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def catalog_instrument(conn, _) do
    with {:ok, instrument} <- Instrument.catalog_instrument(conn.params) do
      conn
      |> put_status(:created)
      |> put_view(json: InstrumentView)
      |> render("show.json", %{data: instrument})
    end
  end

  @doc """
  Handles the edit-instrument request.
  """
  operation :edit_instrument,
    summary: "Edits an existing instrument",
    request_body: {"The instrument attributes", "application/json", EditInstrumentRequest},
    responses: [
      ok: {"The edited instrument", "application/vnd.api+json", InstrumentResponse},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unprocessable_entity: %Reference{"$ref": "#/components/responses/unprocessable_entity"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"}
    ]

  @spec edit_instrument(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def edit_instrument(conn, _) do
    case Instrument.edit_instrument(conn.params) do
      {:ok, instrument} ->
        conn
        |> put_view(json: InstrumentView)
        |> render("show.json", %{data: instrument})

      {:error, errors} ->
        {:error, errors}
    end
  end

  @doc """
  Handles the archive-instrument request.
  """
  operation :archive_instrument,
    summary: "Archives an existing instrument",
    request_body: {"The instrument id", "application/json", ArchiveInstrumentRequest},
    responses: [
      no_content: "The instrument was archived",
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"}
    ]

  @spec archive_instrument(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def archive_instrument(conn, _) do
    case Instrument.archive_instrument(conn.params["id"]) do
      :ok ->
        send_resp(conn, :no_content, "")

      {:error, errors} ->
        {:error, errors}
    end
  end
end
