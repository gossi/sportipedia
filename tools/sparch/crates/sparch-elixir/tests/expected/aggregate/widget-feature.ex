defmodule Sportipedia.Catalog.Equipment.Widget.WidgetAggregate do
@moduledoc """
A piece of gym apparatus a coach catalogs for later reference
"""
use TypedStruct
alias Sportipedia.Catalog.Equipment.Widget.Event.WidgetArchived
alias Sportipedia.Catalog.Equipment.Widget.Event.WidgetCreated
alias Sportipedia.Catalog.Equipment.Widget.Event.WidgetEdited
alias Sportipedia.Catalog.Equipment.Widget.Event.WidgetNoted
alias Sportipedia.Catalog.Equipment.Widget.Event.WidgetRelabelled
alias Sportipedia.Catalog.Equipment.Widget.Event.WidgetRenameLogged
typedstruct do
field :id, String.t()
field :title, String.t()
field :slug, String.t()
field :archived_at, String.t()
field :coach_id, String.t()
field :description, String.t()
field :label, String.t()
field :team_id, String.t()
field :comment, String.t()
end
def apply(%__MODULE__{} = _aggregate, %WidgetArchived{} = _event) do
  nil
end
def apply(%__MODULE__{} = _aggregate, %WidgetCreated{} = event) do
  %__MODULE__{
      id: event.id,
      title: event.title,
      slug: event.slug,
      archived_at: event.archived_at,
      coach_id: event.coach_id,
      description: event.description,
      label: event.label,
      team_id: event.team_id
  }
end
def apply(%__MODULE__{} = aggregate, %WidgetEdited{} = event) do
  changes = WidgetEdited.get_changes(event)

  aggregate
  |> Map.merge(changes)
end
def apply(%__MODULE__{} = aggregate, %WidgetNoted{} = _event) do
  aggregate
end
def apply(%__MODULE__{} = aggregate, %WidgetRelabelled{} = event) do
  changes = WidgetRelabelled.get_changes(event)

  aggregate
  |> Map.merge(changes)
end
def apply(%__MODULE__{} = aggregate, %WidgetRenameLogged{} = _event) do
  aggregate
end
end
