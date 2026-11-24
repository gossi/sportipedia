defmodule Sportipedia.Catalog.Equipment.Widget.Command.CreateWidgetHandler do
@moduledoc """
Handles the CreateWidget command.
"""
alias Sportipedia.Catalog.Equipment.Widget.Command.CreateWidget
alias Sportipedia.Catalog.Equipment.Widget.Event.WidgetCreated
alias Sportipedia.Catalog.Equipment.Widget.WidgetAggregate
@behaviour Commanded.Commands.Handler
@doc """
Handles the CreateWidget command and returns WidgetCreated event(s).
"""
@spec handle(WidgetAggregate.t(), CreateWidget.t()) :: WidgetCreated.t() | [WidgetCreated.t()]
def handle(%WidgetAggregate{} = aggregate, %CreateWidget{} = cmd) do
  # implement logic here
  # return events
end
end
