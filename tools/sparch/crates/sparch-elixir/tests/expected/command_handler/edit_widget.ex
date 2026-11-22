defmodule Sportipedia.Catalog.Equipment.Widget.Command.EditWidgetHandler do
@moduledoc """
Handles the EditWidget command.
"""
alias Sportipedia.Catalog.Equipment.Widget.Command.EditWidget
alias Sportipedia.Catalog.Equipment.Widget.Event.WidgetEdited
alias Sportipedia.Catalog.Equipment.Widget.WidgetAggregate
@behaviour Commanded.Commands.Handler
@doc """
Handles the EditWidget command and returns WidgetEdited event(s).
"""
@spec handle(WidgetAggregate.t(), EditWidget.t()) :: WidgetEdited.t() | [WidgetEdited.t()]
def handle(%WidgetAggregate{} = aggregate, %EditWidget{} = cmd) do
  # implement logic here
  # return events
end
end
