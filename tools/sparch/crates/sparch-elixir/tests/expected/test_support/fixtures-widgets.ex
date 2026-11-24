defmodule Sportipedia.TestSupport.Catalog.Equipment.WidgetFixtures do
  @moduledoc """
  Test fixtures for the widget read model — generated from
  `docs/domain-model/catalog/equipment/read-model.widget.esdm.yaml` by `mix sp.gen.test_support read-model.widget`.

  The model's `schema.examples` are the source of truth: this file is a
  projection and is rewritten whole on every run. Declare fixtures in the
  domain model, not here.

  Ids materialize as `UUID.uuid5(:dns, "<composite>:<read-model>:<mnemonic>")`,
  so one mnemonic names one thing in every environment forever.
  """

  alias Sportipedia.Catalog.Equipment.Widget.WidgetReadModel

  @doc "The `equipment:widget:classic-widget` fixture."
  @spec classic_widget() :: WidgetReadModel.t()
  def classic_widget do
    %WidgetReadModel{
      id: UUID.uuid5(:dns, "equipment:widget:classic-widget"),
      title: "Classic Widget",
      slug: "classic-widget",
      coach_id: UUID.uuid5(:dns, "equipment:coach:head-coach"),
      description: "The original widget of the fixture world",
      label: "classic",
      team_id: UUID.uuid5(:dns, "equipment:team:first-team")
    }
  end

  @doc "The `equipment:widget:gadget-2000` fixture."
  @spec gadget_2000() :: WidgetReadModel.t()
  def gadget_2000 do
    %WidgetReadModel{
      id: UUID.uuid5(:dns, "equipment:widget:gadget-2000"),
      title: "Gadget 2000",
      slug: "gadget-2000",
      description: "A newer widget, unlabeled and unassigned"
    }
  end

  @doc "All widget fixtures, in model order."
  @spec widgets() :: [WidgetReadModel.t()]
  def widgets, do: [classic_widget(), gadget_2000()]
end
