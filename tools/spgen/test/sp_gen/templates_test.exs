defmodule SpGen.TemplatesTest do
  use ExUnit.Case, async: true

  alias SpGen.{Context, Esdm, FixtureRepo, Templates}

  # the fixture model, never the live `docs/domain-model` (see `contributions.md`):
  # these are the exact lines the blueprint promises, and the fixtures state them
  # in their own domain — a model edit outside this tool must not read here
  setup_all do
    %{model: FixtureRepo.model()}
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

  describe "against the fixture model" do
    test "create-widget (create) produces the exact lines the blueprint promises", %{
      model: model
    } do
      c = ctx(model, "command.create-widget")

      assert Templates.validates_lines(c) == [
               "validates :title, presence: true",
               "validates :slug, presence: true, by: [function: &UniqueSlug.validate/2, allow_nil: true]",
               "validates :coachId, by: [function: &AtMostOneOwner.validate/2, allow_nil: true]",
               "validates :teamId, by: [function: &AtMostOneOwner.validate/2, allow_nil: true]"
             ]
    end

    test "edit-widget (update) produces the guarded exists line", %{model: model} do
      c = ctx(model, "command.edit-widget")

      # `allow_blank` covers nil AND empty, and an optional slug keeps presence
      # off while its unique guard stays on — the shape the reference commands
      # carry and the generator must never lose
      assert Templates.validates_lines(c) == [
               "validates :id, presence: true, by: [function: &WidgetExists.validate/2, allow_blank: true]",
               "validates :coachId, by: [function: &AtMostOneOwner.validate/2, allow_nil: true]",
               "validates :slug, by: [function: &UniqueSlug.validate/2, allow_nil: true]",
               "validates :teamId, by: [function: &AtMostOneOwner.validate/2, allow_nil: true]"
             ]
    end

    test "archive-widget (delete) carries nothing but the exists guard", %{model: model} do
      c = ctx(model, "command.archive-widget")

      assert Templates.validates_lines(c) == [
               "validates :id, presence: true, by: [function: &WidgetExists.validate/2, allow_blank: true]"
             ]
    end

    test "field lines match the command's data fields, in the model's order", %{model: model} do
      c = ctx(model, "command.create-widget")

      assert Enum.map(c.fields, &Templates.field_line/1) == [
               "field :id, String.t(), enforce: true",
               "field :title, String.t(), enforce: true",
               "field :slug, String.t(), enforce: true",
               "field :coachId, String.t()",
               "field :description, String.t()",
               "field :label, String.t()",
               "field :teamId, String.t()"
             ]
    end
  end

  describe "sample_value/2" do
    test "id is the fixture's deterministic uuid5, so a test row and its seed match", %{
      model: model
    } do
      c = ctx(model, "command.create-widget")

      assert Templates.sample_value(c, %{name: "id", format: "uuid"}) ==
               ~S|UUID.uuid5(:dns, "equipment:widget:classic-widget")|
    end

    test "id falls back to a uuid4 expression when the read model declares no example", %{
      model: model
    } do
      # an element whose read model has no examples has nothing to match against
      c = ctx(model, "command.create-widget")
      c = %{c | read_model: nil}

      assert Templates.sample_value(c, %{name: "id", format: "uuid"}) == "UUID.uuid4()"
    end

    test "scenario values are preferred and quoted", %{model: model} do
      c = ctx(model, "command.create-widget")

      assert Templates.sample_value(c, %{name: "title", type: "string", required: true}) ==
               ~S|"Pommel Horse"|
    end

    test "falls back to quoted sample strings", %{model: model} do
      # `note-widget` is a fact no scenario tells and no example carries
      c = ctx(model, "command.note-widget")

      assert Templates.sample_value(c, %{name: "comment", type: "string", required: true}) ==
               ~S|"sample-comment"|
    end
  end

  describe "struct_body/2" do
    test "lists fields in order with overrides" do
      c = ctx(FixtureRepo.model(), "command.create-widget")
      body = Templates.struct_body(c, %{"title" => "nil"})
      assert body =~ ~S|id: UUID.uuid5(:dns, "equipment:widget:classic-widget")|
      assert body =~ "title: nil"
      assert body =~ ~S|slug: "pommel-horse"|
    end
  end

  describe "indent/2" do
    test "pads non-empty lines only" do
      assert Templates.indent("a\n\nb", 2) == "  a\n\n  b"
    end
  end
end
