defmodule Sportipedia.Catalog.Equipment.Widget.Command.RelabelWidgetHandler do
@moduledoc """
Handles the RelabelWidget command.
"""
alias Sportipedia.Catalog.Equipment.Widget.Command.RelabelWidget
alias Sportipedia.Catalog.Equipment.Widget.Event.WidgetRelabelled
alias Sportipedia.Catalog.Equipment.Widget.Event.WidgetRenameLogged
alias Sportipedia.Catalog.Equipment.Widget.WidgetAggregate
@behaviour Commanded.Commands.Handler
@doc """
Handles the RelabelWidget command and returns WidgetRelabelled event(s).
"""
@spec handle(WidgetAggregate.t(), RelabelWidget.t()) :: WidgetRelabelled.t() | [WidgetRelabelled.t()]
def handle(%WidgetAggregate{} = aggregate, %RelabelWidget{} = cmd) do
  # implement logic here
  # return events
end
end
