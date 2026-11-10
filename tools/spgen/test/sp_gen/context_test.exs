defmodule SpGen.ContextTest do
  use ExUnit.Case, async: true

  alias SpGen.{Context, Esdm}

  @model_root Path.expand("../../docs/domain-model")

  setup_all do
    {:ok, model} = Esdm.load(@model_root)
    %{model: model}
  end

  defp ctx(model, name, opts \\ []) do
    element = Esdm.resolve!(model, name)
    {:ok, ctx} = Context.build(model, element, opts)
    ctx
  end

  describe "location inference" do
    test "subdomain/composite from the model path, constituent from scope", %{model: model} do
      c = ctx(model, "command.catalog-apparatus")
      assert {c.subdomain, c.composite, c.constituent} == {"catalog", "equipment", "apparatus"}
    end

    test "query takes the read model as constituent", %{model: model} do
      c = ctx(model, "query.read-apparatus")
      assert c.constituent == "apparatus"
      assert c.composite == "equipment"
    end

    test "args override inference", %{model: model} do
      c = ctx(model, "command.catalog-apparatus", subdomain: "catalogue", constituent: "widget")
      assert c.subdomain == "catalogue"
      assert c.constituent == "widget"
    end

    test "unresolvable location is an error", %{model: model} do
      actor = Esdm.resolve!(model, "actor.user")
      # actors.esdm.yaml sits at the model root — no subdomain/composite there
      assert {:error, {:unknown_location, :subdomain}} = Context.build(model, actor, [])
    end

    test "a command without a declared operation stays undecided — nothing is guessed", %{
      model: model
    } do
      # the real model's apparatus commands predate the operation annotations —
      # the ctx keeps nil, and a *run* on such a command is refused by SpGen
      c = ctx(model, "command.catalog-apparatus")
      assert c.operation == nil
    end
  end

  describe "neighborhood" do
    test "aggregate, read model, published events, actors", %{model: model} do
      c = ctx(model, "command.catalog-apparatus")
      assert c.aggregate.name == "apparatus"
      assert c.read_model.name == "apparatus"
      assert [%{name: "apparatus-cataloged"}] = c.events
      assert c.actors == ["user"]
    end
  end

  describe "fields by operation" do
    test "create injects the generated id first, internal", %{model: model} do
      c = ctx(model, "command.catalog-apparatus", operation: :create)
      assert Enum.map(c.fields, & &1.name) == ["id", "title", "slug", "description"]

      assert [id | rest] = c.fields
      assert id.required and id.internal
      assert Enum.map(rest, & &1.internal) == [false, false, false]
      assert Enum.map(rest, & &1.required) == [true, true, false]
    end

    test "update: id is caller-provided, data fields stay partial", %{model: model} do
      c = ctx(model, "command.edit-apparatus", operation: :update)
      # no `required` list in the model → optional fields sort alphabetically
      assert Enum.map(c.fields, & &1.name) == ["id", "description", "slug", "title"]
      assert hd(c.fields).required and not hd(c.fields).internal
      assert c.fields |> Enum.drop(1) |> Enum.map(& &1.required) == [false, false, false]
    end

    test "delete: id from data is kept (not injected)", %{model: model} do
      c = ctx(model, "command.archive-apparatus", operation: :delete)
      assert Enum.map(c.fields, & &1.name) == ["id"]
      assert hd(c.fields).required and not hd(c.fields).internal
    end

    test "event fields keep the declared id", %{model: model} do
      c = ctx(model, "event.apparatus-cataloged", operation: :create)
      assert Enum.map(c.fields, & &1.name) == ["id", "title", "slug", "description"]
    end
  end

  describe "validators (invariant patterns resolved over invariants and constraints)" do
    test "unique invariant maps to its field, allow_nil style :unique", %{model: model} do
      c = ctx(model, "command.catalog-apparatus", operation: :create)

      assert [%{name: "unique-slug", field: "slug", kind: :unique, module: "UniqueSlug"}] =
               c.validators
    end

    test "command exists-constraint maps to :id", %{model: model} do
      c = ctx(model, "command.edit-apparatus", operation: :update)
      assert Enum.map(c.validators, & &1.name) == ["apparatus-exists", "unique-slug"]

      exists = Enum.find(c.validators, &(&1.name == "apparatus-exists"))
      assert exists.field == "id"
      assert exists.kind == :exists
      assert exists.module == "ApparatusExists"
    end

    test "an invariant that guards no field generates no validator", %{model: model} do
      c = ctx(model, "command.catalog-apparatus", operation: :create)
      # the no-archive-when-in-use invariant references no command field
      refute Enum.any?(c.validators, &(&1.name == "no-archive-when-in-use"))

      # … and is not silently dropped: the model named a rule no pattern claims
      assert [%{"name" => "no-archive-when-in-use"}] = c.unresolved
    end

    test "archive command keeps only the exists validator", %{model: model} do
      c = ctx(model, "command.archive-apparatus", operation: :delete)
      assert [%{field: "id", kind: :exists}] = c.validators
    end

    test "unresolved/1 names only the rules no element of the citizen can realize", %{
      model: model
    } do
      # `unique-slug` names `slug`, which catalog-apparatus carries and realizes,
      # so archive-apparatus does not report it — the rule is the citizen's
      # business where the citizen can express it, not this element's problem
      archive = ctx(model, "command.archive-apparatus", operation: :delete)

      assert [{"no-archive-when-in-use", rule}] = Context.unresolved(archive)
      assert rule =~ "no sport references it"

      assert [{"no-archive-when-in-use", _}] =
               Context.unresolved(ctx(model, "aggregate.apparatus"))
    end
  end

  describe "publishing_commands/1" do
    test "finds the commands publishing an event, deterministically", %{model: model} do
      c = ctx(model, "event.apparatus-cataloged")
      assert Enum.map(Context.publishing_commands(c), & &1.name) == ["catalog-apparatus"]
    end

    test "non-event contexts have none", %{model: model} do
      c = ctx(model, "command.catalog-apparatus")
      assert Context.publishing_commands(c) == []
    end
  end

  describe "render" do
    test "fills vars and slots, raises on unknowns", %{model: model} do
      c = ctx(model, "command.catalog-apparatus")

      assert Context.render(
               "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Command.<Command> do",
               c
             ) =~ "Sportipedia.Catalog.Equipment.Apparatus.Command.CatalogApparatus do"

      assert Context.render("<field type>", c) == "String.t()"

      assert_context_raise = fn -> Context.render("<nonsense here>", c) end
      assert_raise ArgumentError, assert_context_raise
    end

    test "aggregate-driven generators self-link (validator sees the aggregate's invariants)", %{
      model: model
    } do
      {:ok, aggregate} = Esdm.resolve(model, "aggregate.apparatus")
      assert {:error, :not_found} = Esdm.aggregate_of(model, aggregate)

      {:ok, c} = Context.build(model, aggregate)
      assert c.aggregate.name == "apparatus"

      # invariants of the aggregate + constraints of its commands, deduped:
      # unique-slug (invariant) + apparatus-exists (archive/edit commands)
      modules = Enum.map(c.validators, & &1.module)
      assert "UniqueSlug" in modules
      assert "ApparatusExists" in modules
    end

    test "extra vars override (event writing into its command's test file)", %{model: model} do
      c = ctx(model, "event.apparatus-cataloged")

      assert Context.render(
               "services/api/test/sportipedia/<_subdomain>/<composite>/<domain_object>/operation/<_operation>_test.exs",
               c,
               %{"operation" => "catalog-apparatus"}
             ) ==
               "services/api/test/sportipedia/catalog/equipment/apparatus/operation/catalog_apparatus_test.exs"
    end
  end

  describe "generated fixtures (the read model's schema.examples)" do
    test "the primary example names the fixture and factory for its constituent", %{
      model: model
    } do
      c = ctx(model, "command.catalog-apparatus")
      assert Context.fixtures?(c)

      fixture = Context.fixture(c)
      assert fixture.module == "Sportipedia.TestSupport.Catalog.Equipment.ApparatusFixtures"
      assert fixture.local == "ApparatusFixtures"
      assert fixture.function == "parallel_bars"
      assert fixture.plural == "apparatuses"
      assert fixture.seed_module == "Sportipedia.TestSupport.Catalog.Equipment"
      assert fixture.seed_function == "new_apparatus"
      assert fixture.seed_all_function == "new_apparatuses"
      assert fixture.file =~ "test/support/catalog/equipment/fixtures/apparatuses.ex"
      assert fixture.seed_file =~ "test/support/catalog/equipment/equipment.ex"
    end

    test "the same fixture is named from a command, an event and a query context", %{
      model: model
    } do
      names =
        for name <- [
              "command.catalog-apparatus",
              "event.apparatus-cataloged",
              "query.read-apparatus"
            ] do
          model |> ctx(name) |> Context.fixture() |> Map.fetch!(:function)
        end

      assert names == ["parallel_bars", "parallel_bars", "parallel_bars"]
    end

    test "the seed expressions call the factory with the fixture", %{model: model} do
      fixture = model |> ctx("command.catalog-apparatus") |> Context.fixture()

      assert Context.seed_expr(fixture) ==
               "Equipment.new_apparatus(ApparatusFixtures.parallel_bars())"

      assert Context.seed_all_expr(fixture) ==
               "Equipment.new_apparatuses(ApparatusFixtures.apparatuses())"
    end

    test "example values are materialized source; absent fields return nil", %{model: model} do
      c = ctx(model, "command.catalog-apparatus")

      assert Context.example_value(c, "id") ==
               ~S|UUID.uuid5(:dns, "equipment:apparatus:parallel-bars")|

      assert Context.example_value(c, "title") == ~S|"Parallel Bars"|
      assert Context.example_value(c, "nonexistent") == nil
    end

    test "an element whose read model declares no examples reports none", %{model: model} do
      c = %{ctx(model, "command.catalog-apparatus") | read_model: nil}

      refute Context.fixtures?(c)
      assert Context.fixture(c) == nil
      assert Context.example_value(c, "id") == nil
    end
  end
end
