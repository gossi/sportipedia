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
end
