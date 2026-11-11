defmodule SpGen.CreationAcceptanceTest do
  @moduledoc """
  Generating citizens into an empty repository: what a run creates, registers,
  defers, and refuses.
  """
  use ExUnit.Case, async: true

  import SpGen.Acceptance

  alias SpGen.{Context, Esdm, FixtureRepo}

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

      # One descriptor per field the rule names: `at-most-one-owner` speaks for
      # `coachId` *and* `teamId`, so it registers twice and the instrument-side
      # half can never disappear from a fresh build silently.
      assert Enum.map(ctx.validators, & &1.name) |> Enum.sort() == [
               "at-most-one-owner",
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
      operation = read(repo, operation_test())

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
      refute FixtureRepo.exists?(repo, event_test()), "an empty test file was created"

      assert Enum.any?(results, fn
               {:deferred, path, _} -> String.contains?(path, "events/widget_created_test.exs")
               _ -> false
             end),
             inspect(results)

      # the event has a test to write, so it creates the file
      {:ok, _} = FixtureRepo.run(repo, :event, ["widget-created"])
      assert FixtureRepo.exists?(repo, event_test())
      assert read(repo, event_test()) =~ ~s|describe "Event"|

      # the aggregate merges into the file that exists now, and the event run's
      # closure already back-filled it
      {:ok, _} = FixtureRepo.run(repo, :aggregate, ["aggregate.widget"])
      content = read(repo, event_test())
      assert content =~ ~s|describe "Event"|
      assert content =~ ~s|describe "Aggregate"|

      # fixed point for that file: the other events are not generated yet, so
      # the aggregate still defers on them — but the file it wrote is final
      {:ok, again} = FixtureRepo.check(repo, :aggregate, ["aggregate.widget"])
      assert {:unchanged, event_test()} in again, inspect(again)
    end

    test "--check promises a test file only if a test would be written", %{repo: repo} do
      {:ok, results} = FixtureRepo.check(repo, :aggregate, ["aggregate.widget"])

      refute Enum.any?(results, fn
               {:checked, event_test(), ids} -> :whole_file in ids
               _ -> false
             end),
             "check promised a file the run would not write: #{inspect(results)}"

      {:ok, results} = FixtureRepo.check(repo, :event, ["widget-created"])

      assert Enum.any?(results, fn
               {:checked, event_test(), ids} -> :whole_file in ids
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
end
