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

  defp ctx(model, name, opts \\ []) do
    element = Esdm.resolve!(model, name)
    {:ok, ctx} = Context.build(model, element, opts)
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
      assert [%{kind: :unique, field: "slug", module: "UniqueSlug", snake: "unique_slug"}] =
               Invariant.resolve(@slug, @fields, "apparatus")
    end

    test "a field the citizen does not carry is not this rule" do
      # `archive-apparatus` addresses an id: the slug invariant is not its guard
      assert Invariant.resolve(@slug, ~w(id), "apparatus") == nil
    end
  end

  describe "resolve/3 — <domain_object>-exists (examples/domain-object-exists.md)" do
    test "existence is checked by id" do
      assert [%{kind: :exists, field: "id", module: "ApparatusExists"}] =
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
        "rule" => "A position can reference apparatusId, and nothing else of the sort"
      }

      assert [%{kind: :rule, field: "apparatusId", module: "AtMostOneEquipment"}] =
               Invariant.resolve(rule, ~w(id apparatusId instrumentId), "position")
    end

    test "naming several fields yields one descriptor per named field" do
      # The model states a rule once, and the rule speaks for every field it
      # names: `equipment-exists` guards the apparatus reference *and* the
      # instrument reference. Yielding only the first named field leaves the
      # other half of the rule unreachable for the generator, so a fresh build
      # would silently drop it (a validator body can name per-field clauses the
      # generator cannot know — the operator finishes them; the registration
      # may never disappear).
      rule = %{
        "name" => "equipment-exists",
        "rule" =>
          "If apparatusId or instrumentId is provided, the referenced equipment must exist"
      }

      descriptors =
        Invariant.resolve(rule, ~w(id title slug apparatusId instrumentId), "position")

      assert Enum.map(descriptors, &{&1.kind, &1.field, &1.module}) == [
               {:rule, "apparatusId", "EquipmentExists"},
               {:rule, "instrumentId", "EquipmentExists"}
             ]
    end

    test "a cross-field invariant registers on every field it merges" do
      rule = %{
        "name" => "at-most-one-equipment",
        "rule" =>
          "A position can reference at most one piece of equipment (either apparatusId or instrumentId, not both)"
      }

      descriptors = Invariant.resolve(rule, ~w(id apparatusId instrumentId), "position")

      assert Enum.map(descriptors, &{&1.name, &1.field}) == [
               {"at-most-one-equipment", "apparatusId"},
               {"at-most-one-equipment", "instrumentId"}
             ]
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
      # the apparatus commands predate operation annotations — the run-time
      # requirement is --template or metadata; a direct context asserts it
      c = ctx(model, "command.edit-apparatus", operation: :update)

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
