defmodule SpGenTest do
  @moduledoc """
  The fixture model's own contracts, and what the model states that the tool
  cannot realize. The generation acceptance themes live in their own modules —
  exunit only schedules async MODULES in parallel, so one big file would be one
  serial lane. See `tools/spgen/contributions.md`.
  """
  use ExUnit.Case, async: true

  import SpGen.Acceptance

  alias SpGen.{Esdm, FixtureRepo}

  # ------------------------------------------------------------------ model

  describe "the fixture model" do
    setup do
      %{repo: FixtureRepo.build()}
    end

    test "loads through the virtual filesystem", %{repo: repo} do
      {:ok, model} = Esdm.load(Path.join(repo.root, "docs/domain-model"), fs: repo.fs)

      # every kind the fixture model states arrives, and by name — the point is
      # that the VFS backend reads the whole model, not which names sort first
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
        assert kind in kinds
      end

      assert Enum.map(model.elements, & &1.name) |> Enum.sort() ==
               Enum.sort([
                 "sport",
                 "sport",
                 "catalog",
                 "user",
                 "admin",
                 "guest",
                 "widget",
                 "widget",
                 "create-widget",
                 "edit-widget",
                 "archive-widget",
                 "note-widget",
                 "relabel-widget",
                 "widget-created",
                 "widget-edited",
                 "widget-archived",
                 "widget-noted",
                 "widget-relabelled",
                 "widget-rename-logged",
                 "manage-widgets",
                 "list-widgets",
                 "read-widget"
               ])
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

  # --------------------------------------------------- rules beyond the tool

  describe "what the model states that the tool cannot realize" do
    setup do
      %{repo: FixtureRepo.build()}
    end

    test "a rule no invariant pattern claims is named in the report", %{repo: repo} do
      {:ok, results} =
        FixtureRepo.check(repo, :command, ["archive-widget", "--template", "delete"])

      # `no-archive-when-in-use` names no field of the citizen at all, so no
      # command can ever realize it; `at-most-one-owner` names `coachId`, which
      # create-widget carries and does realize — reporting it here would be
      # noise about this run instead of a fact about the model
      assert {:unresolved, "command.archive-widget", details} =
               Enum.find(results, &match?({:unresolved, _, _}, &1))

      assert [detail] = details
      assert detail =~ "no-archive-when-in-use"
      assert detail =~ "no invariant pattern realizes it"
      refute detail =~ "at-most-one-owner"
    end

    test "a validates line that lost its rule is reported, never appended twice", %{} do
      repo = generated_repo()

      # what a hand edit leaves behind: the presence check without the
      # constraint the model states for the same field
      FixtureRepo.write(
        repo,
        archive_command(),
        read(repo, archive_command())
        |> String.replace(", by: [function: &WidgetExists.validate/2, allow_blank: true]", "")
      )

      args = ["archive-widget", "--template", "delete"]

      {:ok, results} = FixtureRepo.check(repo, :command, args)

      # in check mode the gap rides inside the row for that file, like a
      # deferred or unplaceable unit does
      assert {:checked, archive_command(), ids} =
               Enum.find(results, &match?({:checked, archive_command(), _}, &1))

      assert {:stale, {:validates, "id"},
              ["add by: [function: &WidgetExists.validate/2, allow_blank: true]"]} in ids

      # the run reports the same gap and writes nothing: appending a second
      # `validates :id` line would *replace* the first in Vex, not extend it
      {:ok, results} = FixtureRepo.run(repo, :command, args)

      assert {:stale, archive_command(), _} = Enum.find(results, &match?({:stale, _, _}, &1))

      source = read(repo, archive_command())
      assert length(Regex.scan(~r/validates :id/, source)) == 1
      assert source =~ "validates :id, presence: true\n"
    end
  end

  # ------------------------------------------------------- test-support projection

  describe "declared operations" do
    setup do
      %{repo: FixtureRepo.build()}
    end

    @edit_command "services/api/lib/sportipedia/catalog/equipment/widget/operations/edit_widget/command.ex"

    test "a command run without --template resolves the declared operation", %{repo: repo} do
      {:ok, _} = FixtureRepo.run(repo, :read_model, ["read-model.widget"])
      {:ok, _} = FixtureRepo.run(repo, :command, ["edit-widget"])

      declared = FixtureRepo.read(repo, @edit_command)
      assert declared =~ "defmodule Sportipedia.Catalog.Equipment.Widget.Command.EditWidget do"

      # and it is the very shape the explicit flag would have picked
      flagged = FixtureRepo.build()
      {:ok, _} = FixtureRepo.run(flagged, :read_model, ["read-model.widget"])
      {:ok, _} = FixtureRepo.run(flagged, :command, ["edit-widget", "--template", "update"])

      assert declared == FixtureRepo.read(flagged, @edit_command)
    end

    test "a command without a declaration is refused — naming it is a decision", %{repo: repo} do
      {:ok, _} = FixtureRepo.run(repo, :read_model, ["read-model.widget"])

      command_yaml = "docs/domain-model/catalog/equipment/command.edit-widget.esdm.yaml"

      FixtureRepo.write(
        repo,
        command_yaml,
        repo
        |> FixtureRepo.read(command_yaml)
        |> String.replace("    spgen.operation: update\n", "")
      )

      assert {:error, message} = FixtureRepo.run(repo, :command, ["edit-widget"])
      assert message =~ "no operation declared for command edit-widget"
      refute FixtureRepo.exists?(repo, @edit_command)
    end
  end
end
