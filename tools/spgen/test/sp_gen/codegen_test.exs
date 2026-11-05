defmodule SpGenTest do
  @moduledoc """
  End-to-end acceptance of the blueprint generators.

  Everything runs against `SpGen.FixtureRepo`: the domain model of
  `fixtures/domain-model` and the hand-owned host files of
  `fixtures/repo`, mounted on an in-memory `SpGen.FS` handle. Nothing is
  read from or written to the real tree, so the repository under test is pure
  data and the suite can run in parallel.

  The widget citizen is the subject: a `unique-slug` invariant, a cross-field
  invariant, an exists-constraint, a multi-event command, create/update/delete
  projections and two queries — enough model to drive every generator.

  What is asserted:

  1. **generation** — a run writes the artifacts its element implies, and the
     invariant dependencies of the code it writes;
  2. **fixed point** — the same run again changes nothing;
  3. **order independence** — forward and reversed generation converge to the
     same tree;
  4. **the snapshot** — the canonical citizen matches
     `fixtures/snapshots/widget.txt`, the recorded expected outcome.

  Generators are driven through `SpGen.run/3`, the black-box interface the CLI
  uses.
  """
  use ExUnit.Case, async: true

  alias SpGen.{Context, Esdm, FixtureRepo}

  @event_test "services/api/test/sportipedia/catalog/equipment/widget/events/widget_created_test.exs"
  @operation_test "services/api/test/sportipedia/catalog/equipment/widget/operations/create_widget_test.exs"

  # every generator the widget citizen needs, in the order the tool documents
  @chain [
    {:read_model, ["read-model.widget"]},
    {:event, ["widget-created"]},
    {:event, ["widget-edited"]},
    {:event, ["widget-archived"]},
    {:event, ["widget-relabelled"]},
    {:event, ["widget-rename-logged"]},
    {:aggregate, ["aggregate.widget"]},
    {:query, ["read-widget"]},
    {:query, ["list-widgets"]},
    {:internal_api, ["read-model.widget"]},
    {:command, ["create-widget", "--template", "create"]},
    {:command, ["edit-widget", "--template", "update"]},
    {:command, ["archive-widget", "--template", "delete"]},
    {:command_handler, ["create-widget"]},
    {:command_handler, ["edit-widget"]},
    {:command_handler, ["archive-widget"]},
    {:projector, ["widget-created"]},
    {:projector, ["widget-edited"]},
    {:policy, ["create-widget"]},
    {:policy, ["read-widget"]},
    {:policy, ["list-widgets"]},
    {:public_api, ["create-widget"]},
    {:public_api, ["read-widget"]},
    {:public_api, ["list-widgets"]},
    {:view, ["read-model.widget"]},
    {:schema, ["read-model.widget"]},
    {:schema, ["create-widget"]},
    {:controller, ["create-widget"]},
    {:controller, ["read-widget"]},
    {:controller, ["list-widgets"]},
    {:bruno, ["create-widget"]},
    {:bruno, ["read-widget"]},
    {:bruno, ["list-widgets"]}
  ]

  defp generate(repo) do
    for {generator, args} <- @chain do
      assert {:ok, _} = FixtureRepo.run(repo, generator, args), "#{generator} #{inspect(args)}"
    end
  end

  # ------------------------------------------------------------------ model

  describe "the fixture model" do
    setup do
      %{repo: FixtureRepo.build()}
    end

    test "loads through the virtual filesystem", %{repo: repo} do
      {:ok, model} = Esdm.load(Path.join(repo.root, "docs/domain-model"), fs: repo.fs)

      assert Enum.map(model.elements, & &1.name) |> Enum.sort() |> Enum.take(4) == [
               "admin",
               "archive-widget",
               "create-widget",
               "edit-widget"
             ]
    end

    test "resolves by bare name, kind.name, file and esdm reference", %{repo: repo} do
      {:ok, model} = Esdm.load(Path.join(repo.root, "docs/domain-model"), fs: repo.fs)

      addresses = [
        "create-widget",
        "command.create-widget",
        "docs/domain-model/catalog/equipment/command.create-widget.esdm.yaml",
        "esdm:domain=sport/bounded-context=sport/aggregate=widget/command=create-widget"
      ]

      for address <- addresses do
        assert {:ok, %{kind: :command, name: "create-widget"}} =
                 Esdm.resolve(model, address, kinds: [:command]),
               address
      end
    end

    test "a bare name shared by two kinds stays ambiguous and says how to resolve it", %{
      repo: repo
    } do
      {:ok, model} = Esdm.load(Path.join(repo.root, "docs/domain-model"), fs: repo.fs)

      assert {:error, reason} = Esdm.resolve(model, "widget")
      message = Esdm.format_error(reason)
      assert message =~ "aggregate=widget"
      assert message =~ "read-model=widget"
    end
  end

  # ------------------------------------------------------------- generation

  describe "generation into an empty repository" do
    setup do
      %{repo: FixtureRepo.build()}
    end

    test "the command run creates its own files and the invariant closure it validates with", %{
      repo: repo
    } do
      {:ok, results} = FixtureRepo.run(repo, :command, ["edit-widget", "--template", "update"])
      created = results |> Enum.filter(&match?({:created, _}, &1)) |> Enum.map(&elem(&1, 1))

      # the command's own artifacts
      for rel <- [
            "widget/operations/edit_widget/command.ex",
            "widget/operations/edit_widget_test.exs"
          ] do
        assert Enum.any?(created, &String.ends_with?(&1, rel)), inspect(created)
      end

      # what its validators delegate to, planned ahead of them in the same run
      for rel <- [
            "widget/read_model.ex",
            "widget/queries/widget_by_slug.ex",
            "widget/internal.ex",
            "widget/validators/unique_slug.ex",
            "widget/validators/widget_exists.ex"
          ] do
        assert Enum.any?(created, &String.ends_with?(&1, rel)),
               "#{rel} was not created by the command run: #{inspect(created)}"
      end

      # the run wrote no reference that is not there: nothing waits on a
      # citizen the command itself just produced
      refute Enum.any?(results, fn
               {:deferred, path, waiting} ->
                 String.contains?(path, "widget/operations/edit_widget/") and
                   Enum.any?(waiting, fn {_id, reason} -> reason =~ "spgen command" end)

               _ ->
                 false
             end),
             inspect(results)
    end

    test "the unique invariant generates the whole example slice", %{repo: repo} do
      {:ok, _} = FixtureRepo.run(repo, :command, ["create-widget", "--template", "create"])

      query =
        read(repo, "lib/sportipedia/catalog/equipment/widget/queries/widget_by_slug.ex")

      assert query =~
               "defmodule Sportipedia.Catalog.Equipment.Widget.Queries.WidgetBySlug do"

      assert query =~ "alias Sportipedia.Catalog.Equipment.Widget.WidgetReadModel"
      assert query =~ "import Ecto.Query"
      assert query =~ "where: r.slug == ^slug"

      internal = read(repo, "lib/sportipedia/catalog/equipment/widget/internal.ex")
      assert internal =~ "def widget_by_id(id) do"
      assert internal =~ "def widget_by_slug(slug) do"

      validator = read(repo, "lib/sportipedia/catalog/equipment/widget/validators/unique_slug.ex")
      assert validator =~ "use Vex.Validator"
      assert validator =~ "alias Sportipedia.Catalog.Equipment.Widget.WidgetInternal"
      assert validator =~ "WidgetInternal.widget_by_slug(value)"
      assert validator =~ "defp slug_belongs_to_widget?"

      command =
        read(repo, "lib/sportipedia/catalog/equipment/widget/operations/create_widget/command.ex")

      assert command =~ "alias Sportipedia.Catalog.Equipment.Widget.Validators.UniqueSlug"

      assert command =~
               "validates :slug, presence: true, by: [function: &UniqueSlug.validate/2, allow_nil: true]"
    end

    test "a rule no pattern claims generates a scaffold, not a guess", %{repo: repo} do
      {:ok, _} = FixtureRepo.run(repo, :command, ["create-widget", "--template", "create"])

      scaffold =
        read(repo, "lib/sportipedia/catalog/equipment/widget/validators/at_most_one_owner.ex")

      assert scaffold =~ "def validate(_value, _context) do"
      assert scaffold =~ ~s|raise "TODO: implement the at-most-one-owner validator|

      # `no-archive-when-in-use` guards no field of the citizen: it resolves to
      # nothing, and that is recorded rather than dropped
      {:ok, model} = Esdm.load(Path.join(repo.root, "docs/domain-model"), fs: repo.fs)
      element = Esdm.resolve!(model, "command.create-widget")
      {:ok, ctx} = Context.build(model, element, fs: repo.fs)

      assert Enum.map(ctx.validators, & &1.name) |> Enum.sort() == [
               "at-most-one-owner",
               "unique-slug"
             ]

      assert Enum.map(ctx.unresolved, & &1["name"]) == ["no-archive-when-in-use"]
    end

    test "the event, aggregate and projector tests live in the event's own file", %{repo: repo} do
      {:ok, _} = FixtureRepo.run(repo, :event, ["widget-created"])
      {:ok, _} = FixtureRepo.run(repo, :aggregate, ["aggregate.widget"])
      {:ok, _} = FixtureRepo.run(repo, :command_handler, ["create-widget"])
      {:ok, _} = FixtureRepo.run(repo, :command, ["create-widget", "--template", "create"])
      {:ok, _} = FixtureRepo.run(repo, :projector, ["widget-created"])

      event_test =
        read(repo, "test/sportipedia/catalog/equipment/widget/events/widget_created_test.exs")

      assert event_test =~
               "defmodule Sportipedia.Catalog.Equipment.Widget.Event.WidgetCreatedTest do"

      assert event_test =~ "use Sportipedia.CatalogTestCase"
      assert event_test =~ "@moduletag :integration"
      assert event_test =~ ~s|describe "Event" do|
      assert event_test =~ ~s|describe "Aggregate" do|
      assert event_test =~ ~s|describe "Projector" do|
      assert event_test =~ "test \"applies widget-created to aggregate state\" do"
      assert event_test =~ "WidgetProjector.handle(event, metadata)"

      # the operation test holds the operation's own blocks — not the fact's
      operation = read(repo, @operation_test)

      assert operation =~ ~s|describe "Command" do|
      assert operation =~ ~s|describe "Command Handler" do|
      refute operation =~ ~s|describe "Event"|
      refute operation =~ ~s|describe "Aggregate"|
    end

    test "one file per event: a multi-event command splits its facts", %{repo: repo} do
      {:ok, _} = FixtureRepo.run(repo, :event, ["widget-relabelled"])
      {:ok, _} = FixtureRepo.run(repo, :event, ["widget-rename-logged"])
      {:ok, _} = FixtureRepo.run(repo, :aggregate, ["aggregate.widget"])

      for name <- ["widget_relabelled", "widget_rename_logged"] do
        rel = "test/sportipedia/catalog/equipment/widget/events/#{name}_test.exs"
        assert FixtureRepo.exists?(repo, "services/api/" <> rel), "#{name} has no test file"
        assert read(repo, rel) =~ ~s|describe "Event" do|
      end

      # the aggregate contributes its apply test to each of them
      assert read(
               repo,
               "test/sportipedia/catalog/equipment/widget/events/widget_relabelled_test.exs"
             ) =~
               "test \"applies widget-relabelled to aggregate state\" do"
    end

    test "the projector run registers into the subdomain supervisor it finds", %{repo: repo} do
      {:ok, _} = FixtureRepo.run(repo, :event, ["widget-created"])
      {:ok, _} = FixtureRepo.run(repo, :read_model, ["read-model.widget"])
      {:ok, _} = FixtureRepo.run(repo, :projector, ["widget-created"])

      supervisor = read(repo, "lib/sportipedia/catalog/supervisor.ex")
      assert supervisor =~ "Sportipedia.Catalog.Equipment.Widget.WidgetProjector"
    end

    test "a registration host the run needs is created when absent", %{repo: repo} do
      FixtureRepo.remove(repo, "services/api/lib/sportipedia/catalog/equipment/router.ex")

      {:ok, _} = FixtureRepo.run(repo, :event, ["widget-created"])
      {:ok, _} = FixtureRepo.run(repo, :command_handler, ["create-widget"])
      {:ok, _} = FixtureRepo.run(repo, :command, ["create-widget", "--template", "create"])
      {:ok, _} = FixtureRepo.run(repo, :aggregate, ["aggregate.widget"])

      router = read(repo, "lib/sportipedia/catalog/equipment/router.ex")
      assert router =~ "defmodule Sportipedia.Catalog.Equipment.Router do"
      assert router =~ "use Commanded.Commands.Router"
      assert router =~ "middleware Identity"
      assert router =~ ~s|identify WidgetAggregate, by: :id, prefix: "equipment/widget/"|

      assert router =~
               "dispatch CreateWidget, to: CreateWidgetHandler, aggregate: WidgetAggregate"

      app = read(repo, "lib/sportipedia/catalog/application.ex")
      assert app =~ "use Commanded.Application, otp_app: :sportipedia"
      assert app =~ "router Sportipedia.Catalog.Equipment.Router"
    end

    test "a test file appears with the first test written into it", %{repo: repo} do
      # the aggregate's contribution waits on its events: nothing may be written
      {:ok, results} = FixtureRepo.run(repo, :aggregate, ["aggregate.widget"])
      refute FixtureRepo.exists?(repo, @event_test), "an empty test file was created"

      assert Enum.any?(results, fn
               {:deferred, path, _} -> String.contains?(path, "events/widget_created_test.exs")
               _ -> false
             end),
             inspect(results)

      # the event has a test to write, so it creates the file
      {:ok, _} = FixtureRepo.run(repo, :event, ["widget-created"])
      assert FixtureRepo.exists?(repo, @event_test)
      assert read(repo, @event_test) =~ ~s|describe "Event"|

      # the aggregate merges into the file that exists now, and the event run's
      # closure already back-filled it
      {:ok, _} = FixtureRepo.run(repo, :aggregate, ["aggregate.widget"])
      content = read(repo, @event_test)
      assert content =~ ~s|describe "Event"|
      assert content =~ ~s|describe "Aggregate"|

      # fixed point for that file: the other events are not generated yet, so
      # the aggregate still defers on them — but the file it wrote is final
      {:ok, again} = FixtureRepo.check(repo, :aggregate, ["aggregate.widget"])
      assert {:unchanged, @event_test} in again, inspect(again)
    end

    test "--check promises a test file only if a test would be written", %{repo: repo} do
      {:ok, results} = FixtureRepo.check(repo, :aggregate, ["aggregate.widget"])

      refute Enum.any?(results, fn
               {:checked, @event_test, ids} -> :whole_file in ids
               _ -> false
             end),
             "check promised a file the run would not write: #{inspect(results)}"

      {:ok, results} = FixtureRepo.check(repo, :event, ["widget-created"])

      assert Enum.any?(results, fn
               {:checked, @event_test, ids} -> :whole_file in ids
               _ -> false
             end),
             "the event has a test to write: #{inspect(results)}"
    end

    test "args override inference", %{repo: repo} do
      {:ok, results} =
        FixtureRepo.run(repo, :command, [
          "create-widget",
          "--template",
          "create",
          "--constituent",
          "gadget"
        ])

      assert Enum.any?(results, fn
               {:created, path} -> String.contains?(path, "gadget")
               _ -> false
             end)
    end

    test "an unknown option and a missing element are usage errors", %{repo: repo} do
      assert {:error, message} = FixtureRepo.run(repo, :command, ["--wat"])
      assert message =~ "unknown option"

      assert {:error, message} = FixtureRepo.run(repo, :command, [])
      assert message =~ "usage: mix sp.gen.command"
    end

    test "a template that does not fit the element or the blueprint is refused", %{repo: repo} do
      assert {:error, message} =
               FixtureRepo.run(repo, :controller, ["read-widget", "--template", "create"])

      assert message =~ "does not fit a query"

      assert {:error, message} =
               FixtureRepo.run(repo, :command, ["create-widget", "--template", "read"])

      assert message =~ "not supported"

      assert {:error, message} =
               FixtureRepo.run(repo, :command_handler, ["create-widget", "--template", "create"])

      assert message =~ "fixed"
    end

    test "an element of the wrong kind is refused", %{repo: repo} do
      assert {:error, message} =
               FixtureRepo.run(repo, :command, ["widget-created", "--template", "create"])

      assert message =~ "command"
      assert message =~ "event"
    end

    test "a model file holding several elements is refused", %{repo: repo} do
      assert {:error, message} =
               FixtureRepo.run(repo, :command, [
                 "docs/domain-model/actors.esdm.yaml",
                 "--template",
                 "create"
               ])

      assert message =~ "more than one element"
    end
  end

  # ------------------------------------------------------------ fixed point

  describe "the full chain" do
    setup do
      %{repo: FixtureRepo.build()}
    end

    test "every generated file parses, is formatted, and a second run changes nothing", %{
      repo: repo
    } do
      generate(repo)

      for path <- FixtureRepo.generated_paths(repo) do
        source = FixtureRepo.read(repo, path)
        assert String.ends_with?(source, "\n"), "missing trailing newline: #{path}"

        if String.ends_with?(path, [".ex", ".exs"]) do
          assert {:ok, _} = Code.string_to_quoted(source), "invalid syntax in #{path}"
        end
      end

      # the registration hosts picked everything up
      web_router = read(repo, "lib/sportipedia_web/router.ex")
      assert web_router =~ "scope \"/widgets\", Widget do"
      assert web_router =~ "post \"/create-widget\", WidgetController, :create_widget"
      assert web_router =~ "get \"/:id_or_slug\", WidgetController, :read_widget"
      assert web_router =~ "get \"/\", WidgetController, :list_widgets"

      # second pass of the whole chain: absolutely nothing changes
      for {generator, args} <- @chain do
        {:ok, results} = FixtureRepo.check(repo, generator, args)

        assert Enum.all?(results, &match?({:unchanged, _}, &1)),
               "#{generator} #{inspect(args)} wanted changes: #{inspect(results)}"
      end
    end

    test "order independence: the reversed chain converges to the same tree" do
      forward = FixtureRepo.build()
      reversed = FixtureRepo.build()

      generate(forward)

      for {generator, args} <- Enum.reverse(@chain) do
        assert {:ok, _} = FixtureRepo.run(reversed, generator, args),
               "#{generator} #{inspect(args)}"
      end

      assert FixtureRepo.generated_paths(forward) == FixtureRepo.generated_paths(reversed)

      for rel <- FixtureRepo.generated_paths(forward) do
        if String.ends_with?(rel, [".ex", ".exs"]) do
          # sibling order (describe blocks, routes) is an insertion history
          # question, the code is the answer — compare canonically. Non-Elixir
          # artifacts (bruno YAML) carry sequence numbers derived from the tree
          # as it was built, so they are compared by presence, not content.
          assert canon_sort(FixtureRepo.read(forward, rel)) ==
                   canon_sort(FixtureRepo.read(reversed, rel)),
                 "AST mismatch in #{rel}"
        end
      end

      # the reversed tree is a fixed point: a forward sweep changes nothing
      for {generator, args} <- @chain do
        {:ok, results} = FixtureRepo.check(reversed, generator, args)

        assert Enum.all?(results, &match?({:unchanged, _}, &1)),
               "#{generator} reversed drift: #{inspect(results)}"
      end
    end

    test "the canonical citizen matches the recorded snapshot", %{repo: repo} do
      generate(repo)
      actual = snapshot_text(repo)
      recorded = expected_snapshot_path()

      if System.get_env("SPGEN_UPDATE_SNAPSHOT") == "1" do
        File.mkdir_p!(Path.dirname(recorded))
        File.write!(recorded, actual)
      end

      assert File.exists?(recorded),
             "no snapshot recorded — run SPGEN_UPDATE_SNAPSHOT=1 mix test"

      assert actual == File.read!(recorded),
             "the generated tree moved off the recorded snapshot (SPGEN_UPDATE_SNAPSHOT=1 to re-record)"
    end
  end

  # ------------------------------------------------------------------ helpers

  # paths in these tests are either repo-rooted or relative to the API project
  defp read(repo, rel), do: FixtureRepo.read(repo, rooted(rel))
  defp rooted("services/" <> _ = rel), do: rel
  defp rooted(rel), do: "services/api/" <> rel

  # The generated tree as one reviewable text: every generated file, in path
  # order, as `== <path> ==` followed by its content.
  defp snapshot_text(repo) do
    repo
    |> FixtureRepo.generated_paths()
    |> Enum.map(fn rel -> "== " <> rel <> " ==\n" <> FixtureRepo.read(repo, rel) end)
    |> Enum.join("\n")
  end

  defp expected_snapshot_path do
    Path.expand("../../fixtures/snapshots/widget.txt", __DIR__)
  end

  # Canonical structure: every __block__ (module bodies, do-blocks) is replaced
  # by the sorted Macro.to_string of its expressions, so two trees with the
  # same code in any sibling order compare equal.
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
end
