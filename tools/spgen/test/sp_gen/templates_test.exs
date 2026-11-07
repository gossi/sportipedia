defmodule SpGen.TemplatesTest do
  use ExUnit.Case, async: true

  alias SpGen.{Context, Esdm, Templates}

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

  describe "field_line/1" do
    test "required fields enforce, optional don't" do
      assert Templates.field_line(%{name: "title", type: "string", required: true}) ==
               "field :title, String.t(), enforce: true"

      assert Templates.field_line(%{name: "description", type: "string", required: false}) ==
               "field :description, String.t()"
    end

    test "uuid formats render as strings" do
      assert Templates.field_line(%{name: "id", type: "string", format: "uuid", required: true}) ==
               "field :id, String.t(), enforce: true"
    end
  end

  describe "validates_line/2" do
    test "presence only" do
      assert Templates.validates_line(%{name: "title", required: true, internal: false}, []) ==
               "validates :title, presence: true"
    end

    test "unique validator adds presence and allow_nil" do
      field = %{name: "slug", required: true, internal: false}
      validators = [%{field: "slug", kind: :unique, module: "UniqueSlug"}]

      assert Templates.validates_line(field, validators) ==
               "validates :slug, presence: true, by: [function: &UniqueSlug.validate/2, allow_nil: true]"
    end

    test "partial field with unique validator omits presence" do
      field = %{name: "slug", required: false, internal: false}
      validators = [%{field: "slug", kind: :unique, module: "UniqueSlug"}]

      assert Templates.validates_line(field, validators) ==
               "validates :slug, by: [function: &UniqueSlug.validate/2, allow_nil: true]"
    end

    test "exists validator adds presence and allow_blank" do
      field = %{name: "id", required: true, internal: false}
      validators = [%{field: "id", kind: :exists, module: "ApparatusExists"}]

      # `allow_blank` covers nil AND empty (`Vex.Blank.blank?/1`): the by-id
      # lookup is `Repo.get/2`, which raises on both — and a `:not_found` for a
      # blank id would collapse into a whole-command 404 instead of this 422
      assert Templates.validates_line(field, validators) ==
               "validates :id, presence: true, by: [function: &ApparatusExists.validate/2, allow_blank: true]"
    end

    test "two validators on one field are two `by:` pairs in ONE call" do
      field = %{name: "apparatusId", required: false, internal: false}

      validators = [
        %{field: "apparatusId", kind: :rule, module: "AtMostOneEquipment"},
        %{field: "apparatusId", kind: :rule, module: "EquipmentExists"}
      ]

      # A generated rule pair carries `allow_nil: true` on a field the model
      # does not require: the scaffold raises on any value — nil included — and
      # an implemented rule body may inspect the value before the context. The
      # operator who finishes the body into a pure cross-field check may drop
      # the skip option again; the needle below does not read it.
      assert Templates.validates_line(field, validators) ==
               "validates :apparatusId, " <>
                 "by: [function: &AtMostOneEquipment.validate/2, allow_nil: true], " <>
                 "by: [function: &EquipmentExists.validate/2, allow_nil: true]"
    end

    test "presence and two validators share the line" do
      field = %{name: "id", required: true, internal: false}

      validators = [
        %{field: "id", kind: :exists, module: "WidgetExists"},
        %{field: "id", kind: :rule, module: "NotInUse"}
      ]

      # `id` is required, so the rule pair gets no skip option: `enforce: true`
      # means the struct cannot even be built without a value here.
      assert Templates.validates_line(field, validators) ==
               "validates :id, presence: true, by: [function: &WidgetExists.validate/2, allow_blank: true], " <>
                 "by: [function: &NotInUse.validate/2]"
    end

    test "the pair text and the needle a line must contain" do
      unique = %{field: "slug", kind: :unique, module: "UniqueSlug"}
      exists = %{field: "id", kind: :exists, module: "WidgetExists"}
      rule = %{field: "coachId", kind: :rule, module: "AtMostOneOwner"}

      assert Templates.validates_by_pair(unique, %{name: "slug", required: false, internal: false}) ==
               "by: [function: &UniqueSlug.validate/2, allow_nil: true]"

      assert Templates.validates_by_pair(exists, %{name: "id", required: true, internal: false}) ==
               "by: [function: &WidgetExists.validate/2, allow_blank: true]"

      assert Templates.validates_by_pair(rule, %{
               name: "coachId",
               required: false,
               internal: false
             }) ==
               "by: [function: &AtMostOneOwner.validate/2, allow_nil: true]"

      assert Templates.validates_by_pair(rule, %{name: "coachId", required: true, internal: false}) ==
               "by: [function: &AtMostOneOwner.validate/2]"

      assert Templates.validates_needle(unique) == "&UniqueSlug.validate/2"

      assert Templates.validators_for(%{name: "id"}, [exists]) == [exists]
      assert Templates.validates_presence?(%{required: true, internal: false})
      refute Templates.validates_presence?(%{required: true, internal: true})
      refute Templates.validates_presence?(%{required: false, internal: false})
    end

    test "internal id (generated by the public API) is not presence-validated" do
      field = %{name: "id", required: true, internal: true}
      assert Templates.validates_line(field, []) == nil
    end

    test "optional field without validator has no line" do
      assert Templates.validates_line(
               %{name: "description", required: false, internal: false},
               []
             ) == nil
    end
  end

  describe "against the real apparatus model" do
    test "catalog-apparatus (create) produces the exact real-world lines", %{model: model} do
      c = ctx(model, "command.catalog-apparatus", operation: :create)

      assert Templates.validates_lines(c) == [
               "validates :title, presence: true",
               "validates :slug, presence: true, by: [function: &UniqueSlug.validate/2, allow_nil: true]"
             ]
    end

    # these are the shape the position reference commands carry; the committed
    # apparatus commands predate the fix and still lack `allow_blank` (blast
    # radius of the generator defect — the tool never rewrites them)
    test "edit-apparatus (update) produces the guarded exists line", %{model: model} do
      c = ctx(model, "command.edit-apparatus", operation: :update)

      assert Templates.validates_lines(c) == [
               "validates :id, presence: true, by: [function: &ApparatusExists.validate/2, allow_blank: true]",
               "validates :slug, by: [function: &UniqueSlug.validate/2, allow_nil: true]"
             ]
    end

    test "archive-apparatus (delete) produces the guarded exists line", %{model: model} do
      c = ctx(model, "command.archive-apparatus", operation: :delete)

      assert Templates.validates_lines(c) == [
               "validates :id, presence: true, by: [function: &ApparatusExists.validate/2, allow_blank: true]"
             ]
    end

    test "field lines match the real command structs", %{model: model} do
      c = ctx(model, "command.catalog-apparatus", operation: :create)

      assert Enum.map(c.fields, &Templates.field_line/1) == [
               "field :id, String.t(), enforce: true",
               "field :title, String.t(), enforce: true",
               "field :slug, String.t(), enforce: true",
               "field :description, String.t()"
             ]
    end
  end

  describe "sample_value/2" do
    test "id is a uuid expression" do
      c = ctx(setup_model(), "command.catalog-apparatus")
      assert Templates.sample_value(c, %{name: "id"}) == "UUID.uuid4()"
    end

    test "scenario values are preferred and quoted", %{model: model} do
      c = ctx(model, "command.catalog-apparatus", operation: :create)

      assert Templates.sample_value(c, %{name: "title", type: "string", required: true}) ==
               ~S|"Vaulting Table"|
    end

    test "falls back to quoted sample strings", %{model: model} do
      c = ctx(model, "command.catalog-apparatus", operation: :create)

      assert Templates.sample_value(c, %{name: "label", type: "string", required: true}) ==
               ~S|"sample-label"|
    end
  end

  describe "struct_body/2" do
    test "lists fields in order with overrides" do
      c = ctx(setup_model(), "command.catalog-apparatus", operation: :create)
      body = Templates.struct_body(c, %{"title" => "nil"})
      assert body =~ "id: UUID.uuid4()"
      assert body =~ "title: nil"
      assert body =~ "slug: \"vaulting-table\""
    end
  end

  describe "indent/2" do
    test "pads non-empty lines only" do
      assert Templates.indent("a\n\nb", 2) == "  a\n\n  b"
    end
  end

  defp setup_model do
    {:ok, model} = Esdm.load(@model_root)
    model
  end
end
