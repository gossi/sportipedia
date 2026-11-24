defmodule Sportipedia.Catalog.Equipment.Widget.Validators.UniqueSlug do
@moduledoc """
Validates that a widget slug is unique within the equipment.
"""
use Vex.Validator
alias Sportipedia.Catalog.Equipment.Widget.WidgetInternal
@doc """
Validates the given slug value.
"""
@spec validate(String.t(), map()) :: :ok | {:error, term()}
def validate(value, context) do
  with widget <- WidgetInternal.widget_by_slug(value),
       false <- is_nil(widget),
       false <- slug_belongs_to_widget?(widget, context) do
    {:error, :slug_exists}
  else
    _ -> :ok
  end
end

defp slug_belongs_to_widget?(widget, context) do
  id = Map.get(context, :id)

  id == widget.id
end
end
