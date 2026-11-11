defmodule SpGen.ContextTest do
  @moduledoc """
  `SpGen.Context` over the **fixture** domain model (`fixtures/domain-model`):
  what a context resolves, derives and renders for one citizen.

  Never the live `docs/domain-model` — see `tools/spgen/contributions.md`.
  """
  use ExUnit.Case, async: true

  alias SpGen.{Context, Esdm, FixtureRepo}

  setup_all do
    %{model: FixtureRepo.model()}
  end

  defp ctx(model, name, opts \\ []) do
    element = Esdm.resolve!(model, name)
    {:ok, ctx} = Context.build(model, element, opts)
    ctx
  end

  describe "location inference" do
    test "subdomain/composite from the model path, constituent from scope", %{model: model} do
      c = ctx(model, "command.create-widget")
      assert {c.subdomain, c.composite, c.constituent} == {"catalog", "equipment", "widget"}
    end

    test "query takes the read model as constituent", %{model: model} do
      c = ctx(model, "query.read-widget")
      assert c.constituent == "widget"
      assert c.composite == "equipment"
    end

    test "args override inference", %{model: model} do
      c = ctx(model, "command.create-widget", subdomain: "catalogue", constituent: "gadget")
      assert c.subdomain == "catalogue"
      assert c.constituent == "gadget"
    end

    test "unresolvable location is an error", %{model: model} do
      actor = Esdm.resolve!(model, "actor.guest")
      # actors.esdm.yaml sits at the model root — no subdomain/composite there
      assert {:error, {:unknown_location, :subdomain}} = Context.build(model, actor, [])
    end

    test "a command without a declared operation stays undecided — nothing is guessed", %{
      model: model
    } do
      # the fixture commands all declare one, so the undecided case is stated by
      # removing the declaration: the ctx keeps nil, and a *run* on such a
      # command is refused by SpGen rather than resolved by guessing
      element = Esdm.resolve!(model, "command.create-widget")

      undecorated = %{
        element
        | doc:
            update_in(
              element.doc,
              ["metadata", "annotations"],
              &Map.delete(&1, "spgen.operation")
            )
      }

      {:ok, c} = Context.build(model, undecorated)
      assert c.operation == nil
    end
  end

  describe "neighborhood" do
    test "aggregate, read model, published events, actors", %{model: model} do
      c = ctx(model, "command.create-widget")
      assert c.aggregate.name == "widget"
      assert c.read_model.name == "widget"
      assert [%{name: "widget-created"}] = c.events
      assert c.actors == ["user"]
    end

    test "one command publishing two events carries both", %{model: model} do
      c = ctx(model, "command.relabel-widget")

      assert c.events |> Enum.map(& &1.name) |> Enum.sort() == [
               "widget-relabelled",
               "widget-rename-logged"
             ]
    end
  end

  describe "fields by operation" do
    test "create injects the generated id first, internal", %{model: model} do
      c = ctx(model, "command.create-widget")

      assert Enum.map(c.fields, & &1.name) == [
               "id",
               "title",
               "slug",
               "coachId",
               "description",
               "label",
               "teamId"
             ]

      assert [id | rest] = c.fields
      assert id.required and id.internal
      assert Enum.all?(rest, &(&1.internal == false))
      assert Enum.map(rest, & &1.required) == [true, true, false, false, false, false]
    end

    test "update: id is caller-provided, data fields stay partial", %{model: model} do
      c = ctx(model, "command.edit-widget")

      # `id` first because the command states it, then the optional data fields
      # in the model's canonical order
      assert Enum.map(c.fields, & &1.name) == [
               "id",
               "coachId",
               "description",
               "label",
               "slug",
               "teamId",
               "title"
             ]

      assert hd(c.fields).required and not hd(c.fields).internal
      assert c.fields |> Enum.drop(1) |> Enum.map(& &1.required) == List.duplicate(false, 6)
    end

    test "delete: id from data is kept (not injected)", %{model: model} do
      c = ctx(model, "command.archive-widget")
      assert Enum.map(c.fields, & &1.name) == ["id"]
      assert hd(c.fields).required and not hd(c.fields).internal
    end

    test "event fields keep the declared id", %{model: model} do
      c = ctx(model, "event.widget-created")
      assert "id" in Enum.map(c.fields, & &1.name)
    end
  end

  describe "validators (invariant patterns resolved over invariants and constraints)" do
    test "unique invariant maps to its field, allow_nil style :unique", %{model: model} do
      c = ctx(model, "command.create-widget")

      assert [%{name: "unique-slug", field: "slug", kind: :unique, module: "UniqueSlug"}] =
               Enum.filter(c.validators, &(&1.kind == :unique))
    end

    test "command exists-constraint maps to :id", %{model: model} do
      c = ctx(model, "command.edit-widget")

      exists = Enum.find(c.validators, &(&1.kind == :exists))
      assert exists.field == "id"
      assert exists.module == "WidgetExists"
      assert "widget-exists" in Enum.map(c.validators, & &1.name)
    end

    test "a rule naming two fields claims both", %{model: model} do
      c = ctx(model, "command.create-widget")

      assert c.validators
             |> Enum.filter(&(&1.name == "at-most-one-owner"))
             |> Enum.map(& &1.field) == ["coachId", "teamId"]
    end

    test "an invariant that guards no field generates no validator", %{model: model} do
      c = ctx(model, "command.create-widget")
      # the no-archive-when-in-use invariant references no command field
      refute Enum.any?(c.validators, &(&1.name == "no-archive-when-in-use"))

      # … and is not silently dropped: the model named a rule no pattern claims
      assert [%{"name" => "no-archive-when-in-use"}] = c.unresolved
    end

    test "archive command keeps only the exists validator", %{model: model} do
      c = ctx(model, "command.archive-widget")
      assert [%{field: "id", kind: :exists}] = c.validators
    end

    test "unresolved/1 names only the rules no element of the citizen can realize", %{
      model: model
    } do
      # `unique-slug` names `slug`, which create-widget carries and realizes, so
      # archive-widget does not report it — the rule is the citizen's business
      # where the citizen can express it, not this element's problem
      archive = ctx(model, "command.archive-widget")

      assert [{"no-archive-when-in-use", rule}] = Context.unresolved(archive)
      assert rule =~ "no sport references it"

      assert [{"no-archive-when-in-use", _}] = Context.unresolved(ctx(model, "aggregate.widget"))
    end
  end

  describe "publishing_commands/1" do
    test "finds the commands publishing an event, deterministically", %{model: model} do
      c = ctx(model, "event.widget-created")
      assert Enum.map(Context.publishing_commands(c), & &1.name) == ["create-widget"]
    end

    test "an event no command publishes has none", %{model: model} do
      c = ctx(model, "event.widget-rename-logged")

      assert Enum.map(Context.publishing_commands(c), & &1.name) == ["relabel-widget"]
    end

    test "non-event contexts have none", %{model: model} do
      c = ctx(model, "command.create-widget")
      assert Context.publishing_commands(c) == []
    end
  end

  describe "render" do
    test "fills vars and slots, raises on unknowns", %{model: model} do
      c = ctx(model, "command.create-widget")

      assert Context.render(
               "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Command.<Command> do",
               c
             ) =~ "Sportipedia.Catalog.Equipment.Widget.Command.CreateWidget do"

      assert Context.render("<field type>", c) == "String.t()"

      assert_context_raise = fn -> Context.render("<nonsense here>", c) end
      assert_raise ArgumentError, assert_context_raise
    end

    test "aggregate-driven generators self-link (validator sees the aggregate's invariants)", %{
      model: model
    } do
      {:ok, aggregate} = Esdm.resolve(model, "aggregate.widget")
      assert {:error, :not_found} = Esdm.aggregate_of(model, aggregate)

      {:ok, c} = Context.build(model, aggregate)
      assert c.aggregate.name == "widget"

      # invariants of the aggregate + constraints of its commands, deduped:
      # unique-slug (invariant) + widget-exists (the edit/archive commands)
      modules = Enum.map(c.validators, & &1.module)
      assert "UniqueSlug" in modules
      assert "WidgetExists" in modules
    end

    test "extra vars override (event writing into its command's test file)", %{model: model} do
      c = ctx(model, "event.widget-created")

      assert Context.render(
               "services/api/test/sportipedia/<_subdomain>/<composite>/<domain_object>/operation/<_operation>_test.exs",
               c,
               %{"operation" => "create-widget"}
             ) ==
               "services/api/test/sportipedia/catalog/equipment/widget/operation/create_widget_test.exs"
    end
  end

  # The one place a blueprint asks "is this a collection read?" is the context's
  # operation: declared by the model's `spgen.operation` when the model declares
  # it, else derived from `result.type`. Asking the shape as well would give one
  # decision two sources, and a `--template` override would mean nothing.
  describe "query operations and parameters" do
    test "a declared collection read is a collection", %{model: model} do
      c = ctx(model, "query.list-widgets")
      assert c.operation == :collection
      assert Context.collection?(c)
    end

    test "a read query is not a collection", %{model: model} do
      c = ctx(model, "query.read-widget")
      assert c.operation == :read
      refute Context.collection?(c)
    end

    test "--template wins over the declaration", %{model: model} do
      c = ctx(model, "query.list-widgets", operation: :read)
      refute Context.collection?(c)
    end

    test "filterable names are the filter's properties", %{model: model} do
      c = ctx(model, "query.list-widgets")
      assert Context.filterable_fields(c) == ["title"]
    end

    test "sortable names are the sort's own list, in its order", %{model: model} do
      c = ctx(model, "query.list-widgets")
      assert Context.sortable_fields(c) == ["title", "slug"]
    end

    test "a model naming no sortable fields sorts by what it filters", %{model: model} do
      element = Esdm.resolve!(model, "query.list-widgets")

      bare = %{
        element
        | doc: put_in(element.doc, ["parameters", "properties", "sort", "sortableFields"], nil)
      }

      {:ok, c} = Context.build(model, bare)
      assert Context.sortable_fields(c) == ["title"]
      assert Context.sortable_fields(c) == Context.filterable_fields(c)
    end

    test "the page style is the model's own keys", %{model: model} do
      # the fixture declares a `page` with no properties: number/size is the
      # house style the QueryBuilder defaults to
      assert ctx(model, "query.list-widgets") |> Context.page_style() == :numbered
    end

    test "the query module template renders from a query context", %{model: model} do
      c = ctx(model, "query.list-widgets")

      assert Context.render(
               "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Queries.<Query>",
               c
             ) == "Sportipedia.Catalog.Equipment.Widget.Queries.ListWidgets"
    end
  end

  describe "generated fixtures (the read model's schema.examples)" do
    test "the primary example names the fixture and factory for its constituent", %{
      model: model
    } do
      c = ctx(model, "command.create-widget")
      assert Context.fixtures?(c)

      fixture = Context.fixture(c)
      assert fixture.module == "Sportipedia.TestSupport.Catalog.Equipment.WidgetFixtures"
      assert fixture.local == "WidgetFixtures"
      assert fixture.function == "classic_widget"
      assert fixture.plural == "widgets"
      assert fixture.seed_module == "Sportipedia.TestSupport.Catalog.Equipment"
      assert fixture.seed_function == "new_widget"
      assert fixture.seed_all_function == "new_widgets"
      assert fixture.file =~ "test/support/catalog/equipment/fixtures/widgets.ex"
      assert fixture.seed_file =~ "test/support/catalog/equipment/equipment.ex"
    end

    test "the same fixture is named from a command, an event and a query context", %{
      model: model
    } do
      names =
        for name <- [
              "command.create-widget",
              "event.widget-created",
              "query.read-widget"
            ] do
          model |> ctx(name) |> Context.fixture() |> Map.fetch!(:function)
        end

      assert names == ["classic_widget", "classic_widget", "classic_widget"]
    end

    test "the seed expressions call the factory with the fixture", %{model: model} do
      fixture = model |> ctx("command.create-widget") |> Context.fixture()

      assert Context.seed_expr(fixture) == "Equipment.new_widget(WidgetFixtures.classic_widget())"

      assert Context.seed_all_expr(fixture) ==
               "Equipment.new_widgets(WidgetFixtures.widgets())"
    end

    test "example values are materialized source; absent fields return nil", %{model: model} do
      c = ctx(model, "command.create-widget")

      assert Context.example_value(c, "id") ==
               ~S|UUID.uuid5(:dns, "equipment:widget:classic-widget")|

      assert Context.example_value(c, "title") == ~S|"Classic Widget"|
      assert Context.example_value(c, "nonexistent") == nil
    end

    test "an element whose read model declares no examples reports none", %{model: model} do
      c = %{ctx(model, "command.create-widget") | read_model: nil}

      refute Context.fixtures?(c)
      assert Context.fixture(c) == nil
      assert Context.example_value(c, "id") == nil
    end
  end
end
