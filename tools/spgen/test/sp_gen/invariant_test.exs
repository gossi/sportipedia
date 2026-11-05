defmodule SpGen.InvariantTest do
  @moduledoc """
  The invariant patterns: the executable counterpart of the example blueprints
  in `docs/architecture/blueprints/backend/domain/examples/`.

  A rule of the domain model resolves by its name and the fields the citizen
  carries — the shapes the examples show, a scaffold for the rest, and a rule
  that guards no field stays unresolved instead of quietly becoming nothing.
  """
  use ExUnit.Case, async: true

  alias SpGen.{Context, Esdm, Invariant}

  @model_root Path.expand("../../docs/domain-model")

  setup_all do
    {:ok, model} = Esdm.load(@model_root)
    %{model: model}
  end

  defp ctx(model, name) do
    element = Esdm.resolve!(model, name)
    {:ok, ctx} = Context.build(model, element)
    ctx
  end

  @slug %{"name" => "unique-slug", "rule" => "The slug for the apparatus must be unique"}
  @exists %{"name" => "apparatus-exists", "rule" => "An apparatus needs to exist (check by id)"}
  @in_use %{
    "name" => "no-archive-when-in-use",
    "rule" => "An apparatus can only be archived when no sport references it"
  }

  @fields ~w(id title slug description)

  describe "resolve/3 — unique-<field> (examples/unique-slug.md)" do
    test "the field is read from the rule's name" do
      assert %{kind: :unique, field: "slug", module: "UniqueSlug", snake: "unique_slug"} =
               Invariant.resolve(@slug, @fields, "apparatus")
    end

    test "a field the citizen does not carry is not this rule" do
      # `archive-apparatus` addresses an id: the slug invariant is not its guard
      assert Invariant.resolve(@slug, ~w(id), "apparatus") == nil
    end
  end

  describe "resolve/3 — <domain_object>-exists (examples/domain-object-exists.md)" do
    test "existence is checked by id" do
      assert %{kind: :exists, field: "id", module: "ApparatusExists"} =
               Invariant.resolve(@exists, @fields, "apparatus")
    end

    test "another domain object's existence is not this pattern" do
      # `equipment-exists` on a position guards a reference, not the citizen
      assert Invariant.resolve(
               %{"name" => "equipment-exists", "rule" => "must exist"},
               @fields,
               "position"
             ) ==
               nil
    end
  end

  describe "resolve/3 — a rule no example covers" do
    test "naming a field becomes a scaffold the operator implements" do
      rule = %{
        "name" => "at-most-one-equipment",
        "rule" => "A position can reference either apparatusId or instrumentId, not both"
      }

      assert %{kind: :rule, field: "apparatusId", module: "AtMostOneEquipment"} =
               Invariant.resolve(rule, ~w(id apparatusId instrumentId), "position")
    end

    test "naming no field is no validator" do
      assert Invariant.resolve(@in_use, @fields, "apparatus") == nil
    end
  end

  describe "resolve_all/3" do
    test "keeps input order and separates what no pattern claims" do
      {validators, unresolved} =
        Invariant.resolve_all([@slug, @in_use, @exists], @fields, "apparatus")

      assert Enum.map(validators, & &1.kind) == [:unique, :exists]
      assert unresolved == [@in_use]
    end

    test "the registered patterns are asked in order" do
      assert Invariant.patterns() == [
               SpGen.Invariant.UniqueField,
               SpGen.Invariant.DomainObjectExists,
               SpGen.Invariant.FieldRule
             ]
    end
  end

  describe "the domain model's own rules" do
    test "every invariant of the apparatus citizen resolves or stays visible", %{model: model} do
      c = ctx(model, "command.edit-apparatus")

      assert Enum.map(c.validators, & &1.name) == ["apparatus-exists", "unique-slug"]

      # the cross-aggregate precondition guards no field of this citizen
      assert Enum.map(c.unresolved, & &1["name"]) == ["no-archive-when-in-use"]
    end

    test "an aggregate-driven context sees its commands' constraints", %{model: model} do
      c = ctx(model, "aggregate.apparatus")

      assert c.validators |> Enum.map(& &1.kind) |> Enum.sort() == [:exists, :unique]
      assert Context.unique_fields(c) == ["slug"]
    end
  end
end
