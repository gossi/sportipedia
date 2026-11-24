defmodule Sportipedia.Catalog.Equipment.Widget.WidgetProjector do
@moduledoc """
Projects widget events to the widget read model.
"""
  use Commanded.Projections.Ecto,
    application: Sportipedia.Catalog,
    repo: Sportipedia.Catalog.Repo,
    name: "equipment.widget_projection",
    schema_prefix: "catalog",
    consistency: :strong
alias Sportipedia.Catalog.Equipment.Widget.Event.WidgetArchived
alias Sportipedia.Catalog.Equipment.Widget.Event.WidgetCreated
alias Sportipedia.Catalog.Equipment.Widget.Event.WidgetEdited
alias Sportipedia.Catalog.Equipment.Widget.Event.WidgetNoted
alias Sportipedia.Catalog.Equipment.Widget.Event.WidgetRelabelled
alias Sportipedia.Catalog.Equipment.Widget.Event.WidgetRenameLogged
alias Sportipedia.Catalog.Equipment.Widget.WidgetInternal
alias Sportipedia.Catalog.Equipment.Widget.WidgetReadModel
@doc """
Projects an WidgetArchived event to hard-delete the widget read model.
"""
project %WidgetArchived{} = event, _metadata, fn multi ->
  case WidgetInternal.widget_by_id(event.id) do
    nil ->
      multi

    %WidgetReadModel{} = widget ->
      multi
      |> Ecto.Multi.delete(:widget_archived, widget)
  end
end
@doc """
Projects an WidgetCreated event to the widget read model.
"""
project %WidgetCreated{} = event, _metadata, fn multi ->
  multi
  |> Ecto.Multi.insert(
    :widget_created,
    WidgetReadModel.insert_changeset(%WidgetReadModel{}, Map.from_struct(event))
  )
end
@doc """
Projects an WidgetEdited event to update the widget read model.
"""
project %WidgetEdited{} = event, _metadata, fn multi ->
  case WidgetInternal.widget_by_id(event.id) do
    nil ->
      multi

    %WidgetReadModel{} = widget ->
      attrs = WidgetEdited.get_changes(event)

      multi
      |> Ecto.Multi.update(
        :widget_edited,
        WidgetReadModel.update_changeset(widget, attrs)
      )
  end
end
@doc """
Projects an WidgetRelabelled event to update the widget read model.
"""
project %WidgetRelabelled{} = event, _metadata, fn multi ->
  case WidgetInternal.widget_by_id(event.id) do
    nil ->
      multi

    %WidgetReadModel{} = widget ->
      attrs = WidgetRelabelled.get_changes(event)

      multi
      |> Ecto.Multi.update(
        :widget_relabelled,
        WidgetReadModel.update_changeset(widget, attrs)
      )
  end
end
end
