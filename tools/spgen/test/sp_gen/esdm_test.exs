defmodule SpGen.EsdmTest do
  use ExUnit.Case, async: true

  alias SpGen.Esdm
  alias SpGen.Esdm.Element

  # test files run with cwd = services/api
  @model_root Path.expand("../../docs/domain-model")

  setup_all do
    {:ok, model} = Esdm.load(@model_root)
    %{model: model}
  end

  @command_ref "esdm:domain=sport/bounded-context=sport/aggregate=apparatus/command=catalog-apparatus"
  @event_ref "esdm:domain=sport/bounded-context=sport/aggregate=apparatus/event=apparatus-cataloged"

  describe "load/index" do
    test "indexes all kinds of the real model", %{model: model} do
      kinds = model.elements |> Enum.map(& &1.kind) |> Enum.uniq() |> Enum.sort()
      assert :command in kinds
      assert :event in kinds
      assert :aggregate in kinds
      assert :"read-model" in kinds
      assert :query in kinds
      assert :feature in kinds
    end

    test "every element carries a reference, kind/name and scope", %{model: model} do
      for e <- model.elements do
        assert e.address =~ ~r/^esdm:domain=[a-z-]+/
        assert e.kind && e.name && is_list(e.scope) && e.source =~ ".esdm.yaml"
      end
    end
  end

  describe "reference building" do
    test "command reference is the serialized document head", %{model: model} do
      {:ok, element} = Esdm.resolve(model, @command_ref)
      assert element.address == @command_ref
      assert element.kind == :command
      assert element.name == "catalog-apparatus"

      assert element.scope == [
               {"domain", "sport"},
               {"bounded-context", "sport"},
               {"aggregate", "apparatus"}
             ]
    end

    test "domain carries no scope", %{model: model} do
      {:ok, element} = Esdm.resolve(model, "esdm:domain=sport")
      assert element.kind == :domain
      assert element.scope == []
    end

    test "bounded-context, subdomain and event references resolve", %{model: model} do
      assert {:ok, %{kind: :"bounded-context"}} =
               Esdm.resolve(model, "esdm:domain=sport/bounded-context=sport")

      assert {:ok, %{kind: :subdomain, name: "catalog"}} =
               Esdm.resolve(model, "esdm:domain=sport/subdomain=catalog")

      assert {:ok, %{kind: :event, name: "apparatus-cataloged"}} = Esdm.resolve(model, @event_ref)
    end
  end

  describe "resolve/2 address forms" do
    test "bare name", %{model: model} do
      assert {:ok, element} = Esdm.resolve(model, "catalog-apparatus")
      assert element.kind == :command
    end

    test "kind.name", %{model: model} do
      assert {:ok, element} = Esdm.resolve(model, "command.catalog-apparatus")
      assert element.kind == :command
    end

    test "file path", %{model: model} do
      file = Path.join(@model_root, "catalog/equipment/command.catalog-apparatus.esdm.yaml")
      assert {:ok, element} = Esdm.resolve(model, file)
      assert element.name == "catalog-apparatus"
    end

    test "relative file path", %{model: model} do
      rel =
        Path.relative_to(
          Path.join(@model_root, "catalog/equipment/command.catalog-apparatus.esdm.yaml"),
          File.cwd!()
        )

      assert {:ok, element} = Esdm.resolve(model, rel)
      assert element.name == "catalog-apparatus"
    end

    test "bare names narrow to the caller's kinds", %{model: model} do
      # "apparatus" exists as aggregate and read-model
      assert {:ok, %{kind: :aggregate}} =
               Esdm.resolve(model, "apparatus", kinds: [:aggregate, :command, :event])

      assert {:ok, %{kind: :"read-model"}} =
               Esdm.resolve(model, "apparatus", kinds: [:"read-model"])
    end

    test "a name only in foreign kinds reports kind_mismatch with pointers", %{model: model} do
      assert {:error, {:kind_mismatch, "apparatus", [:query], found}} =
               Esdm.resolve(model, "apparatus", kinds: [:query])

      assert found |> Enum.map(& &1.kind) |> Enum.sort() == [:aggregate, :"read-model"]

      hint = Esdm.format_error({:kind_mismatch, "apparatus", [:query], found})
      assert hint =~ "read-model.apparatus"
      assert hint =~ "esdm:domain=sport/bounded-context=sport/read-model=apparatus"
    end

    test "genuine ambiguity survives narrowing", %{model: model} do
      # internal_api legitimately drives from both kinds — the caller must pick
      assert {:error, {:ambiguous, addresses}} =
               Esdm.resolve(model, "apparatus", kinds: [:"read-model", :aggregate])

      assert length(addresses) == 2
    end

    test "ambiguous bare name lists esdm: references", %{model: model} do
      # "apparatus" is an aggregate AND a read model — allowed to coexist
      assert {:error, {:ambiguous, addresses}} = Esdm.resolve(model, "apparatus")
      assert Enum.any?(addresses, &String.contains?(&1, "aggregate=apparatus"))
      assert Enum.any?(addresses, &String.contains?(&1, "read-model=apparatus"))
    end

    test "multi-document file is refused with the candidates", %{model: model} do
      file = Path.join(@model_root, "actors.esdm.yaml")
      assert {:error, {:ambiguous_file, ^file, elements}} = Esdm.resolve(model, file)
      assert length(elements) == 3
    end

    test "unknown things error", %{model: model} do
      assert {:error, {:unknown_element, "no-such-thing"}} = Esdm.resolve(model, "no-such-thing")
      assert {:error, {:unknown_reference, _}} = Esdm.resolve(model, @command_ref <> "x")
      assert {:error, {:file_not_in_model, _}} = Esdm.resolve(model, "some/other.esdm.yaml")
      assert {:error, {:invalid_reference_segment, _}} = Esdm.resolve(model, "esdm:domain-sport")
    end

    test "resolve! raises a readable message", %{model: model} do
      assert_raise RuntimeError, ~r/cannot resolve "apparatus".*ambiguous/, fn ->
        Esdm.resolve!(model, "apparatus")
      end
    end
  end

  describe "neighborhood" do
    test "aggregate_of and read_model_for", %{model: model} do
      {:ok, command} = Esdm.resolve(model, @command_ref)

      assert {:ok, %{kind: :aggregate, name: "apparatus"}} = Esdm.aggregate_of(model, command)

      assert {:ok, %{kind: :"read-model", name: "apparatus"}} =
               Esdm.read_model_for(model, command)
    end

    test "query resolves its read model", %{model: model} do
      {:ok, query} = Esdm.resolve(model, "query.list-apparatuses")
      assert {:ok, %{name: "apparatus"}} = Esdm.read_model_for(model, query)
    end

    test "publishes and actors", %{model: model} do
      {:ok, command} = Esdm.resolve(model, @command_ref)
      assert Esdm.publishes(command) == ["apparatus-cataloged"]
      assert Esdm.actors(command) == ["user"]
    end

    test "invariants of an aggregate, constraints of a command", %{model: model} do
      {:ok, aggregate} = Esdm.resolve(model, "aggregate.apparatus")
      names = aggregate |> Esdm.invariants() |> Enum.map(& &1["name"])
      assert "unique-slug" in names

      {:ok, edit} = Esdm.resolve(model, "command.edit-apparatus")
      assert Enum.any?(Esdm.constraints(edit), &(&1["name"] == "apparatus-exists"))
    end
  end

  describe "fields/1 canonical order" do
    test "command data: id-less, required first, optional alphabetical", %{model: model} do
      {:ok, command} = Esdm.resolve(model, @command_ref)
      fields = Esdm.fields(command)

      assert Enum.map(fields, & &1.name) == ["title", "slug", "description"]
      assert Enum.map(fields, & &1.required) == [true, true, false]
      assert hd(fields).description == "Name of the apparatus"
    end

    test "event data carries the generated id first", %{model: model} do
      {:ok, event} = Esdm.resolve(model, @event_ref)
      assert Enum.map(Esdm.fields(event), & &1.name) == ["id", "title", "slug", "description"]
    end

    test "array query result uses items", %{model: model} do
      {:ok, query} = Esdm.resolve(model, "query.list-apparatuses")
      assert Enum.map(Esdm.fields(query), & &1.name) == ["id", "title", "slug", "description"]
    end

    test "read model schema", %{model: model} do
      {:ok, rm} = Esdm.resolve(model, "read-model.apparatus")
      assert Enum.map(Esdm.fields(rm), & &1.name) == ["id", "title", "slug", "description"]
    end
  end

  describe "declared operations (metadata.annotations)" do
    defp annotated(annotations) do
      %SpGen.Esdm.Element{
        kind: :"read-model",
        name: "widget",
        scope: [{"domain", "sport"}, {"bounded-context", "sport"}],
        doc: %{"metadata" => %{"annotations" => annotations}},
        source: "docs/domain-model/catalog/equipment/read-model.widget.esdm.yaml",
        address: "esdm:domain=sport/bounded-context=sport/read-model=widget"
      }
    end

    test "operation.<event> keys become the decision map", %{model: _model} do
      rm =
        annotated(%{
          "spgen.operation.widget-created" => "create",
          "spgen.operation.widget-audited" => "none",
          "spgen.operation.widget-edited" => "deleted?"
        })

      assert Esdm.declared_effects(rm) == %{
               "widget-created" => :create,
               "widget-audited" => :none,
               "widget-edited" => :invalid
             }
    end

    test "keys of other shapes are not effects", %{model: _model} do
      rm =
        annotated(%{
          "spgen.operation" => "create",
          "spgen.operation." => "update",
          "author" => "someone"
        })

      assert Esdm.declared_effects(rm) == %{}
    end

    test "a command declares its operation, or declares nothing usable" do
      command = fn value ->
        %SpGen.Esdm.Element{
          kind: :command,
          name: "create-widget",
          scope: [{"domain", "sport"}, {"bounded-context", "sport"}, {"aggregate", "widget"}],
          doc: %{"metadata" => %{"annotations" => %{"spgen.operation" => value}}},
          source: "docs/domain-model/catalog/equipment/command.create-widget.esdm.yaml",
          address: "esdm:domain=sport/.../command=create-widget"
        }
      end

      assert Esdm.declared_operation(command.("update")) == :update
      # `none` is a decision everywhere: a command may dispatch facts that
      # materialize nothing
      assert Esdm.declared_operation(command.("none")) == :none
      assert Esdm.declared_operation(command.("install")) == nil
      assert Esdm.declared_operation(%{command.(nil) | doc: %{}}) == nil
    end
  end

  describe "scenarios/2" do
    test "finds the feature scenarios exercising the operation, model order", %{model: model} do
      {:ok, command} = Esdm.resolve(model, @command_ref)
      scenarios = Esdm.scenarios(model, command)

      # manage-apparatuses has the happy path plus two rejections
      assert Enum.map(scenarios, & &1["name"]) == [
               "catalog-apparatus",
               "catalog-apparatus-invalid-without-title",
               "catalog-apparatus-duplicate-slug"
             ]

      [happy | rejects] = scenarios
      assert get_in(happy, ["when", "data"])["title"] == "Vaulting Table"
      assert [%{"event" => "apparatus-cataloged"}] = get_in(happy, ["then", "events"])

      assert Enum.map(rejects, &get_in(&1, ["then", "rejection", "reason"])) == [
               "title must be present",
               "slug already exists"
             ]
    end
  end

  test "Element helpers", %{model: model} do
    {:ok, command} = Esdm.resolve(model, @command_ref)
    assert Element.aggregate_name(command) == "apparatus"
    assert Element.segment(command) == "command=catalog-apparatus"
    {:ok, query} = Esdm.resolve(model, "query.read-apparatus")
    assert Element.read_model_name(query) == "apparatus"
  end
end
