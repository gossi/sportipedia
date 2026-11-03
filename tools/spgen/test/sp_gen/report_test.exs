defmodule SpGen.ReportTest do
  @moduledoc "The grouped operator report over the result rows of a run."
  use ExUnit.Case, async: true

  alias SpGen.Report

  @lib "services/api/lib/sportipedia/catalog/equipment/apparatus/"
  @test_root "services/api/test/sportipedia/catalog/equipment/apparatus/"

  # `{:deferred, path, [{unit_id, reason}]}` — one waiting unit
  defp waiting(unit_id, reason), do: [{unit_id, reason}]

  describe "render/1 grouping" do
    test "one heading per applied group, files indented below" do
      rows = [
        {:created, @lib <> "events/apparatus_cataloged.ex"},
        {:merged, @lib <> "router.ex", [{:dispatch, "CatalogApparatus"}]},
        {:unchanged, @lib <> "aggregate.ex"}
      ]

      assert Report.render(rows) == [
               "Created",
               "  catalog/equipment/apparatus/events/apparatus_cataloged.ex",
               "Updated",
               "  catalog/equipment/apparatus/router.ex",
               "Ignored",
               "  catalog/equipment/apparatus/aggregate.ex"
             ]
    end

    test "groups that did not apply print nothing" do
      assert Report.render([{:unchanged, @lib <> "aggregate.ex"}]) == [
               "Ignored",
               "  catalog/equipment/apparatus/aggregate.ex"
             ]

      assert Report.render([]) == []
    end

    test "back-fills read as updates and a path is stated once" do
      rows = [
        {:merged, @lib <> "aggregate.ex", [{:alias, "E"}]},
        {:backfill, @lib <> "aggregate.ex", [{:apply, "apparatus-cataloged"}]}
      ]

      assert Report.render(rows) == ["Updated", "  catalog/equipment/apparatus/aggregate.ex"]
    end

    test "files inside and outside the project roots keep their own shape" do
      rows = [
        {:created, @test_root <> "operation/catalog_apparatus_test.exs"},
        {:created, "bruno/Catalog/Equipment/catalog-apparatus.yml"}
      ]

      assert Report.render(rows) == [
               "Created",
               "  bruno/Catalog/Equipment/catalog-apparatus.yml",
               "  catalog/equipment/apparatus/operation/catalog_apparatus_test.exs"
             ]
    end

    test "entries sort by display path within a group" do
      rows = [{:unchanged, @lib <> "router.ex"}, {:unchanged, @lib <> "aggregate.ex"}]
      assert ["Ignored", first, second] = Report.render(rows)
      assert first < second
    end
  end

  describe "render/1 deferred units" do
    test "a file waiting on a citizen lands in Ignored with the command to run" do
      path = @lib <> "operation/catalog_apparatus/command.ex"
      reason = "validator unique_slug not generated (spgen validator)"
      rows = [{:deferred, path, waiting({:alias, "V"}, reason)}]

      assert Report.render(rows) == [
               "Ignored",
               "  catalog/equipment/apparatus/operation/catalog_apparatus/command.ex  skipped: spgen validator"
             ]
    end

    test "several waiting citizens collapse into one sorted note" do
      entries =
        waiting(
          {:alias, "A"},
          "event apparatus-cataloged not generated (spgen event apparatus-cataloged)"
        ) ++
          waiting(
            {:apply, "b"},
            "event apparatus-edited not generated (spgen event apparatus-edited)"
          ) ++
          waiting({:validates, "c"}, "validator unique_slug not generated (spgen validator)")

      assert ["Ignored", line] = Report.render([{:deferred, @lib <> "aggregate.ex", entries}])

      assert line ==
               "  catalog/equipment/apparatus/aggregate.ex  " <>
                 "skipped: spgen event apparatus-cataloged, spgen event apparatus-edited, spgen validator"
    end

    test "a partially updated file reports as Updated and keeps its note" do
      rows = [
        {:merged, @lib <> "aggregate.ex", [{:alias, "A"}]},
        {:deferred, @lib <> "aggregate.ex",
         waiting(
           {:apply, "x"},
           "event apparatus-archived not generated (spgen event apparatus-archived)"
         )}
      ]

      assert ["Updated", line] = Report.render(rows)

      assert line ==
               "  catalog/equipment/apparatus/aggregate.ex  skipped: spgen event apparatus-archived"
    end

    test "a reason without a command still reports the file" do
      rows = [{:deferred, @lib <> "aggregate.ex", waiting({:alias, "A"}, "no gate given")}]
      assert ["Ignored", "  catalog/equipment/apparatus/aggregate.ex"] = Report.render(rows)
    end
  end

  describe "render/1 in check mode" do
    test "future tense for what would change" do
      rows = [
        {:checked, @lib <> "aggregate.ex", [:whole_file]},
        {:checked, @lib <> "router.ex", [{:dispatch, "X"}]},
        {:unchanged, @lib <> "public_api.ex"}
      ]

      assert Report.render(rows) == [
               "Would create",
               "  catalog/equipment/apparatus/aggregate.ex",
               "Would update",
               "  catalog/equipment/apparatus/router.ex",
               "Ignored",
               "  catalog/equipment/apparatus/public_api.ex"
             ]
    end

    test "a check row whose units all wait reads as skipped, not as an update" do
      deferred =
        {:deferred, {:alias, "V"}, ["validator unique_slug not generated (spgen validator)"]}

      assert ["Ignored", line] = Report.render([{:checked, @lib <> "command.ex", [deferred]}])
      assert line =~ "skipped: spgen validator"
    end

    test "a check row with unplaceable units reports Blocked, not an update" do
      rows = [{:checked, @lib <> "router.ex", [{:unplaceable, {:dispatch, "X"}}]}]

      assert Report.render(rows) == ["Blocked", "  catalog/equipment/apparatus/router.ex"]
    end

    test "Ignored keeps its name in check mode" do
      assert ["Ignored", _] = Report.render([{:unchanged, @lib <> "aggregate.ex"}])
    end
  end

  describe "render/1 problems" do
    test "blocked and failed get their own groups" do
      rows = [
        {:blocked, @lib <> "router.ex", [{:dispatch, "X"}]},
        {:error, @lib <> "aggregate.ex", :unparsable}
      ]

      assert Report.render(rows) == [
               "Blocked",
               "  catalog/equipment/apparatus/router.ex",
               "Failed",
               "  catalog/equipment/apparatus/aggregate.ex"
             ]
    end

    test "a file that received units but also has unplaceable ones shows in both groups" do
      rows = [
        {:merged, @lib <> "router.ex", [{:dispatch, "Y"}]},
        {:blocked, @lib <> "router.ex", [{:dispatch, "X"}]}
      ]

      assert Report.render(rows) == [
               "Updated",
               "  catalog/equipment/apparatus/router.ex",
               "Blocked",
               "  catalog/equipment/apparatus/router.ex"
             ]
    end
  end

  describe "display_path/1" do
    test "strips the four project roots" do
      assert Report.display_path(@lib <> "aggregate.ex") ==
               "catalog/equipment/apparatus/aggregate.ex"

      assert Report.display_path(
               "services/api/lib/sportipedia_web/catalog/equipment/apparatus/apparatus_controller.ex"
             ) == "catalog/equipment/apparatus/apparatus_controller.ex"

      assert Report.display_path(@test_root <> "operation/catalog_apparatus_test.exs") ==
               "catalog/equipment/apparatus/operation/catalog_apparatus_test.exs"

      assert Report.display_path("services/api/test/sportipedia_web/router_test.exs") ==
               "router_test.exs"
    end

    test "leaves anything else alone" do
      path = "docs/domain-model/catalog/equipment/aggregate.apparatus.esdm.yaml"
      assert Report.display_path(path) == path
    end
  end
end
