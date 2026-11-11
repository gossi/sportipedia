defmodule SpGen.CheckTest do
  @moduledoc """
  `mix sp.check`'s engine against the fixture repository: the checks are the
  generators' own contracts — a green model here must always be generatable.
  """
  use ExUnit.Case, async: true

  alias SpGen.{Check, FixtureRepo}

  @rm "docs/domain-model/catalog/equipment/read-model.widget.esdm.yaml"
  @cmd "docs/domain-model/catalog/equipment/command.create-widget.esdm.yaml"
  @query "docs/domain-model/catalog/equipment/query.list-widgets.esdm.yaml"

  defp rm_text(repo), do: FixtureRepo.read(repo, @rm)
  defp cmd_text(repo), do: FixtureRepo.read(repo, @cmd)
  defp query_text(repo), do: FixtureRepo.read(repo, @query)

  describe "the fixture model as a whole" do
    setup do
      %{repo: FixtureRepo.build()}
    end

    test "reports the dangling fixture references of the closed world", %{repo: repo} do
      assert {:ok, findings} = Check.run(["--root", repo.root], fs: repo.fs)

      messages = Enum.map(findings, & &1.message)

      assert length(messages) == 2
      assert Enum.any?(messages, &(&1 =~ "equipment:coach:head-coach"))
      assert Enum.any?(messages, &(&1 =~ "equipment:team:first-team"))

      for finding <- findings, do: assert(finding.file =~ "read-model.widget.esdm.yaml")
    end

    test "the prose contracts hold in the fixtures: no findings from descriptions", %{
      repo: repo
    } do
      assert {:ok, findings} = Check.run(["--root", repo.root], fs: repo.fs)
      refute Enum.any?(findings, &(&1.message =~ "no description"))
    end
  end

  describe "scoped runs" do
    setup do
      %{repo: FixtureRepo.build()}
    end

    test "an element address checks exactly that element — no cross-model findings", %{repo: repo} do
      assert {:ok, []} = Check.run(["read-model.widget", "--root", repo.root], fs: repo.fs)
    end

    test "a directory argument checks every element under it", %{repo: repo} do
      dir = Path.join([repo.root, "docs", "domain-model", "catalog"])

      assert {:ok, findings} = Check.run([dir, "--root", repo.root], fs: repo.fs)
      # scoped: the dangling-reference sweep belongs to whole-model mode only
      assert findings == []
    end

    test "an unresolvable address is a usage error", %{repo: repo} do
      assert {:error, message} =
               Check.run(["read-model.nonesuch", "--root", repo.root], fs: repo.fs)

      assert message =~ "unknown_element" or message =~ "no such element"
    end
  end

  describe "findings on a model that cannot be generated" do
    setup do
      %{repo: FixtureRepo.build()}
    end

    test "a broken example key surfaces as a fixture-contract finding", %{repo: repo} do
      FixtureRepo.write(
        repo,
        @rm,
        String.replace(
          rm_text(repo),
          "equipment:widget:classic-widget",
          "equipment:widget:Classic Widget"
        )
      )

      assert {:ok, findings} = Check.run(["--root", repo.root], fs: repo.fs)
      assert Enum.any?(findings, &(&1.message =~ "is not a fixture key"))
    end

    test "a missing description surfaces as a prose finding", %{repo: repo} do
      FixtureRepo.write(repo, @cmd, drop_description(cmd_text(repo)))

      assert {:ok, findings} = Check.run(["--root", repo.root], fs: repo.fs)

      assert Enum.any?(findings, fn finding ->
               finding.message =~ "no description" and finding.file =~ "command.create-widget"
             end)
    end

    test "a projection whose decision is missing is found", %{repo: repo} do
      FixtureRepo.write(
        repo,
        @rm,
        rm_text(repo) |> String.replace("    spgen.operation.widget-created: create\n", "")
      )

      assert {:ok, findings} = Check.run(["--root", repo.root], fs: repo.fs)

      assert Enum.any?(
               findings,
               &(&1.message =~ "has no spgen.operation.widget-created decision")
             )
    end

    test "`none` on a projected event is a contradiction", %{repo: repo} do
      FixtureRepo.write(
        repo,
        @rm,
        rm_text(repo)
        |> String.replace(
          "spgen.operation.widget-created: create",
          "spgen.operation.widget-created: none"
        )
      )

      assert {:ok, findings} = Check.run(["--root", repo.root], fs: repo.fs)

      assert Enum.any?(
               findings,
               &(&1.message =~ "none, but the read model projects widget-created")
             )
    end

    test "an orphan decision for an event the read model never mentions is found", %{repo: repo} do
      FixtureRepo.write(
        repo,
        @rm,
        rm_text(repo)
        |> String.replace(
          "    spgen.operation.widget-created: create\n",
          "    spgen.operation.widget-created: create\n    spgen.operation.widget-teleported: none\n"
        )
      )

      assert {:ok, findings} = Check.run(["--root", repo.root], fs: repo.fs)

      assert Enum.any?(
               findings,
               &(&1.message =~
                   "spgen.operation.widget-teleported names no event of aggregate widget")
             )
    end

    test "a command without an operation is an open completeness question", %{repo: repo} do
      FixtureRepo.write(
        repo,
        @cmd,
        cmd_text(repo) |> String.replace("    spgen.operation: create\n", "")
      )

      assert {:ok, findings} = Check.run(["--root", repo.root], fs: repo.fs)

      assert Enum.any?(findings, fn f ->
               f.message =~ "no metadata.annotations.spgen.operation" and
                 f.file =~ "command.create-widget"
             end)
    end

    test "a key that names the wrong home is found even beside the reference sweep", %{repo: repo} do
      FixtureRepo.write(
        repo,
        @rm,
        String.replace(
          rm_text(repo),
          "equipment:widget:classic-widget",
          "catalog:widget:classic-widget"
        )
      )

      assert {:ok, findings} = Check.run(["--root", repo.root], fs: repo.fs)
      assert Enum.any?(findings, &(&1.message =~ "a key must name its own home"))
    end
  end

  # A query's `spgen.operation` is the declaration that lets `spgen query` ship a
  # working body instead of a marker, so the value is checked when present — and
  # its absence is silence, not a gap: `result.type: array` answers the same
  # question and every model written before the annotation stays valid.
  describe "a query's declared operation" do
    setup do
      %{repo: FixtureRepo.build()}
    end

    test "declaring collection over an array is clean", %{repo: repo} do
      assert {:ok, []} = Check.run(["query.list-widgets", "--root", repo.root], fs: repo.fs)
    end

    test "declaring none is clean — the result shape answers it", %{repo: repo} do
      FixtureRepo.write(
        repo,
        @query,
        query_text(repo) |> String.replace("    spgen.operation: collection\n", "")
      )

      assert {:ok, []} = Check.run(["query.list-widgets", "--root", repo.root], fs: repo.fs)
    end

    test "a value outside read|collection is found", %{repo: repo} do
      rewrite_query(repo, "spgen.operation: everything")

      assert {:ok, findings} = Check.run(["query.list-widgets", "--root", repo.root], fs: repo.fs)

      assert Enum.any?(
               findings,
               &(&1.message =~ "spgen.operation: \"everything\" is not read|collection")
             )
    end

    test "a declaration that contradicts the result is found", %{repo: repo} do
      rewrite_query(repo, "spgen.operation: read")

      assert {:ok, findings} = Check.run(["query.list-widgets", "--root", repo.root], fs: repo.fs)

      assert Enum.any?(
               findings,
               &(&1.message =~ "spgen.operation: read contradicts result.type: array")
             )
    end

    test "a per-event key on a query is found — it names no event", %{repo: repo} do
      FixtureRepo.write(
        repo,
        @query,
        query_text(repo)
        |> String.replace(
          "    spgen.operation: collection\n",
          "    spgen.operation: collection\n    spgen.operation.widget-created: create\n"
        )
      )

      assert {:ok, findings} = Check.run(["query.list-widgets", "--root", repo.root], fs: repo.fs)

      assert Enum.any?(
               findings,
               &(&1.message =~ "queries declare a bare spgen.operation (read|collection)")
             )
    end

    test "a read query declaring read is clean", %{repo: repo} do
      read = "docs/domain-model/catalog/equipment/query.read-widget.esdm.yaml"

      FixtureRepo.write(
        repo,
        read,
        FixtureRepo.read(repo, read)
        |> String.replace(
          "readModel: widget\n",
          "readModel: widget\nmetadata:\n  annotations:\n    spgen.operation: read\n"
        )
      )

      assert {:ok, []} = Check.run(["query.read-widget", "--root", repo.root], fs: repo.fs)
    end
  end

  defp rewrite_query(repo, annotation) do
    FixtureRepo.write(
      repo,
      @query,
      query_text(repo) |> String.replace("spgen.operation: collection", annotation)
    )
  end

  defp drop_description(text) do
    text
    |> String.split("\n")
    |> Enum.reject(&Regex.match?(~r/^description:/, &1))
    |> Enum.join("\n")
  end
end
