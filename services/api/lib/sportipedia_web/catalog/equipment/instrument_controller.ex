defmodule SportipediaWeb.Catalog.Equipment.InstrumentController do
  alias OpenApiSpex.Reference
  alias SportipediaWeb.System.FallbackController
  alias SportipediaWeb.Catalog.Equipment.InstrumentView
  alias SportipediaWeb.Catalog.Equipment.Schemas.InstrumentResponse
  alias SportipediaWeb.Catalog.Equipment.Schemas.InstrumentListResponse
  alias Sportipedia.Catalog.Equipment.Instrument
  alias Sportipedia.Catalog.Equipment.Instrument.Policy
  alias Sportipedia.Catalog.Equipment.Instrument.Command.CatalogInstrument
  alias Sportipedia.Catalog.Equipment.Instrument.Command.DeleteInstrument
  alias Sportipedia.Catalog.Equipment.Instrument.Command.ArchiveInstrument
  alias Sportipedia.Catalog.Equipment.Instrument.InstrumentReadModel

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
    view: InstrumentView

  tags ["equipment"]

  operation :catalog_instrument,
    summary: "Catalogs an instrument",
    request_body: {"Instrument params", "application/json", CatalogInstrument},
    responses: [
      ok: {"New Instrument", "application/vnd.api+json", InstrumentResponse},
      unprocessable_entity: %Reference{"$ref": "#/components/responses/unprocessable_entity"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"}
    ]

  def catalog_instrument(conn, _) do
    IO.inspect(
      Commanded.Application.event_store_adapter(Sportipedia.Catalog),
      label: "EVENT STORE ADAPTER"
    )

    with {:ok, instrument} <- Instrument.catalog_instrument(conn.params) do
      conn
      |> put_view(json: InstrumentView)
      |> render("show.json", %{data: instrument})
    end
  end

  operation :read_instrument,
    summary: "Read an instrument",
    parameters: [
      id: [in: :path, description: "Instrument ID", type: :string]
    ],
    responses: [
      ok: {"Instrument", "application/vnd.api+json", InstrumentResponse},
      not_found: %Reference{"$ref": "#/components/responses/not_found"}
    ]

  def read_instrument(conn, _) do
    case Instrument.read_instrument(conn.params["id"]) do
      %InstrumentReadModel{} = instrument ->
        conn
        |> put_view(json: InstrumentView)
        |> render("show.json", %{data: instrument})

      nil ->
        {:error, :notfound}
    end
  end

  operation :list_instruments,
    summary: "List instruments",
    responses: [
      ok: {"Instrument collection", "application/vnd.api+json", InstrumentListResponse}
    ]

  def list_instruments(conn, _) do
    case Instrument.list_instruments(conn.assigns.jsonapi_query) do
      data ->
        conn
        |> put_view(json: InstrumentView)
        |> render("index.json", %{data: data})
    end
  end

  operation :edit_instrument,
    summary: "Edit an instrument",
    request_body: {"Instrument params", "application/json", EditInstrument},
    responses: [
      ok: {"Instrument", "application/vnd.api+json", InstrumentResponse},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unprocessable_entity: %Reference{"$ref": "#/components/responses/unprocessable_entity"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"}
    ]

  def edit_instrument(conn, _) do
    case Instrument.edit_instrument(conn.params) do
      {:ok, instrument} ->
        conn
        |> put_view(json: InstrumentView)
        |> render("show.json", %{data: instrument})

      {:error, _} ->
        {:error, :notfound}
    end
  end

  operation :archive_instrument,
    summary: "Archives an instrument",
    request_body: {"Instrument params", "application/json", ArchiveInstrument},
    responses: [
      no_content: "Instrument deleted",
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"}
    ]

  def archive_instrument(conn, _) do
    case Instrument.archive_instrument(conn.params["id"]) do
      :ok ->
        send_resp(conn, :no_content, "")

      {:error, _} ->
        {:error, :notfound}
    end
  end
end
