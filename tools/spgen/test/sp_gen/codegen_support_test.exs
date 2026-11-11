defmodule SpGen.TestSupportAcceptanceTest do
  @moduledoc """
  Test support: the fixture projection, the factory ledger, and the generated
  tests that consume the fixtures they were given.
  """
  use ExUnit.Case, async: true

  import SpGen.Acceptance

  alias SpGen.FixtureRepo

  # ------------------------------------------------------- test-support projection

  describe "test-support projections" do
    setup do
      %{repo: FixtureRepo.build()}
    end

    test "a created run lands both outputs", %{repo: repo} do
      # the read model's closure already converges the test-support citizens —
      # the explicit run confirms the fixed point and the content is what we
      # actually promise
      {:ok, _} = FixtureRepo.run(repo, :read_model, ["read-model.widget"])
      {:ok, _} = FixtureRepo.run(repo, :test_support, ["read-model.widget"])

      fixtures = FixtureRepo.read(repo, support_fixture())
      assert fixtures =~ "def classic_widget do"
      assert fixtures =~ ~s|id: UUID.uuid5(:dns, "equipment:widget:classic-widget")|
      assert fixtures =~ "def widgets, do: [classic_widget(), gadget_2000()]"

      ledger = FixtureRepo.read(repo, support_ledger())
      assert ledger =~ "def new_widget(%WidgetReadModel{} = fixture) do"
      assert ledger =~ "def new_widget(attributes) when is_map(attributes) do"
      assert ledger =~ "def new_widgets(attribute_collection) do"
    end

    test "the projection rewrites a hand-edited file back to the model — twice is nothing", %{
      repo: repo
    } do
      {:ok, _} = FixtureRepo.run(repo, :read_model, ["read-model.widget"])
      {:ok, _} = FixtureRepo.run(repo, :test_support, ["read-model.widget"])
      canonical = FixtureRepo.read(repo, support_fixture())

      FixtureRepo.write(
        repo,
        support_fixture(),
        """
        defmodule Sportipedia.TestSupport.Catalog.Equipment.WidgetFixtures do
          def hand_added, do: :nope
        end
        """
      )

      {:ok, results} = FixtureRepo.run(repo, :test_support, ["read-model.widget"])

      assert Enum.any?(results, fn
               {:rewritten, path} -> path == support_fixture()
               _ -> false
             end)

      assert FixtureRepo.read(repo, support_fixture()) == canonical

      # fixed point: the re-run finds the projection equal to its render
      {:ok, again} = FixtureRepo.run(repo, :test_support, ["read-model.widget"])

      refute Enum.any?(again, fn
               {:rewritten, path} -> path == support_fixture()
               _ -> false
             end)
    end

    test "--check reports the rewrite in future tense and writes nothing", %{repo: repo} do
      {:ok, _} = FixtureRepo.run(repo, :read_model, ["read-model.widget"])
      {:ok, _} = FixtureRepo.run(repo, :test_support, ["read-model.widget"])

      FixtureRepo.write(repo, support_fixture(), "# hand edit, drift\n")

      {:ok, results} = FixtureRepo.check(repo, :test_support, ["read-model.widget"])

      assert Enum.any?(results, fn
               {:checked, path, ids} -> path == support_fixture() and Enum.member?(ids, :rewrite)
               _ -> false
             end)

      assert FixtureRepo.read(repo, support_fixture()) == "# hand edit, drift\n"

      assert SpGen.Report.render([{:checked, support_fixture(), [:rewrite]}])
             |> Enum.any?(&(&1 =~ "Would rewrite"))
    end

    test "the run is self-sufficient: its read-model dependency lands in the same run", %{
      repo: _repo
    } do
      repo = FixtureRepo.build(only: ["domain-model"])
      read_model = "services/api/lib/sportipedia/catalog/equipment/widget/read_model.ex"

      {:ok, results} = FixtureRepo.run(repo, :test_support, ["read-model.widget"])

      # nothing waits: the read model arrives as a dependency, fixtures and
      # ledger land after it, in one run
      refute Enum.any?(results, &match?({:deferred, _, _}, &1))
      assert FixtureRepo.exists?(repo, read_model)
      assert FixtureRepo.exists?(repo, support_fixture())
      assert FixtureRepo.exists?(repo, support_ledger())

      assert FixtureRepo.read(repo, support_ledger()) =~
               "def new_widget(%WidgetReadModel{} = fixture)"
    end

    test "a creating test-support run leaves human deletions in neighbors alone — :all runs still backfill",
         %{} do
      repo = generated_repo()
      event = "services/api/lib/sportipedia/catalog/equipment/widget/events/widget_created.ex"

      stripped =
        FixtureRepo.read(repo, event)
        |> String.replace("    field :title, String.t(), enforce: true\n", "")

      assert stripped != FixtureRepo.read(repo, event)
      FixtureRepo.write(repo, event, stripped)

      # force a *creating* test_support run: remove its projection
      FixtureRepo.remove(repo, support_fixture())
      {:ok, _} = FixtureRepo.run(repo, :test_support, ["read-model.widget"])

      assert FixtureRepo.exists?(repo, support_fixture())
      # its scope is :none — the foreign citizen keeps the human's deletion
      refute FixtureRepo.read(repo, event) =~ "field :title"

      # the mechanism survives where it is owed: an `:all` generator whose run
      # creates a citizen still sweeps the neighborhood
      handler =
        "services/api/lib/sportipedia/catalog/equipment/widget/operations/create_widget/handler.ex"

      FixtureRepo.remove(repo, handler)
      {:ok, _} = FixtureRepo.run(repo, :command_handler, ["create-widget"])

      assert FixtureRepo.read(repo, event) =~ "field :title"
    end

    test "a read model without examples generates the ledger only", %{repo: repo} do
      text =
        FixtureRepo.read(repo, "docs/domain-model/catalog/equipment/read-model.widget.esdm.yaml")

      [without_examples | _] = String.split(text, "  examples:")

      FixtureRepo.write(
        repo,
        "docs/domain-model/catalog/equipment/read-model.widget.esdm.yaml",
        without_examples
      )

      {:ok, _} = FixtureRepo.run(repo, :read_model, ["read-model.widget"])
      {:ok, _} = FixtureRepo.run(repo, :test_support, ["read-model.widget"])

      refute FixtureRepo.exists?(repo, support_fixture())
      assert FixtureRepo.exists?(repo, support_ledger())

      assert FixtureRepo.read(repo, support_ledger()) =~
               "def new_widgets(attribute_collection) do"
    end

    test "a model violating the fixture contract fails the run and writes nothing", %{repo: repo} do
      {:ok, _} = FixtureRepo.run(repo, :read_model, ["read-model.widget"])
      {:ok, _} = FixtureRepo.run(repo, :test_support, ["read-model.widget"])
      canonical_fixtures = FixtureRepo.read(repo, support_fixture())
      canonical_ledger = FixtureRepo.read(repo, support_ledger())

      text =
        FixtureRepo.read(repo, "docs/domain-model/catalog/equipment/read-model.widget.esdm.yaml")

      FixtureRepo.write(
        repo,
        "docs/domain-model/catalog/equipment/read-model.widget.esdm.yaml",
        String.replace(text, "equipment:widget:classic-widget", "equipment:widget:Classic Widget")
      )

      assert {:error, message} = FixtureRepo.run(repo, :test_support, ["read-model.widget"])
      assert message =~ "is not a fixture key"

      # the violation aborts before planning: what the model justified stands,
      # nothing corrupt was added
      assert FixtureRepo.read(repo, support_fixture()) == canonical_fixtures
      assert FixtureRepo.read(repo, support_ledger()) == canonical_ledger
    end
  end

  # ------------------------------------------------ tests consume the fixtures

  describe "generated tests consume the generated fixtures" do
    setup do
      %{repo: generated_repo()}
    end

    @read_endpoint "test/sportipedia_web/catalog/equipment/widget/operations/read_widget_endpoint_test.exs"
    @list_endpoint "test/sportipedia_web/catalog/equipment/widget/operations/list_widgets_endpoint_test.exs"
    @create_endpoint "test/sportipedia_web/catalog/equipment/widget/operations/create_widget_endpoint_test.exs"
    @created_event "test/sportipedia/catalog/equipment/widget/events/widget_created_test.exs"

    test "a read seeds the model's fixture row, not a re-dispatched create command", %{repo: repo} do
      test = read(repo, @read_endpoint)

      assert test =~ ~s|{:ok, %{id: id}} = Equipment.new_widget(WidgetFixtures.classic_widget())|
      assert test =~ "alias Sportipedia.TestSupport.Catalog.Equipment"
      assert test =~ "alias Sportipedia.TestSupport.Catalog.Equipment.WidgetFixtures"
      refute test =~ "Widget.create_widget("
    end

    test "a collection seeds every fixture through the plural", %{repo: repo} do
      test = read(repo, @list_endpoint)

      assert test =~ ~s|{:ok, _} = Equipment.new_widgets(WidgetFixtures.widgets())|
    end

    test "a command test dispatches through the public API and aliases no fixture", %{repo: repo} do
      test = read(repo, @create_endpoint)

      refute test =~ "Sportipedia.TestSupport"
      refute test =~ "new_widget("
    end

    test "an event struct carries the fixture's id and the referenced fixture's id", %{
      repo: repo
    } do
      test = read(repo, @created_event)

      # the fact's own id is the fixture key's uuid5 — the projector writes the
      # row under it, so `Repo.get(read_model, event.id)` finds the seeded row
      assert test =~ ~S|id: UUID.uuid5(:dns, "equipment:widget:classic-widget")|
      # a `*Id` reference matches the referenced fixture's id by construction
      assert test =~ ~S|coachId: UUID.uuid5(:dns, "equipment:coach:head-coach")|
      # the example data replaces the throwaway `sample-*` strings
      refute test =~ "sample-title"
    end

    test "an example-less read model still seeds through the create command", %{repo: _repo} do
      repo = FixtureRepo.build()

      text =
        FixtureRepo.read(repo, "docs/domain-model/catalog/equipment/read-model.widget.esdm.yaml")

      [without_examples | _] = String.split(text, "  examples:")

      FixtureRepo.write(
        repo,
        "docs/domain-model/catalog/equipment/read-model.widget.esdm.yaml",
        without_examples
      )

      # Only the generator that owns the file under test: this claim is about how
      # a read seeds when the model states no example row, and the endpoint test
      # is `spgen controller`'s output. Running the whole chain here would
      # re-prove the tree the snapshot already records, at forty times the cost.
      {:ok, _} = FixtureRepo.run(repo, :controller, ["read-widget"])

      read_test = read(repo, @read_endpoint)
      refute read_test =~ "Sportipedia.TestSupport"
      assert read_test =~ "Widget.create_widget("
    end
  end

  # ------------------------------------------------------------------ helpers

  # paths in these tests are either repo-rooted or relative to the API project
end
