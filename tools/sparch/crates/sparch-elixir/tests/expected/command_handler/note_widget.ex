defmodule Sportipedia.Catalog.Equipment.Widget.Command.NoteWidgetHandler do
@moduledoc """
Handles the NoteWidget command.
"""
alias Sportipedia.Catalog.Equipment.Widget.Command.NoteWidget
alias Sportipedia.Catalog.Equipment.Widget.Event.WidgetNoted
alias Sportipedia.Catalog.Equipment.Widget.WidgetAggregate
@behaviour Commanded.Commands.Handler
@doc """
Handles the NoteWidget command and returns WidgetNoted event(s).
"""
@spec handle(WidgetAggregate.t(), NoteWidget.t()) :: WidgetNoted.t() | [WidgetNoted.t()]
def handle(%WidgetAggregate{} = aggregate, %NoteWidget{} = cmd) do
  # implement logic here
  # return events
end
end
