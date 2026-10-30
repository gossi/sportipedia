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

    test "unknown operation info errors, never guesses", %{model: model} do
      c = ctx(model, "command.catalog-apparatus")
      assert c.operation == :create
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

  describe "validators (from invariants and constraints)" do
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

    test "invariant without a matching field is dropped", %{model: model} do
      c = ctx(model, "command.catalog-apparatus", operation: :create)
      # the no-archive-when-in-use invariant references no command field
      refute Enum.any?(c.validators, &(&1.name == "no-archive-when-in-use"))
    end

    test "archive command keeps only the exists validator", %{model: model} do
      c = ctx(model, "command.archive-apparatus", operation: :delete)
      assert [%{field: "id", kind: :exists}] = c.validators
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
end
