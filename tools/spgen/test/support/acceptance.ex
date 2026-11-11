defmodule SpGen.Acceptance do
  @moduledoc """
  Shared vocabulary for the end-to-end generator acceptance tests.

  These tests are split across several modules — not because the subjects
  differ, but because ExUnit schedules **async modules** concurrently while the
  tests inside one module run one after another: a single 45-test file is one
  serial lane on an eleven-core machine. Each file below owns a theme
  (creation, the full chain, queries, test support, the model's limits) and
  imports this module for what they share.

  What is shared is deliberately narrow: the build sequence, the tree it
  produces, and the reading of a repository. Nothing here decides what a test
  asserts.
  """

  import ExUnit.Assertions

  alias SpGen.FixtureRepo

  @event_test "services/api/test/sportipedia/catalog/equipment/widget/events/widget_created_test.exs"
  @operation_test "services/api/test/sportipedia/catalog/equipment/widget/operations/create_widget_test.exs"
  @archive_command "services/api/lib/sportipedia/catalog/equipment/widget/operations/archive_widget/command.ex"
  @support_fixture "services/api/test/support/catalog/equipment/fixtures/widgets.ex"
  @support_ledger "services/api/test/support/catalog/equipment/equipment.ex"

  # The shared paths are MACROS, not functions: a test writes
  # `match?({:checked, archive_command(), _}, row)`, and a pattern only accepts a
  # literal. Expanding to the string keeps each name usable both as a term and
  # inside a pattern.
  @doc "The event test file the widget citizen's events share."
  defmacro event_test, do: @event_test
  @doc "The operation test file `create-widget` writes into."
  defmacro operation_test, do: @operation_test
  @doc "The archive command's file."
  defmacro archive_command, do: @archive_command
  @doc "The generated fixtures module."
  defmacro support_fixture, do: @support_fixture
  @doc "The composite's factory ledger."
  defmacro support_ledger, do: @support_ledger

  @doc """
  Every generator the widget citizen needs, in the order the tool documents.
  Also the recorded build sequence: a chain that stops half-way leaves gates
  waiting, and the fixed-point assertions below assume it completed.
  """
  def chain do
    [
      {:read_model, ["read-model.widget"]},
      {:test_support, ["read-model.widget"]},
      {:event, ["widget-created"]},
      {:event, ["widget-edited"]},
      {:event, ["widget-archived"]},
      {:event, ["widget-relabelled"]},
      {:event, ["widget-rename-logged"]},
      {:event, ["widget-noted"]},
      {:aggregate, ["aggregate.widget"]},
      {:query, ["read-widget"]},
      {:query, ["list-widgets"]},
      {:internal_api, ["read-model.widget"]},
      {:command, ["create-widget", "--template", "create"]},
      {:command, ["edit-widget", "--template", "update"]},
      {:command, ["archive-widget", "--template", "delete"]},
      {:command, ["note-widget", "--template", "none"]},
      {:command_handler, ["create-widget"]},
      {:command_handler, ["edit-widget"]},
      {:command_handler, ["archive-widget"]},
      {:command_handler, ["note-widget"]},
      {:projector, ["widget-created"]},
      {:projector, ["widget-edited"]},
      {:policy, ["create-widget"]},
      {:policy, ["read-widget"]},
      {:policy, ["list-widgets"]},
      {:policy, ["note-widget"]},
      {:public_api, ["create-widget"]},
      {:public_api, ["read-widget"]},
      {:public_api, ["list-widgets"]},
      {:public_api, ["note-widget"]},
      {:view, ["read-model.widget"]},
      {:schema, ["read-model.widget"]},
      {:schema, ["create-widget"]},
      {:schema, ["note-widget"]},
      {:schema, ["list-widgets"]},
      {:controller, ["create-widget"]},
      {:controller, ["read-widget"]},
      {:controller, ["list-widgets"]},
      {:controller, ["note-widget"]},
      {:bruno, ["create-widget"]},
      {:bruno, ["read-widget"]},
      {:bruno, ["list-widgets"]},
      {:bruno, ["note-widget"]}
    ]
  end

  @doc "Runs the whole chain into `repo`, failing loudly on the first refusal."
  def generate(repo) do
    for {generator, args} <- chain() do
      assert {:ok, _} = FixtureRepo.run(repo, generator, args), "#{generator} #{inspect(args)}"
    end
  end

  @doc """
  The full chain, built AT MOST ONCE per session and only for the tests that ask
  for it. A generator run costs what the neighbourhood closure costs, so thirty
  of them is the suite's dominant expense — and paying it per test buys no extra
  truth: the tree a test reads is the tree this produced.

  Tests that generate from an EMPTY repository (creation behaviour, order
  independence, refusals) keep their own `FixtureRepo.build/1`.
  """
  def generated_tree do
    FixtureRepo.shared(:full_chain, fn ->
      repo = FixtureRepo.build()
      generate(repo)
      FixtureRepo.contents(repo)
    end)
  end

  @doc "A private copy of the fully generated tree — write it freely."
  def generated_repo, do: FixtureRepo.restore(generated_tree())

  @doc "Content of a generated file; accepts a repo-relative or API-relative path."
  def read(repo, rel), do: FixtureRepo.read(repo, rooted(rel))

  @doc "API-relative path → repo-relative path."
  def rooted("services/" <> _ = rel), do: rel
  def rooted(rel), do: "services/api/" <> rel

  @doc """
  The rows of a `--check` sweep that would change the tree. `{:unresolved, _, _}`
  rows name model rules no invariant pattern realizes — the run writes nothing
  for them — so they are not drift and a fixed point keeps reporting them.
  """
  def writes(results) do
    results
    |> Enum.reject(&match?({:unchanged, _}, &1))
    |> Enum.reject(&match?({:unresolved, _, _}, &1))
  end

  @doc "The generated tree as one reviewable text, in path order."
  def snapshot_text(repo) do
    repo
    |> FixtureRepo.generated_paths()
    |> Enum.map(fn rel -> "== " <> rel <> " ==\n" <> FixtureRepo.read(repo, rel) end)
    |> Enum.join("\n")
  end

  @doc "The recorded snapshot's path."
  def snapshot_path, do: Path.expand("../../fixtures/snapshots/widget.txt", __DIR__)

  @doc """
  Canonical structure: every `__block__` (module bodies, do-blocks) is replaced
  by the sorted `Macro.to_string` of its expressions, so two trees with the same
  code in any sibling order compare equal.
  """
  def canon_sort(text) do
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
