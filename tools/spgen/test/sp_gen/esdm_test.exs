defmodule SpGen.EsdmTest do
  @moduledoc """
  The ESDM reader: loading, indexing, reference resolution and the model reads
  every blueprint depends on — all over the **fixture** model
  (`fixtures/domain-model`). Never the live `docs/domain-model`: see
  `tools/spgen/contributions.md`.
  """
  use ExUnit.Case, async: true

  alias SpGen.Esdm
  alias SpGen.Esdm.Element
  alias SpGen.FixtureRepo

  setup_all do
    %{model: FixtureRepo.model(), model_root: FixtureRepo.model_path()}
  end

  @command_ref "esdm:domain=sport/bounded-context=sport/aggregate=widget/command=create-widget"
  @event_ref "esdm:domain=sport/bounded-context=sport/aggregate=widget/event=widget-created"

  describe "load/index" do
    test "indexes every kind the fixture model holds", %{model: model} do
      kinds = model.elements |> Enum.map(& &1.kind) |> Enum.uniq() |> Enum.sort()

      for kind <- [
            :domain,
            :"bounded-context",
            :subdomain,
            :actor,
            :aggregate,
            :command,
            :event,
            :"read-model",
            :query,
            :feature
          ] do
        assert kind in kinds, "the fixture model must cover #{inspect(kind)}"
      end
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
      assert element.name == "create-widget"

      assert element.scope == [
               {"domain", "sport"},
               {"bounded-context", "sport"},
               {"aggregate", "widget"}
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

      assert {:ok, %{kind: :event, name: "widget-created"}} = Esdm.resolve(model, @event_ref)
    end
  end

  describe "resolve/2 address forms" do
    test "bare name", %{model: model} do
      assert {:ok, element} = Esdm.resolve(model, "create-widget")
      assert element.kind == :command
    end

    test "kind.name", %{model: model} do
      assert {:ok, element} = Esdm.resolve(model, "command.create-widget")
      assert element.kind == :command
    end

    test "file path", %{model: model, model_root: root} do
      file = Path.join(root, "catalog/equipment/command.create-widget.esdm.yaml")
      assert {:ok, element} = Esdm.resolve(model, file)
      assert element.name == "create-widget"
    end

    test "relative file path", %{model: model, model_root: root} do
      rel =
        Path.join(root, "catalog/equipment/command.create-widget.esdm.yaml")
        |> Path.relative_to(File.cwd!())

      assert {:ok, element} = Esdm.resolve(model, rel)
      assert element.name == "create-widget"
    end

    test "bare names narrow to the caller's kinds", %{model: model} do
      # "widget" exists as aggregate and read-model
      assert {:ok, %{kind: :aggregate}} =
               Esdm.resolve(model, "widget", kinds: [:aggregate, :command, :event])

      assert {:ok, %{kind: :"read-model"}} = Esdm.resolve(model, "widget", kinds: [:"read-model"])
    end

    test "a name only in foreign kinds reports kind_mismatch with pointers", %{model: model} do
      assert {:error, {:kind_mismatch, "widget", [:query], found}} =
               Esdm.resolve(model, "widget", kinds: [:query])

      assert found |> Enum.map(& &1.kind) |> Enum.sort() == [:aggregate, :"read-model"]

      hint = Esdm.format_error({:kind_mismatch, "widget", [:query], found})
      assert hint =~ "read-model.widget"
      assert hint =~ "esdm:domain=sport/bounded-context=sport/read-model=widget"
    end

    test "genuine ambiguity survives narrowing", %{model: model} do
      # internal_api legitimately drives from both kinds — the caller must pick
      assert {:error, {:ambiguous, addresses}} =
               Esdm.resolve(model, "widget", kinds: [:"read-model", :aggregate])

      assert length(addresses) == 2
    end

    test "ambiguous bare name lists esdm: references", %{model: model} do
      # "widget" is an aggregate AND a read model — allowed to coexist
      assert {:error, {:ambiguous, addresses}} = Esdm.resolve(model, "widget")
      assert Enum.any?(addresses, &String.contains?(&1, "aggregate=widget"))
      assert Enum.any?(addresses, &String.contains?(&1, "read-model=widget"))
    end

    test "multi-document file is refused with the candidates", %{model: model, model_root: root} do
      file = Path.join(root, "actors.esdm.yaml")
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
      assert_raise RuntimeError, ~r/cannot resolve "widget".*ambiguous/, fn ->
        Esdm.resolve!(model, "widget")
      end
    end
  end

  describe "neighborhood" do
    test "aggregate_of and read_model_for", %{model: model} do
      {:ok, command} = Esdm.resolve(model, @command_ref)

      assert {:ok, %{kind: :aggregate, name: "widget"}} = Esdm.aggregate_of(model, command)

      assert {:ok, %{kind: :"read-model", name: "widget"}} = Esdm.read_model_for(model, command)
    end

    test "query resolves its read model", %{model: model} do
      {:ok, query} = Esdm.resolve(model, "query.list-widgets")
      assert {:ok, %{name: "widget"}} = Esdm.read_model_for(model, query)
    end

    test "publishes and actors", %{model: model} do
      {:ok, command} = Esdm.resolve(model, @command_ref)
      assert Esdm.publishes(command) == ["widget-created"]
      assert Esdm.actors(command) == ["user"]
    end

    test "invariants of an aggregate, constraints of a command", %{model: model} do
      {:ok, aggregate} = Esdm.resolve(model, "aggregate.widget")
      names = aggregate |> Esdm.invariants() |> Enum.map(& &1["name"])
      assert "unique-slug" in names

      {:ok, edit} = Esdm.resolve(model, "command.edit-widget")
      assert Enum.any?(Esdm.constraints(edit), &(&1["name"] == "widget-exists"))
    end
  end

  describe "fields/1 canonical order" do
    test "command data: id-less, required first, optional alphabetical", %{model: model} do
      {:ok, command} = Esdm.resolve(model, @command_ref)
      fields = Esdm.fields(command)

      assert Enum.map(fields, & &1.name) == [
               "title",
               "slug",
               "coachId",
               "description",
               "label",
               "teamId"
             ]

      assert Enum.map(fields, & &1.required) == [true, true, false, false, false, false]
      assert hd(fields).description == "Name of the widget"
    end

    test "event data carries the generated id first", %{model: model} do
      {:ok, event} = Esdm.resolve(model, @event_ref)

      assert Enum.map(Esdm.fields(event), & &1.name) == [
               "id",
               "title",
               "slug",
               "coachId",
               "description",
               "label",
               "teamId"
             ]
    end

    test "array query result uses items", %{model: model} do
      {:ok, query} = Esdm.resolve(model, "query.list-widgets")
      assert Enum.map(Esdm.fields(query), & &1.name) == ["id", "title", "slug", "label"]
    end

    test "read model schema", %{model: model} do
      {:ok, rm} = Esdm.resolve(model, "read-model.widget")

      assert Enum.map(Esdm.fields(rm), & &1.name) == [
               "id",
               "title",
               "slug",
               "archivedAt",
               "coachId",
               "description",
               "label",
               "teamId"
             ]
    end
  end

  describe "declared operations (metadata.annotations)" do
    defp annotated(annotations) do
      %Element{
        kind: :"read-model",
        name: "widget",
        scope: [{"domain", "sport"}, {"bounded-context", "sport"}],
        doc: %{"metadata" => %{"annotations" => annotations}},
        source: "fixtures/domain-model/catalog/equipment/read-model.widget.esdm.yaml",
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

    test "the fixture read model's own decisions cover every projection", %{model: model} do
      {:ok, rm} = Esdm.resolve(model, "read-model.widget")

      assert Esdm.declared_effects(rm) == %{
               "widget-created" => :create,
               "widget-edited" => :update,
               "widget-archived" => :delete,
               "widget-relabelled" => :update,
               # facts that materialize nothing are decided too, not left blank
               "widget-noted" => :none,
               "widget-rename-logged" => :none
             }
    end

    test "a command declares its operation, or declares nothing usable" do
      command = fn value ->
        %Element{
          kind: :command,
          name: "create-widget",
          scope: [{"domain", "sport"}, {"bounded-context", "sport"}, {"aggregate", "widget"}],
          doc: %{"metadata" => %{"annotations" => %{"spgen.operation" => value}}},
          source: "fixtures/domain-model/catalog/equipment/command.create-widget.esdm.yaml",
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

    test "a query declares read|collection, and the command vocabulary is not its own" do
      query = fn value ->
        %Element{
          kind: :query,
          name: "list-widgets",
          scope: [{"domain", "sport"}, {"bounded-context", "sport"}],
          doc: %{"metadata" => %{"annotations" => %{"spgen.operation" => value}}},
          source: "fixtures/domain-model/catalog/equipment/query.list-widgets.esdm.yaml",
          address: "esdm:domain=sport/.../query=list-widgets"
        }
      end

      assert Esdm.declared_query_operation(query.("collection")) == :collection
      assert Esdm.declared_query_operation(query.("read")) == :read
      # a command's word is not a query's: `create` over an array is no answer
      assert Esdm.declared_query_operation(query.("create")) == nil
      assert Esdm.declared_query_operation(query.(nil)) == nil
    end

    test "the fixture query's declaration is read from the model", %{model: model} do
      {:ok, collection} = Esdm.resolve(model, "query.list-widgets")
      {:ok, read} = Esdm.resolve(model, "query.read-widget")

      assert Esdm.declared_query_operation(collection) == :collection
      # read-widget states no declaration: its shape answers (see ContextTest)
      assert Esdm.declared_query_operation(read) == nil
    end
  end

  # The collection's parameters are the model's, not the generator's invention:
  # what is filterable, what is sortable, and how it paginates are three reads of
  # one document, and `SpGen.Blueprint.Schema` renders no enum without them.
  describe "query parameters" do
    setup %{model: model} do
      {:ok, query} = Esdm.resolve(model, "query.list-widgets")
      %{query: query}
    end

    test "the declared parameter names, in order", %{query: query} do
      assert Esdm.query_parameter_names(query) == ["filter", "page", "sort"]
    end

    test "filterable names are the filter's own properties", %{query: query} do
      assert get_in(query.doc, ["parameters", "properties", "filter", "properties"])
             |> Map.keys() == ["title"]
    end

    test "sortable names come from the sort's own list, in its order", %{query: query} do
      assert Esdm.sortable_fields(query) == ["title", "slug"]
    end

    test "a model that names no sort fields declares none", %{query: query} do
      bare = %{
        query
        | doc: put_in(query.doc, ["parameters", "properties", "sort", "sortableFields"], nil)
      }

      assert Esdm.sortable_fields(bare) == []
    end

    test "pagination style is the page's own keys", %{query: query} do
      assert Esdm.page_style(query) == :numbered

      offset =
        %{
          query
          | doc:
              put_in(
                query.doc,
                ["parameters", "properties", "page", "properties"],
                %{"limit" => %{"type" => "integer"}, "offset" => %{"type" => "integer"}}
              )
        }

      assert Esdm.page_style(offset) == :offset

      nopage = %{
        query
        | doc: update_in(query.doc, ["parameters", "properties"], &Map.delete(&1, "page"))
      }

      assert Esdm.page_style(nopage) == :none
    end

    test "a bare page is the house style", %{query: query} do
      bare = %{
        query
        | doc: put_in(query.doc, ["parameters", "properties", "page", "properties"], nil)
      }

      assert Esdm.page_style(bare) == :numbered
    end
  end

  describe "scenarios/2" do
    test "finds the feature scenarios exercising the operation, model order", %{model: model} do
      {:ok, command} = Esdm.resolve(model, @command_ref)
      scenarios = Esdm.scenarios(model, command)

      assert Enum.map(scenarios, & &1["name"]) == ["create-widget"]
      assert hd(scenarios) |> get_in(["when", "data", "title"]) == "Pommel Horse"
    end

    test "a scenario naming the query in `when.query` counts too" do
      # the fixture feature tells two commands; a third scenario naming the query
      # is stated inline rather than by editing the shared fixture, because this
      # test is about how `scenarios/2` matches, not about the fixture's content
      feature = %Element{
        kind: :feature,
        name: "reads-widgets",
        scope: [{"domain", "sport"}, {"bounded-context", "sport"}],
        doc: %{
          "apiVersion" => "schema.esdm.io/core/v1",
          "kind" => "feature",
          "name" => "reads-widgets",
          "scenarios" => [
            %{"name" => "reads one", "when" => %{"query" => "read-widget"}},
            %{"name" => "unrelated", "when" => %{"command" => "create-widget"}}
          ]
        },
        source: "fixtures/domain-model/catalog/equipment/feature.reads-widgets.esdm.yaml",
        address: "esdm:domain=sport/bounded-context=sport/aggregate=widget/feature=reads-widgets"
      }

      {:ok, model} = Esdm.load(FixtureRepo.model_path())
      model = %{model | elements: model.elements ++ [feature]}
      {:ok, query} = Esdm.resolve(model, "query.read-widget")

      assert Enum.map(Esdm.scenarios(model, query), & &1["name"]) == ["reads one"]
    end

    test "an operation no scenario tells has none", %{model: model} do
      {:ok, command} = Esdm.resolve(model, "command.note-widget")
      assert Esdm.scenarios(model, command) == []
    end
  end
end
