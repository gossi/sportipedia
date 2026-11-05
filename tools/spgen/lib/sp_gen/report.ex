defmodule SpGen.Report do
  @moduledoc """
  The operator-facing report: the result rows of a run (`t:SpGen.row/0`)
  rendered as grouped file lists — `Created`, `Updated`, `Ignored`, plus
  `Blocked` / `Failed` when they apply. An empty group prints no heading;
  paths show relative to their project root, not the repo.

  A deferred unit is not a failure — generation order never matters — so its
  file folds into `Ignored` with a `skipped:` note naming the generator to run
  first (`spgen internal_api`). `--check` rows read in future tense.
  """

  @typedoc "One report line, in print order."
  @type line :: String.t()

  @headings [:created, :updated, :ignored, :blocked, :failed]
  @labels %{
    created: "Created",
    updated: "Updated",
    ignored: "Ignored",
    blocked: "Blocked",
    failed: "Failed"
  }
  @check_labels %{created: "Would create", updated: "Would update"}

  # a path is stated once per run; the furthest-along state of a file wins
  # and the `skipped:` notes of every row touching that file accumulate
  @write_order [created: 0, updated: 1, ignored: 2]
  @write_groups Keyword.keys(@write_order)

  # project roots are noise in every line; the citizen path behind them is not
  @roots [
    "services/api/lib/sportipedia/",
    "services/api/lib/sportipedia_web/",
    "services/api/test/sportipedia/",
    "services/api/test/sportipedia_web/"
  ]

  @doc "Render the grouped report lines for one run."
  @spec render([SpGen.row()]) :: [line()]
  def render(rows) do
    check? = Enum.any?(rows, &match?({:checked, _, _}, &1))

    rows
    |> Enum.flat_map(&entries/1)
    |> groups()
    |> Enum.flat_map(&section(&1, check?))
  end

  @doc "Strip the project roots a report already implies."
  @spec display_path(String.t()) :: String.t()
  def display_path(path) do
    Enum.find_value(@roots, path, fn root ->
      if String.starts_with?(path, root), do: String.replace_prefix(path, root, "")
    end)
  end

  # ------------------------------------------------------------------ entries

  # one row becomes `{group, path, skipped}`; `:checked` rows resolve to the
  # group they would produce when the generator actually runs
  defp entries({:created, path}), do: [{:created, path, []}]
  defp entries({:merged, path, _ids}), do: [{:updated, path, []}]
  defp entries({:backfill, path, _ids}), do: [{:updated, path, []}]
  defp entries({:unchanged, path}), do: [{:ignored, path, []}]

  defp entries({:deferred, path, requests}),
    do: [{:ignored, path, Enum.map(requests, &elem(&1, 1))}]

  defp entries({:blocked, path, _ids}), do: [{:blocked, path, []}]
  defp entries({:error, path, _reason}), do: [{:failed, path, []}]

  defp entries({:checked, path, [:whole_file]}), do: [{:created, path, []}]

  defp entries({:checked, path, ids}) do
    skipped =
      Enum.flat_map(ids, fn
        {:deferred, _id, reasons} -> reasons
        _other -> []
      end)

    group =
      cond do
        Enum.any?(ids, &match?({:unplaceable, _}, &1)) -> :blocked
        Enum.any?(ids, &placeable?/1) -> :updated
        true -> :ignored
      end

    [{group, path, skipped}]
  end

  # a unit that would land if the generator ran: anything but a wrapped report
  defp placeable?({:deferred, _, _}), do: false
  defp placeable?({:unplaceable, _}), do: false
  defp placeable?(_id), do: true

  # ------------------------------------------------------------------- groups

  defp groups(entries) do
    {writes, problems} =
      Enum.split_with(entries, fn {group, _path, _skipped} -> group in @write_groups end)

    by_path =
      writes
      |> strongest()
      |> Enum.group_by(
        fn {_path, group, _notes} -> group end,
        fn {path, _group, notes} -> {path, notes} end
      )

    by_problem =
      problems
      |> Enum.uniq_by(fn {group, path, _notes} -> {group, path} end)
      |> Enum.group_by(
        fn {group, _path, _notes} -> group end,
        fn {_group, path, notes} -> {path, notes} end
      )

    @headings
    |> Enum.map(fn group ->
      items =
        Map.get(by_path, group, []) ++ Map.get(by_problem, group, [])

      {group, Enum.sort_by(items, fn {path, _notes} -> display_path(path) end)}
    end)
    |> Enum.reject(fn {_group, items} -> items == [] end)
  end

  # reduce to one entry per path: keep the strongest group, union the notes
  defp strongest(entries) do
    entries
    |> Enum.reduce(%{}, fn {group, path, skipped}, acc ->
      Map.update(acc, path, {path, group, MapSet.new(skipped)}, &merge(&1, group, skipped))
    end)
    |> Map.values()
  end

  defp merge({path, best, notes}, group, skipped) do
    {path, if(rank(group) < rank(best), do: group, else: best),
     MapSet.union(notes, MapSet.new(skipped))}
  end

  defp rank(group), do: Keyword.fetch!(@write_order, group)

  # ------------------------------------------------------------------ section

  defp section({_group, []}, _check?), do: []

  defp section({group, items}, check?) do
    [label(group, check?) | Enum.map(items, &line/1)]
  end

  defp label(group, true = _check?), do: Map.get(@check_labels, group, @labels[group])
  defp label(group, _check?), do: @labels[group]

  defp line({path, skipped}), do: "  " <> display_path(path) <> note(skipped)

  defp note(skipped) do
    case commands(skipped) do
      [] -> ""
      commands -> "  skipped: " <> Enum.join(commands, ", ")
    end
  end

  # "validator unique_slug not generated (spgen command)" → "spgen command"
  defp commands(reasons) do
    reasons
    |> Enum.flat_map(&(Regex.run(~r/\((spgen [^)]*)\)/, &1, capture: :all_but_first) || []))
    |> Enum.uniq()
    |> Enum.sort()
  end
end
