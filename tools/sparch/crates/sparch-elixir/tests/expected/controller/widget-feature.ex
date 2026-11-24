defmodule SportipediaWeb.Catalog.Equipment.Widget.WidgetController do
@moduledoc """
Handles HTTP requests for widget operations.
"""
use SportipediaWeb, :controller
use OpenApiSpex.ControllerSpecs
alias OpenApiSpex.Reference
alias Sportipedia.Catalog.Equipment.Widget
alias Sportipedia.Catalog.Equipment.Widget.WidgetReadModel
alias SportipediaWeb.Catalog.Equipment.Widget.Schemas.CreateWidgetRequest
alias SportipediaWeb.Catalog.Equipment.Widget.Schemas.EditWidgetRequest
alias SportipediaWeb.Catalog.Equipment.Widget.Schemas.ListWidgetsQueryParams
alias SportipediaWeb.Catalog.Equipment.Widget.Schemas.NoteWidgetRequest
alias SportipediaWeb.Catalog.Equipment.Widget.Schemas.RelabelWidgetRequest
alias SportipediaWeb.Catalog.Equipment.Widget.WidgetView
alias SportipediaWeb.System.FallbackController
  plug Bodyguard.Plug.Authorize,
    policy: Sportipedia.Catalog.Equipment.Widget.Policy,
    action: {Phoenix.Controller, :action_name},
    user: {Sportipedia.Auth, :get_user_from_assigns},
    fallback: FallbackController
  plug JSONAPI.QueryParser,
    filter: ~w(title),
    sort: ~w(title slug),
    view: WidgetView
tags ["equipment"]
@doc """
Handles the archive-widget request.
"""
operation :archive_widget,
  summary: "Archives a widget that is no longer used",
  responses: [
        no_content: "The widget has been archived",
        not_found: %Reference{"$ref": "#/components/responses/not_found"},
        unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
        forbidden: %Reference{"$ref": "#/components/responses/forbidden"}
  ]

@spec archive_widget(Plug.Conn.t(), map()) :: Plug.Conn.t()
def archive_widget(conn, _) do
  case Widget.archive_widget(conn.params["id"]) do
    :ok ->
      send_resp(conn, :no_content, "")

    {:error, errors} ->
      {:error, errors}
  end
end
@doc """
Handles the create-widget request.
"""
operation :create_widget,
  summary: "Catalogs a new widget in the equipment catalog",
      request_body: {"The widget attributes", "application/json", CreateWidgetRequest},
  responses: [
        ok: {"The widget", "application/vnd.api+json", WidgetResponse},
        unprocessable_entity: %Reference{"$ref": "#/components/responses/unprocessable_entity"},
        unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
        forbidden: %Reference{"$ref": "#/components/responses/forbidden"}
  ]

@spec create_widget(Plug.Conn.t(), map()) :: Plug.Conn.t()
def create_widget(conn, _) do
  with {:ok, widget} <- Widget.create_widget(create_widget_params(conn.params)) do
    conn
    |> put_view(json: WidgetView)
    |> render("show.json", %{data: widget})
  end
end

defp create_widget_params(%{"data" => data} = params) do
  base = data["attributes"] || %{}

  case params["id"] || data["id"] do
    nil -> base
    id -> Map.put(base, "id", id)
  end
end
@doc """
Handles the edit-widget request.
"""
operation :edit_widget,
  summary: "Edits an existing widget",
      request_body: {"The widget attributes", "application/json", EditWidgetRequest},
  responses: [
        ok: {"The widget", "application/vnd.api+json", WidgetResponse},
        unprocessable_entity: %Reference{"$ref": "#/components/responses/unprocessable_entity"},
        unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
        forbidden: %Reference{"$ref": "#/components/responses/forbidden"}
  ]

@spec edit_widget(Plug.Conn.t(), map()) :: Plug.Conn.t()
def edit_widget(conn, _) do
  with {:ok, widget} <- Widget.edit_widget(edit_widget_params(conn.params)) do
    conn
    |> put_view(json: WidgetView)
    |> render("show.json", %{data: widget})
  end
end

defp edit_widget_params(%{"data" => data} = params) do
  base = data["attributes"] || %{}

  case params["id"] || data["id"] do
    nil -> base
    id -> Map.put(base, "id", id)
  end
end
@doc """
Handles the note-widget request.
"""
operation :note_widget,
  summary: "Takes note of a widget — a fact is recorded, nothing materializes",
      request_body: {"The widget attributes", "application/json", NoteWidgetRequest},
  responses: [
        no_content: "The widget was processed without materialization",
        not_found: %Reference{"$ref": "#/components/responses/not_found"},
        unprocessable_entity: %Reference{"$ref": "#/components/responses/unprocessable_entity"},
        unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
        forbidden: %Reference{"$ref": "#/components/responses/forbidden"}
  ]

@spec note_widget(Plug.Conn.t(), map()) :: Plug.Conn.t()
def note_widget(conn, _) do
  case Widget.note_widget(note_widget_params(conn.params)) do
    :ok ->
      send_resp(conn, :no_content, "")

    {:error, errors} ->
      {:error, errors}
  end
end

defp note_widget_params(%{"data" => data} = params) do
  base = data["attributes"] || %{}

  case params["id"] || data["id"] do
    nil -> base
    id -> Map.put(base, "id", id)
  end
end
@doc """
Handles the relabel-widget request.
"""
operation :relabel_widget,
  summary: "Renames a widget and records the rename for the audit trail",
      request_body: {"The widget attributes", "application/json", RelabelWidgetRequest},
  responses: [
        ok: {"The widget", "application/vnd.api+json", WidgetResponse},
        unprocessable_entity: %Reference{"$ref": "#/components/responses/unprocessable_entity"},
        unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
        forbidden: %Reference{"$ref": "#/components/responses/forbidden"}
  ]

@spec relabel_widget(Plug.Conn.t(), map()) :: Plug.Conn.t()
def relabel_widget(conn, _) do
  with {:ok, widget} <- Widget.relabel_widget(relabel_widget_params(conn.params)) do
    conn
    |> put_view(json: WidgetView)
    |> render("show.json", %{data: widget})
  end
end

defp relabel_widget_params(%{"data" => data} = params) do
  base = data["attributes"] || %{}

  case params["id"] || data["id"] do
    nil -> base
    id -> Map.put(base, "id", id)
  end
end
@doc """
Handles the list-widgets request.
"""
operation :list_widgets,
  summary: "List all widgets with filtering, sorting, and pagination",
      parameters: [
        query: [in: :query, schema: ListWidgetsQueryParams]
      ],
  responses: [
        ok: {"Widget collection", "application/vnd.api+json", WidgetCollectionResponse}
  ]

@spec list_widgets(Plug.Conn.t(), map()) :: Plug.Conn.t()
def list_widgets(conn, _) do
  case Widget.list_widgets(conn.assigns.jsonapi_query) do
    {:ok, data} ->
      conn
      |> put_view(json: WidgetView)
      |> render("index.json", %{data: data})
  end
end
@doc """
Handles the read-widget request.
"""
operation :read_widget,
  summary: "Retrieve a single widget by its id or slug",
      parameters: [
        id_or_slug: [in: :path, description: "The widget id or or or slug", type: :string]
      ],
  responses: [
        ok: {"The widget", "application/vnd.api+json", WidgetResponse},
        not_found: %Reference{"$ref": "#/components/responses/not_found"}
  ]

@spec read_widget(Plug.Conn.t(), map()) :: Plug.Conn.t()
def read_widget(conn, _) do
  case Widget.read_widget(conn.params["id_or_slug"]) do
    {:ok, %WidgetReadModel{} = widget} ->
      conn
      |> put_view(json: WidgetView)
      |> render("show.json", %{data: widget})

    {:error, :not_found} ->
      {:error, :not_found}
  end
end
end
