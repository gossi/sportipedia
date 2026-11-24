defmodule Sportipedia.Catalog.Equipment.Widget.Command.ArchiveWidgetHandler do
@moduledoc """
Handles the ArchiveWidget command.
"""
alias Sportipedia.Catalog.Equipment.Widget.Command.ArchiveWidget
alias Sportipedia.Catalog.Equipment.Widget.Event.WidgetArchived
alias Sportipedia.Catalog.Equipment.Widget.WidgetAggregate
@behaviour Commanded.Commands.Handler
@doc """
Handles the ArchiveWidget command and returns WidgetArchived event(s).
"""
@spec handle(WidgetAggregate.t(), ArchiveWidget.t()) :: WidgetArchived.t() | [WidgetArchived.t()]
def handle(%WidgetAggregate{} = aggregate, %ArchiveWidget{} = cmd) do
  # implement logic here
  # return events
end
end
