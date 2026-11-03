defmodule SpGenTest do
  @moduledoc """
  End-to-end acceptance of the `mix sp.gen.*` generators.

  Covers the two promises of the tool:

  1. **pickup**: run over existing code (the hand-written apparatus
     constituents of this repo) — everything is present, nothing changes
     (`--check` reports `unchanged` for every file).
  2. **generation**: run for a fresh citizen (widget fixture in a scratch
     tree) — missing files get their scaffold, existing shared files only
     receive missing units, and a second run changes nothing (idempotent).
  """
  use ExUnit.Case, async: false

  alias SpGen

  # test files run from tools/spgen; __DIR__ = tools/spgen/test/sp_gen
  @repo_root Path.expand("../../../..", __DIR__)

  # ------------------------------------------------------------------ pickup

  describe "pickup: --check over the existing apparatus code" do
    test "command create/update/delete are fully represented already" do
      for {name, template} <- [
            {"catalog-apparatus", "create"},
            {"edit-apparatus", "update"},
            {"archive-apparatus", "delete"}
          ] do
        assert {:ok, results} =
                 SpGen.run(:command, [name, "--template", template, "--check"])

        assert Enum.all?(results, &match?({:unchanged, _}, &1)),
               "#{name} wanted changes: #{inspect(results)}"

        # command, its test file, the composite router, the subdomain application
        assert length(results) == 4
      end
    end

    test "command handlers are fully represented already" do
      for name <- ["catalog-apparatus", "edit-apparatus"] do
        assert {:ok, results} = SpGen.run(:command_handler, [name, "--check"])
        assert Enum.all?(results, &match?({:unchanged, _}, &1))
      end
    end

    test "bruno docs for all apparatus operations already exist" do
      for name <- [
            "catalog-apparatus",
            "edit-apparatus",
            "archive-apparatus",
            "read-apparatus",
            "list-apparatuses"
          ] do
        assert {:ok, results} = SpGen.run(:bruno, [name, "--check"])

        assert Enum.all?(results, &match?({:unchanged, _}, &1)),
               "#{name} wanted changes: #{inspect(results)}"
      end
    end

    test "events are fully represented already" do
      for {name, template} <- [
            {"apparatus-cataloged", "create"},
            {"apparatus-edited", "update"},
            {"apparatus-archived", "delete"}
          ] do
        assert {:ok, results} = SpGen.run(:event, [name, "--template", template, "--check"])
        assert Enum.all?(results, &match?({:unchanged, _}, &1))
      end
    end
  end

  # ------------------------------------------------------------------ widget

  describe "generation into a scratch tree" do
    setup do
      root = build_scratch("test")
      on_exit(fn -> File.rm_rf!(root) end)
      %{root: root}
    end

    # scratch repo fixture: registration files + the widget citizen model
    defp build_scratch(label) do
      root = Path.join(System.tmp_dir!(), "spgen-#{label}-#{:erlang.unique_integer([:positive])}")
      api = Path.join(root, "services/api")
      File.mkdir_p!(Path.join(api, "lib/sportipedia/catalog/equipment"))

      # the scratch tree has no deps/, so `import_deps` in the real
      # .formatter.exs cannot resolve — inline the same locals explicitly
      File.write!(
        Path.join(api, ".formatter.exs"),
        """
        [
          inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
          locals_without_parens: [
            router: 1, middleware: 1, dispatch: 1, dispatch: 2, identify: 2, project: 3, type: 1,
            field: 1, field: 2, field: 3, plugin: 1, plugin: 2, timestamps: 1,
            validates: 2, add: 2, add: 3, create: 1, create: 2, modify: 2, modify: 3,
            pipeline: 2, scope: 1, scope: 2, scope: 3, scope: 4, plug: 1, plug: 2,
            pipe_through: 1, get: 3, get: 4, post: 3, post: 4, patch: 3, patch: 4,
            put: 3, put: 4, delete: 3, delete: 4, resources: 2, resources: 3, resources: 4,
            match: 4, match: 5, forward: 2, forward: 3,
            operation: 2, tags: 1, security: 1
          ]
        ]
        """
      )

      File.write!(Path.join(api, "lib/sportipedia/catalog/equipment/router.ex"), ~S'''
      defmodule Sportipedia.Catalog.Equipment.Router do
        alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusAggregate

        use Commanded.Commands.Router

        middleware Identity
        middleware Validate

        identify ApparatusAggregate, by: :id, prefix: "equipment/apparatus/"
      end
      ''')

      # supervisor + web router registration fixtures
      web = Path.join(api, "lib/sportipedia_web")
      File.mkdir_p!(web)

      File.write!(Path.join(web, "router.ex"), ~S'''
      defmodule SportipediaWeb.Router do
        use SportipediaWeb, :router

        scope "/catalog", SportipediaWeb.Catalog do
          pipe_through [:api, :catalog]

          scope "/equipment", Equipment do
            scope "/apparatuses", Apparatus do
              post "/catalog-apparatus", ApparatusController, :catalog_apparatus
            end
          end
        end
      end
      ''')

      File.mkdir_p!(Path.join(api, "lib/sportipedia/catalog"))

      File.write!(Path.join([api, "lib/sportipedia/catalog", "supervisor.ex"]), ~S'''
      defmodule Sportipedia.Catalog.Supervisor do
        use Supervisor

        def start_link(arg) do
          Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
        end

        def init(_arg) do
          children = [
            Sportipedia.Catalog
          ]

          Supervisor.init(children, strategy: :one_for_one)
        end
      end
      ''')

      model = Path.join(root, "docs/domain-model")
      File.mkdir_p!(Path.dirname(model))
      File.cp_r!(Path.join(@repo_root, "docs/domain-model"), model)

      widget = Path.join(model, "catalog/equipment")

      File.write!(Path.join(widget, "aggregate.widget.esdm.yaml"), ~S'''
      apiVersion: schema.esdm.io/core/v1
      kind: aggregate
      name: widget
      scope:
        domain: sport
        boundedContext: sport
      identifiedBy:
        source: generated
        generator: uuid
      state:
        type: object
        properties:
          id:
            type: string
            format: uuid
          label:
            type: string
        required:
          - id
          - label
      ''')

      File.write!(Path.join(widget, "command.create-widget.esdm.yaml"), ~S'''
      apiVersion: schema.esdm.io/core/v1
      kind: command
      name: create-widget
      scope:
        domain: sport
        boundedContext: sport
        aggregate: widget
      data:
        type: object
        properties:
          label:
            type: string
        required:
          - label
      publishes:
        - widget-created
      actors:
        - user
      ''')

      File.write!(Path.join(widget, "event.widget-created.esdm.yaml"), ~S'''
      apiVersion: schema.esdm.io/core/v1
      kind: event
      name: widget-created
      scope:
        domain: sport
        boundedContext: sport
        aggregate: widget
      data:
        type: object
        properties:
          id:
            type: string
            format: uuid
          label:
            type: string
        required:
          - id
          - label
      ''')

      File.write!(Path.join(widget, "read-model.widget.esdm.yaml"), ~S'''
      apiVersion: schema.esdm.io/core/v1
      kind: read-model
      name: widget
      scope:
        domain: sport
        boundedContext: sport
      projections:
        - boundedContext: sport
          aggregate: widget
          event: widget-created
          rule: "Project the widget when it is created"
      schema:
        type: object
        properties:
          id:
            type: string
            format: uuid
          label:
            type: string
        required:
          - id
          - label
      ''')

      File.write!(Path.join(widget, "query.read-widget.esdm.yaml"), ~S'''
      apiVersion: schema.esdm.io/core/v1
      kind: query
      name: read-widget
      description: "Retrieve a single widget"
      scope:
        domain: sport
        boundedContext: sport
      readModel: widget
      result:
        type: object
        properties:
          id:
            type: string
            format: uuid
          label:
            type: string
        required:
          - id
          - label
      parameters:
        type: object
        properties:
          id:
            type: string
            format: uuid
      actors:
        - guest
        - user
      ''')

      File.write!(Path.join(widget, "query.list-widgets.esdm.yaml"), ~S'''
      apiVersion: schema.esdm.io/core/v1
      kind: query
      name: list-widgets
      description: "List all widgets"
      scope:
        domain: sport
        boundedContext: sport
      readModel: widget
      result:
        type: array
        items:
          type: object
          properties:
            id:
              type: string
              format: uuid
            label:
              type: string
          required:
            - id
            - label
      parameters:
        type: object
        properties:
          filter:
            type: object
            properties:
              label:
                type: string
          sort:
            type: string
          page:
            type: object
      actors:
        - guest
        - user
      ''')

      File.write!(Path.join(widget, "feature.widget-management.esdm.yaml"), ~S'''
      apiVersion: schema.esdm.io/given-when-then/v1
      kind: feature
      name: manage-widgets
      scope:
        domain: sport
        boundedContext: sport
        aggregate: widget
      scenarios:
        - name: create-widget
          given: []
          when:
            command: create-widget
            data:
              label: "Pommel Horse"
            actor: user
          then:
            events:
              - event: widget-created
                data:
                  id: "{{ generated }}"
                  label: "Pommel Horse"
      ''')

      root
    end

    test "story A/B: deferral + back-fill converge with ordered creation", %{} do
      a = build_scratch("a")
      b = build_scratch("b")
      agg_rel = "lib/sportipedia/catalog/equipment/widget/aggregate.ex"
      agg_plan_path = "services/api/" <> agg_rel

      try do
        # A) aggregate first: no events exist, so the aggregate materializes
        # as a bare shell and its handler units defer (still exit 0)
        {:ok, results_a} = SpGen.run(:aggregate, ["aggregate.widget", "--root", a])
        bare = read(a, agg_rel)
        assert bare =~ "use TypedStruct"
        assert bare =~ "field :label, String.t()"
        refute bare =~ "WidgetCreated"

        assert Enum.any?(results_a, fn
                 {:deferred, ^agg_plan_path, _} -> true
                 _ -> false
               end)

        # the event run creates the event and back-fills the aggregate
        {:ok, results_ev} =
          SpGen.run(:event, ["widget-created", "--template", "create", "--root", a])

        assert Enum.any?(results_ev, fn
                 {:backfill, ^agg_plan_path, ids} -> ids != []
                 _ -> false
               end)

        filled = read(a, agg_rel)
        assert filled =~ "def apply(%__MODULE__{} = _aggregate, %WidgetCreated{} = event)"

        # B) event first: the aggregate is created complete — nothing about
        # the aggregate itself defers (unrelated command units may still, via
        # the closure's honest reporting)
        {:ok, _} = SpGen.run(:event, ["widget-created", "--template", "create", "--root", b])
        {:ok, results_b} = SpGen.run(:aggregate, ["aggregate.widget", "--root", b])

        refute Enum.any?(results_b, fn
                 {:deferred, ^agg_plan_path, _} -> true
                 _ -> false
               end)

        assert Enum.any?(results_b, fn
                 {:created, ^agg_plan_path} -> true
                 _ -> false
               end)

        # convergence: the same code in either generation order (AST equality)
        assert canon_ast(filled) == canon_ast(read(b, agg_rel))

        # fixed points: re-running any of these generators changes nothing
        for root <- [a, b],
            {generator, args} <- [
              {:aggregate, ["aggregate.widget"]},
              {:event, ["widget-created", "--template", "create"]}
            ] do
          {:ok, results} = SpGen.run(generator, args ++ ["--root", root])

          assert Enum.all?(results, &match?({:unchanged, _}, &1)),
                 "#{generator} #{inspect(args)} on #{root}: #{inspect(results)}"
        end
      after
        File.rm_rf(a)
        File.rm_rf(b)
      end
    end

    # structural AST comparison: generation order is a layout question,
    # the code is the answer. Strips all node metadata (the generic clause
    # covers remote-call nodes whose "name" is itself a tuple).
    defp canon_ast(text) do
      {:ok, ast} = Code.string_to_quoted(text)

      Macro.prewalk(ast, fn
        {name, meta, args} when is_list(meta) -> {name, [], args}
        other -> other
      end)
    end

    defp run(generator, args, root) do
      SpGen.run(generator, args ++ ["--root", root])
    end

    test "creates a complete citizen and is then a no-op", %{root: root} do
      # event first (its tests live in the publishing command's test file)
      assert {:ok, results} = run(:event, ["widget-created", "--template", "create"], root)
      assert Enum.count(results, &match?({:created, _}, &1)) == 2

      assert {:ok, results} = run(:command_handler, ["create-widget"], root)
      assert [{:created, handler} | _] = Enum.filter(results, &match?({:created, _}, &1))
      assert handler =~ "handler.ex"

      assert {:ok, results} = run(:command, ["create-widget", "--template", "create"], root)
      assert Enum.any?(results, &match?({:created, _}, &1))
      assert Enum.any?(results, &(match?({:merged, _, _ids}, &1) and elem(&1, 2) != []))

      # the aggregate exists now — its run back-fills the router entries the
      # command run had to defer (aggregate alias, identify, dispatch)
      assert {:ok, _} = run(:aggregate, ["aggregate.widget"], root)

      # everything parses
      for path <- generated_files(root) do
        source = File.read!(path)
        assert {:ok, _} = Code.string_to_quoted(source), "invalid syntax in #{path}"
        assert String.ends_with?(source, "\n"), "missing trailing newline: #{path}"
      end

      # second run: complete no-op
      assert {:ok, results} = run(:event, ["widget-created", "--template", "create"], root)
      assert Enum.all?(results, &match?({:unchanged, _}, &1))
      assert {:ok, results} = run(:command_handler, ["create-widget"], root)
      assert Enum.all?(results, &match?({:unchanged, _}, &1))
      assert {:ok, results} = run(:command, ["create-widget", "--template", "create"], root)
      assert Enum.all?(results, &match?({:unchanged, _}, &1))
      assert {:ok, results} = run(:aggregate, ["aggregate.widget"], root)
      assert Enum.all?(results, &match?({:unchanged, _}, &1))
    end

    test "generated command matches the blueprint shape", %{root: root} do
      {:ok, _} = run(:event, ["widget-created", "--template", "create"], root)
      {:ok, _} = run(:command_handler, ["create-widget"], root)
      {:ok, _} = run(:command, ["create-widget", "--template", "create"], root)
      # aggregate last: its run back-fills the router entries the command run
      # deferred (they reference the aggregate module)
      {:ok, _} = run(:aggregate, ["aggregate.widget"], root)

      command =
        read(root, "lib/sportipedia/catalog/equipment/widget/operation/create_widget/command.ex")

      assert command =~ "defmodule Sportipedia.Catalog.Equipment.Widget.Command.CreateWidget do"
      assert command =~ "use TypedStruct"
      assert command =~ "use ExConstructor"
      assert command =~ "field :id, String.t(), enforce: true"
      assert command =~ "field :label, String.t(), enforce: true"
      assert command =~ "use Vex.Struct"
      assert command =~ "validates :label, presence: true"
      refute command =~ "validates :id"

      event = read(root, "lib/sportipedia/catalog/equipment/widget/events/widget_created.ex")
      assert event =~ "defmodule Sportipedia.Catalog.Equipment.Widget.Event.WidgetCreated do"
      assert event =~ "@derive Jason.Encoder"

      handler =
        read(root, "lib/sportipedia/catalog/equipment/widget/operation/create_widget/handler.ex")

      assert handler =~ "@behaviour Commanded.Commands.Handler"
      assert handler =~ "def handle(%WidgetAggregate{} = aggregate, %CreateWidget{} = cmd) do"

      router = read(root, "lib/sportipedia/catalog/equipment/router.ex")

      assert router =~
               "dispatch CreateWidget, to: CreateWidgetHandler, aggregate: WidgetAggregate"

      assert router =~ "identify WidgetAggregate, by: :id, prefix: \"equipment/widget/\""

      test_file =
        read(root, "test/sportipedia/catalog/equipment/widget/operation/create_widget_test.exs")

      assert test_file =~ "use Sportipedia.CatalogTestCase"
      assert test_file =~ "@moduletag :integration"
      assert test_file =~ ~s|describe "WidgetCreated event" do|
      assert test_file =~ ~s|describe "CreateWidgetHandler" do|
      assert test_file =~ ~s|describe "CreateWidget command" do|
    end

    # the athlete's position is the richest citizen in the model: a date-time
    # field, a unique invariant, and constraints on its commands
    test "generated read model matches the blueprint shape", %{root: root} do
      {:ok, _} = run(:read_model, ["read-model.position"], root)

      # the by-slug query is the hand-written host the internal accessor
      # delegates to (see the unique-slug example in the blueprint docs)
      query_path =
        Path.join(
          root,
          "services/api/lib/sportipedia/catalog/athlete/position/queries/position_by_slug.ex"
        )

      File.mkdir_p!(Path.dirname(query_path))

      File.write!(query_path, ~S'''
      defmodule Sportipedia.Catalog.Athlete.Position.Queries.PositionBySlug do
        @moduledoc """
        Query to fetch a position by its slug.
        """

        alias Sportipedia.Catalog.Athlete.Position.PositionReadModel
        import Ecto.Query

        @doc """
        Creates a new query to fetch a position by slug.
        """
        def new(slug) do
          from(r in PositionReadModel,
            where: r.slug == ^slug
          )
        end
      end
      ''')

      {:ok, _} = run(:internal_api, ["read-model.position"], root)

      rm = read(root, "lib/sportipedia/catalog/athlete/position/read_model.ex")

      # the injected primary key is cast as an atom, fields land before the
      # trailing `timestamps()`, and date-times map to the timestamp type
      assert rm =~ "cast(attrs, [:id, :title, :slug"
      assert rm =~ "field :archivedAt, :utc_datetime_usec"

      lines = String.split(rm, "\n")
      field = Enum.find_index(lines, &String.contains?(&1, "field :instrumentId"))
      ts = Enum.find_index(lines, &String.contains?(&1, "timestamps()"))
      assert field < ts, "field after timestamps():\n#{rm}"

      # the aggregate's unique invariant becomes a unique constraint on the
      # index name the migration will create (`<table>_<field>_index`)
      assert rm =~ "unique_constraint(:slug, name: :position_slug_index)"

      # read-model-driven generators see the projected aggregate's rules, too:
      # the by-slug accessor back-fills next to its query
      internal = read(root, "lib/sportipedia/catalog/athlete/position/internal.ex")
      assert internal =~ "def position_by_slug"

      # second run: complete no-op
      assert {:ok, results} = run(:read_model, ["read-model.position"], root)
      assert Enum.all?(results, &match?({:unchanged, _}, &1)), inspect(results)
      assert {:ok, results} = run(:internal_api, ["read-model.position"], root)
      assert Enum.all?(results, &match?({:unchanged, _}, &1)), inspect(results)
    end

    test "all four address forms resolve to the same command", %{root: root} do
      forms = [
        "create-widget",
        "command.create-widget",
        "docs/domain-model/catalog/equipment/command.create-widget.esdm.yaml",
        "esdm:domain=sport/bounded-context=sport/aggregate=widget/command=create-widget"
      ]

      results_per_form =
        for form <- forms do
          {:ok, results} =
            SpGen.run(:command, [form, "--template", "create", "--check", "--root", root])

          results
        end

      # --check writes nothing, so every form must observe the identical plan
      assert Enum.all?(results_per_form, &(&1 == hd(results_per_form))),
             "forms resolved differently: #{inspect(results_per_form)}"

      assert Enum.any?(hd(results_per_form), &match?({:checked, _, _}, &1))
    end

    # The registration hosts are not a precondition of a run: the generators
    # that write into them create them when the composite or subdomain lacks
    # one (router.ex and application.ex by `command`, supervisor.ex by
    # `projector`).
    test "the command run creates the composite router and the commanded application", %{
      root: root
    } do
      File.rm_rf!(Path.join(root, "services/api/lib/sportipedia/catalog/equipment/router.ex"))

      {:ok, _} = run(:event, ["widget-created"], root)
      {:ok, _} = run(:command_handler, ["create-widget"], root)
      {:ok, _} = run(:command, ["create-widget"], root)
      # the aggregate's run back-fills the router entries the command deferred
      {:ok, _} = run(:aggregate, ["aggregate.widget"], root)

      router = read(root, "lib/sportipedia/catalog/equipment/router.ex")

      assert router =~ "defmodule Sportipedia.Catalog.Equipment.Router do"
      assert router =~ "use Commanded.Commands.Router"
      assert router =~ "alias Sportipedia.Support.Commanded.Middleware.Identity"
      assert router =~ "middleware Identity"
      assert router =~ "middleware Validate"

      assert router =~
               ~S|identify WidgetAggregate, by: :id, prefix: "equipment/widget/"|

      assert router =~
               "dispatch CreateWidget, to: CreateWidgetHandler, aggregate: WidgetAggregate"

      app = read(root, "lib/sportipedia/catalog/application.ex")

      assert app =~ "defmodule Sportipedia.Catalog do"
      assert app =~ "use Commanded.Application, otp_app: :sportipedia"
      assert app =~ "router Sportipedia.Catalog.Equipment.Router"

      # every host the run created is complete: a second run changes nothing
      assert {:ok, again} = run(:command, ["create-widget"], root)
      assert Enum.all?(again, &match?({:unchanged, _}, &1)), inspect(again)
    end

    test "the projector run creates the subdomain supervisor it registers into", %{root: root} do
      File.rm_rf!(Path.join(root, "services/api/lib/sportipedia/catalog/supervisor.ex"))

      for {generator, args} <- [
            {:event, ["widget-created"]},
            {:command_handler, ["create-widget"]},
            {:command, ["create-widget"]},
            {:aggregate, ["aggregate.widget"]},
            {:read_model, ["read-model.widget"]},
            {:internal_api, ["read-model.widget"]}
          ] do
        assert {:ok, _} = run(generator, args, root)
      end

      assert {:ok, results} = run(:projector, ["widget-created"], root)

      assert Enum.any?(
               results,
               &match?({:created, "services/api/lib/sportipedia/catalog/supervisor.ex"}, &1)
             ),
             inspect(results)

      supervisor = read(root, "lib/sportipedia/catalog/supervisor.ex")

      assert supervisor =~ "defmodule Sportipedia.Catalog.Supervisor do"
      assert supervisor =~ "use Supervisor"
      assert supervisor =~ "Supervisor.start_link(__MODULE__, arg, name: __MODULE__)"
      assert supervisor =~ "Supervisor.init(children, strategy: :one_for_one)"
      assert supervisor =~ "Sportipedia.Catalog.Equipment.Widget.WidgetProjector"

      assert {:ok, again} = run(:projector, ["widget-created"], root)
      assert Enum.all?(again, &match?({:unchanged, _}, &1)), inspect(again)
    end

    # A test file is a container for tests: a contributor whose units all wait
    # defers without creating it, and the first one with a test to write owns
    # its birth.
    test "a test file appears with the first test written into it", %{root: root} do
      rel =
        "services/api/test/sportipedia/catalog/equipment/widget/operation/create_widget_test.exs"

      path = Path.join(root, rel)

      # the aggregate's contribution is gated on its events, which are not
      # generated yet: nothing may be written
      assert {:ok, results} = run(:aggregate, ["aggregate.widget"], root)
      refute File.exists?(path), "an empty test file was created"

      assert Enum.any?(results, fn
               {:deferred, ^rel, _} -> true
               _ -> false
             end),
             inspect(results)

      # the event has a test to write, so it creates the file
      assert {:ok, _} = run(:event, ["widget-created", "--template", "create"], root)
      assert File.exists?(path)
      assert File.read!(path) =~ ~s|describe "WidgetCreated event"|

      # the aggregate now merges into the file that exists (its own run had to
      # defer, and the event run's closure already back-filled it)
      assert {:ok, _} = run(:aggregate, ["aggregate.widget"], root)
      content = File.read!(path)
      assert content =~ ~s|describe "WidgetCreated event"|
      assert content =~ ~s|describe "WidgetAggregate"|

      # fixed point
      assert {:ok, again} = run(:aggregate, ["aggregate.widget"], root)
      assert Enum.all?(again, &match?({:unchanged, _}, &1)), inspect(again)
    end

    test "--check promises a test file only if a test would be written", %{root: root} do
      rel =
        "services/api/test/sportipedia/catalog/equipment/widget/operation/create_widget_test.exs"

      assert {:ok, results} = run(:aggregate, ["aggregate.widget", "--check"], root)

      refute Enum.any?(results, fn
               {:checked, ^rel, ids} -> :whole_file in ids
               _ -> false
             end),
             "check promised a file the run would not write: #{inspect(results)}"

      assert {:ok, results} =
               run(:event, ["widget-created", "--template", "create", "--check"], root)

      assert Enum.any?(results, fn
               {:checked, ^rel, ids} -> :whole_file in ids
               _ -> false
             end),
             "the event has a test to write and should create the file: #{inspect(results)}"
    end

    @chain [
      {"event", ["widget-created"]},
      {"command_handler", ["create-widget"]},
      {"command", ["create-widget"]},
      {"aggregate", ["aggregate.widget"]},
      {"read_model", ["read-model.widget"]},
      {"projector", ["widget-created"]},
      {"internal_api", ["read-model.widget"]},
      {"policy", ["create-widget"]},
      {"policy", ["read-widget"]},
      {"policy", ["list-widgets"]},
      {"public_api", ["create-widget"]},
      {"public_api", ["read-widget"]},
      {"public_api", ["list-widgets"]},
      {"query", ["read-widget"]},
      {"view", ["read-model.widget"]},
      {"schema", ["read-model.widget"]},
      {"schema", ["create-widget"]},
      {"controller", ["create-widget"]},
      {"controller", ["read-widget"]},
      {"controller", ["list-widgets"]},
      {"bruno", ["create-widget"]},
      {"bruno", ["read-widget"]},
      {"bruno", ["list-widgets"]}
    ]

    test "order-independence: the reversed full chain converges to the same citizen", %{} do
      fwd = build_scratch("fwd")
      rev = build_scratch("rev")

      try do
        for {name, args} <- @chain do
          assert {:ok, _} = SpGen.run(String.to_atom(name), args ++ ["--root", fwd])
        end

        for {name, args} <- Enum.reverse(@chain) do
          assert {:ok, _} = SpGen.run(String.to_atom(name), args ++ ["--root", rev])
        end

        fwd_files = generated_files(fwd) |> Enum.map(&Path.relative_to(&1, fwd)) |> Enum.sort()
        rev_files = generated_files(rev) |> Enum.map(&Path.relative_to(&1, rev)) |> Enum.sort()
        assert fwd_files == rev_files, "the two orders generated different file sets"

        # same code in both trees: sibling order (describe blocks, routes) may
        # differ by insertion history, so compare canonically sorted ASTs
        for rel <- fwd_files do
          assert canon_sort(File.read!(Path.join(fwd, rel))) ==
                   canon_sort(File.read!(Path.join(rev, rel))),
                 "AST mismatch in #{rel}"
        end

        # the reversed tree is a fixed point: a forward sweep changes nothing
        for {name, args} <- @chain do
          {:ok, results} = SpGen.run(String.to_atom(name), args ++ ["--check", "--root", rev])

          assert Enum.all?(results, &match?({:unchanged, _}, &1)),
                 "#{name} reversed-tree drift: #{inspect(results)}"
        end
      after
        File.rm_rf(fwd)
        File.rm_rf(rev)
      end
    end

    # Canonical structure: every __block__ (module bodies, do-blocks) is
    # replaced by the sorted Macro.to_string of its expressions, so two trees
    # with the same code in any sibling order compare equal.
    defp canon_sort(text) do
      {:ok, ast} = Code.string_to_quoted(text)

      {ast, _} =
        Macro.postwalk(ast, nil, fn
          {:__block__, meta, exprs}, acc ->
            sorted = exprs |> Enum.map(&Macro.to_string/1) |> Enum.sort()
            {{:__block__, meta, sorted}, acc}

          other, acc ->
            {other, acc}
        end)

      Macro.to_string(ast)
    end

    test "the whole citizen chain: creates, then is a no-op", %{root: root} do
      for {name, args} <- @chain do
        assert {:ok, _} = SpGen.run(String.to_atom(name), args ++ ["--root", root])
      end

      # every generated file parses and ends with a newline
      for path <- Path.wildcard(Path.join(root, "services/api/**/*.{ex,exs}")),
          not String.ends_with?(path, ".formatter.exs") do
        source = File.read!(path)
        assert {:ok, _} = Code.string_to_quoted(source), "invalid syntax in #{path}"
        assert String.ends_with?(source, "\n"), "missing trailing newline: #{path}"
      end

      # the registration files picked everything up
      web_router = File.read!(Path.join(root, "services/api/lib/sportipedia_web/router.ex"))
      assert web_router =~ "scope \"/widgets\", Widget do"
      assert web_router =~ "post \"/create-widget\", WidgetController, :create_widget"
      assert web_router =~ "get \"/:id\", WidgetController, :read_widget"
      assert web_router =~ "get \"/\", WidgetController, :list_widgets"

      supervisor =
        File.read!(Path.join(root, "services/api/lib/sportipedia/catalog/supervisor.ex"))

      assert supervisor =~
               "children = [Sportipedia.Catalog, Sportipedia.Catalog.Equipment.Widget.WidgetProjector]"

      bruno_dir = Path.join(root, "bruno/Catalog/Equipment/Widget")
      create_doc = File.read!(Path.join(bruno_dir, "Create Widget.yml"))
      assert create_doc =~ "method: POST"
      assert create_doc =~ ~s|"type": "widget"|
      assert create_doc =~ ~s|"label": "Pommel Horse"|
      assert create_doc =~ "seq: 1"
      assert File.read!(Path.join(bruno_dir, "Read Widget.yml")) =~ "method: GET"
      assert File.read!(Path.join(bruno_dir, "List Widgets.yml")) =~ "seq: 3"
      assert File.read!(Path.join(bruno_dir, "folder.yml")) =~ "name: Widget"

      # second run of the full chain: absolutely nothing changes
      for {name, args} <- @chain do
        assert {:ok, results} =
                 SpGen.run(String.to_atom(name), args ++ ["--check", "--root", root])

        assert Enum.all?(results, &match?({:unchanged, _}, &1)),
               "#{name} #{inspect(args)} wanted changes: #{inspect(results)}"
      end
    end

    test "args override inference", %{root: root} do
      {:ok, results} =
        SpGen.run(:command, [
          "create-widget",
          "--template",
          "create",
          "--root",
          root,
          "--constituent",
          "gadget"
        ])

      assert Enum.any?(results, fn
               {:created, path} -> String.contains?(path, "gadget")
               _ -> false
             end)
    end
  end

  # ------------------------------------------------------------------ errors

  describe "argument contract" do
    test "without --template the operation derives from the domain model" do
      # catalog-apparatus publishes apparatus-cataloged, whose projection creates a row
      assert {:ok, results} = SpGen.run(:command, ["catalog-apparatus", "--check"])
      assert Enum.all?(results, &match?({:unchanged, _}, &1))
      assert length(results) == 4
    end

    test "template does not fit the element kind" do
      # controller spans both kinds, so the kind guard is what rejects this
      assert {:error, message} =
               SpGen.run(:controller, [
                 "read-apparatus",
                 "--template",
                 "create"
               ])

      assert message =~ "does not fit a query"
    end

    test "template is validated against the blueprint's set" do
      assert {:error, message} =
               SpGen.run(:command, ["catalog-apparatus", "--template", "read"])

      assert message =~ "not supported"

      assert {:error, message} =
               SpGen.run(:event, ["apparatus-cataloged", "--template", "collection"])

      assert message =~ "not supported"
    end

    test "fixed blueprints reject --template" do
      assert {:error, message} =
               SpGen.run(:command_handler, ["catalog-apparatus", "--template", "create"])

      assert message =~ "fixed"
    end

    test "bare element names resolve among the generator's kinds" do
      # apparatus exists as both aggregate and read-model; each generator finds its own
      assert {:ok, results} = SpGen.run(:aggregate, ["apparatus", "--check"])
      assert Enum.all?(results, &match?({:unchanged, _}, &1)), inspect(results)

      assert {:ok, results} = SpGen.run(:read_model, ["apparatus", "--check"])
      assert Enum.all?(results, &match?({:unchanged, _}, &1)), inspect(results)

      assert {:ok, results} = SpGen.run(:view, ["apparatus", "--check"])
      assert Enum.all?(results, &match?({:unchanged, _}, &1)), inspect(results)

      # internal_api genuinely accepts both colliding kinds → ambiguity persists,
      # and the error tells the caller how to disambiguate
      assert {:error, message} = SpGen.run(:internal_api, ["apparatus", "--check"])
      assert message =~ "aggregate=apparatus"
      assert message =~ "read-model=apparatus"
    end

    test "wrong element kind is refused" do
      assert {:error, message} =
               SpGen.run(:command, ["apparatus-cataloged", "--template", "create"])

      assert message =~ "command"
      assert message =~ "event"
    end

    test "ambiguous names list their esdm references" do
      assert {:error, message} = SpGen.run(:command, ["apparatus", "--template", "create"])
      assert message =~ "esdm:"
      assert message =~ "aggregate=apparatus"
    end

    test "multi element file is refused" do
      path = Path.join(@repo_root, "docs/domain-model/actors.esdm.yaml")
      assert {:error, message} = SpGen.run(:command, [path, "--template", "create"])
      assert message =~ "more than one element"
    end

    test "missing argument prints usage" do
      assert {:error, message} = SpGen.run(:command, [])
      assert message =~ "usage: mix sp.gen.command"
    end

    test "unknown option is reported" do
      assert {:error, message} = SpGen.run(:command, ["--wat"])
      assert message =~ "unknown option"
    end
  end

  # ------------------------------------------------------------------- misc

  defp generated_files(root) do
    Path.wildcard(Path.join(root, "services/api/**/*.{ex,exs}"))
  end

  defp read(root, rel) do
    File.read!(Path.join([root, "services/api", rel]))
  end
end
