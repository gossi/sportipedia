defmodule Sportipedia.Catalog.Equipment.Widget do
@moduledoc """
Public API for managing widgets in the sport.
"""
alias Sportipedia.Architecture
alias Sportipedia.Catalog
alias Sportipedia.Catalog.Equipment.Widget.Command.ArchiveWidget
alias Sportipedia.Catalog.Equipment.Widget.Command.CreateWidget
alias Sportipedia.Catalog.Equipment.Widget.Command.EditWidget
alias Sportipedia.Catalog.Equipment.Widget.Command.NoteWidget
alias Sportipedia.Catalog.Equipment.Widget.Command.RelabelWidget
alias Sportipedia.Catalog.Equipment.Widget.Queries.ListWidgets
alias Sportipedia.Catalog.Equipment.Widget.WidgetInternal
alias Sportipedia.Catalog.Equipment.Widget.WidgetReadModel
alias Sportipedia.Catalog.Repo
alias Sportipedia.Support.ErrorClassifier

alias Sportipedia.Support.Validators.UuidValidator
@doc """
Archives a widget that is no longer used
"""
@spec archive_widget(String.t()) :: Architecture.public_api()
def archive_widget(id) do
  case Catalog.dispatch(ArchiveWidget.new(id: id), consistency: :strong) do
    :ok -> :ok
    {:error, errors} -> ErrorClassifier.classify_error(errors)
  end
end

@doc """
Catalogs a new widget in the equipment catalog
"""
@spec create_widget(%{required(:title) => String.t(), required(:slug) => String.t(), optional(:coach_id) => String.t() | nil, optional(:description) => String.t() | nil, optional(:label) => String.t() | nil, optional(:team_id) => String.t() | nil}) :: Architecture.public_api(WidgetReadModel.t())
def create_widget(params) do
  id = UUID.uuid4()
  cmd = CreateWidget.new(Map.put(params, "id", id))

  case Catalog.dispatch(cmd, consistency: :strong) do
    :ok ->
      {:ok, WidgetInternal.widget_by_id(id)}

    {:error, errors} ->
      ErrorClassifier.classify_error(errors)
  end
end

@doc """
Edits an existing widget
"""
@spec edit_widget(%{required(:id) => String.t(), optional(:coach_id) => String.t() | nil, optional(:description) => String.t() | nil, optional(:label) => String.t() | nil, optional(:slug) => String.t() | nil, optional(:team_id) => String.t() | nil, optional(:title) => String.t() | nil}) :: Architecture.public_api(WidgetReadModel.t())
def edit_widget(params) do
  case Catalog.dispatch(EditWidget.new(params), consistency: :strong) do
    :ok ->
      {:ok, WidgetInternal.widget_by_id(params[:id] || params["id"])}

    {:error, errors} ->
      ErrorClassifier.classify_error(errors)
  end
end

@doc """
Takes note of a widget — a fact is recorded, nothing materializes
"""
@spec note_widget(map()) :: Architecture.public_api()
def note_widget(params) do
  case Catalog.dispatch(NoteWidget.new(params), consistency: :strong) do
    :ok -> :ok
    {:error, errors} -> ErrorClassifier.classify_error(errors)
  end
end

@doc """
Renames a widget and records the rename for the audit trail
"""
@spec relabel_widget(%{required(:id) => String.t(), required(:label) => String.t()}) :: Architecture.public_api(WidgetReadModel.t())
def relabel_widget(params) do
  case Catalog.dispatch(RelabelWidget.new(params), consistency: :strong) do
    :ok ->
      {:ok, WidgetInternal.widget_by_id(params[:id] || params["id"])}

    {:error, errors} ->
      ErrorClassifier.classify_error(errors)
  end
end

@doc """
List all widgets with filtering, sorting, and pagination
"""
@spec list_widgets(JSONAPI.Config.t()) :: Architecture.public_api([WidgetReadModel.t()])
def list_widgets(query) do
  {:ok, Repo.all(ListWidgets.new(query))}
end

@doc """
Retrieve a single widget by its id or slug
"""
@spec read_widget(String.t()) :: Architecture.public_api(WidgetReadModel.t())
def read_widget(id_or_slug) do
  case lookup_widget(id_or_slug) do
    nil -> {:error, :not_found}
    read_model -> {:ok, read_model}
  end
end

defp lookup_widget(id_or_slug) do
  if UuidValidator.valid_uuid?(id_or_slug) do
    WidgetInternal.widget_by_id(id_or_slug)
  else
    WidgetInternal.widget_by_slug(id_or_slug)
  end
end
end
