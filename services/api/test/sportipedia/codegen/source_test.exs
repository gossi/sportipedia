defmodule Sportipedia.Codegen.SourceTest do
  @moduledoc """
  Exercises presence detection against the real, hand-written apparatus
  files of this codebase — the strongest guarantee that generated code
  merges into them instead of duplicating what is already there.

  Placement (where a missing unit lands) is `Sportipedia.Codegen.MergeTest`'s
  business.
  """
  use ExUnit.Case, async: true

  alias Sportipedia.Codegen.Source

  # __DIR__ = services/api/test/sportipedia/codegen
  @root Path.expand("../../../", __DIR__)
  @api_root Path.join(@root, "lib/sportipedia")

  defp source!(rel), do: Path.join(@api_root, rel) |> File.read!() |> Source.parse()
  defp source_at_root!(rel), do: Path.join(@root, rel) |> File.read!() |> Source.parse()

  describe "module and directives — real command.ex" do
    setup do
      %{src: source!("catalog/equipment/apparatus/operation/catalog_apparatus/command.ex")}
    end

    test "module name", %{src: src} do
      assert Source.module_name(src) ==
               "Sportipedia.Catalog.Equipment.Apparatus.Command.CatalogApparatus"
    end

    test "moduledoc and uses", %{src: src} do
      assert Source.has_moduledoc?(src)
      assert Source.has_use?(src, "TypedStruct")
      assert Source.has_use?(src, "ExConstructor")
      assert Source.has_use?(src, "Vex.Struct")
      refute Source.has_use?(src, "Vex.Validator")
    end

    test "alias detection", %{src: src} do
      assert Source.has_alias?(
               src,
               "Sportipedia.Catalog.Equipment.Apparatus.Validators.UniqueSlug"
             )

      refute Source.has_alias?(
               src,
               "Sportipedia.Catalog.Equipment.Apparatus.Validators.ApparatusExists"
             )
    end

    test "field entries by name", %{src: src} do
      for field <- [":id", ":title", ":slug", ":description"] do
        assert Source.entry?(src, :field, field), "missing #{field}"
      end

      refute Source.entry?(src, :field, ":status")
    end

    test "validates entries by field", %{src: src} do
      assert Source.entry?(src, :validates, ":title")
      assert Source.entry?(src, :validates, ":slug")
      refute Source.entry?(src, :validates, ":description")
    end

    test "moduledoc attribute is seen", %{src: src} do
      assert Source.has_attribute?(src, :moduledoc)
    end
  end

  describe "defs — real handler.ex" do
    setup do
      %{src: source!("catalog/equipment/apparatus/operation/catalog_apparatus/handler.ex")}
    end

    test "behaviour and clauses", %{src: src} do
      assert Source.has_behaviour?(src, "Commanded.Commands.Handler")
      assert Source.has_def?(src, :handle, 2)
      refute Source.has_def?(src, :handle, 1)
    end

    test "clause matching by head pattern", %{src: src} do
      assert Source.def_head_has?(src, :handle, 2, "CatalogApparatus{}")
      refute Source.def_head_has?(src, :handle, 2, "EditApparatus{}")
    end
  end

  describe "entries — real projector.ex" do
    setup do
      %{src: source!("catalog/equipment/apparatus/projector.ex")}
    end

    test "project entries keyed by event pattern", %{src: src} do
      assert Source.entry?(src, :project, "ApparatusCataloged{}")
      assert Source.entry?(src, :project, "ApparatusEdited{}")
      assert Source.entry?(src, :project, "ApparatusArchived{}")
      refute Source.entry?(src, :project, "InstrumentCataloged{}")
    end

    test "use with keyword options matches by module only", %{src: src} do
      assert Source.has_use?(src, "Commanded.Projections.Ecto")
    end

    test "project calls found with line ranges", %{src: src} do
      entries = Source.calls(src, :project)
      assert length(entries) == 3
      [%Source.Entry{line: line, end_line: end_line} | _] = entries
      assert line < end_line
    end
  end

  describe "commanded router — real equipment/router.ex" do
    setup do
      %{src: source!("catalog/equipment/router.ex")}
    end

    test "dispatch entries and aggregate keyword", %{src: src} do
      assert Source.entry?(src, :dispatch, "CatalogApparatus")
      assert Source.entry?(src, :dispatch, "ArchiveInstrument")
      refute Source.entry?(src, :dispatch, "SuggestSport")

      aggregates =
        src
        |> Source.calls(:dispatch)
        |> Enum.map(&Sportipedia.Codegen.Source.Entry.kw(&1, :aggregate))

      assert aggregates == [
               "ApparatusAggregate",
               "ApparatusAggregate",
               "ApparatusAggregate",
               "InstrumentAggregate",
               "InstrumentAggregate",
               "InstrumentAggregate"
             ]
    end

    test "identify entries", %{src: src} do
      assert Source.entry?(src, :identify, "ApparatusAggregate")
    end

    test "dispatch clustering by aggregate via Entry.kw", %{src: src} do
      apparatus =
        src
        |> Source.calls(:dispatch)
        |> Enum.count(
          &(Sportipedia.Codegen.Source.Entry.kw(&1, :aggregate) == "ApparatusAggregate")
        )

      assert apparatus == 3
    end
  end

  describe "supervisor" do
    test "children by text presence" do
      src = source_at_root!("lib/sportipedia/catalog/supervisor.ex")
      assert Source.has_child?(src, "Sportipedia.Catalog.Equipment.Apparatus.ApparatusProjector")
      refute Source.has_child?(src, "Sportipedia.Catalog.Skill.SkillProjector")
    end
  end

  describe "operation test file" do
    setup do
      %{
        src:
          source_at_root!(
            "test/sportipedia/catalog/equipment/apparatus/operation/catalog_apparatus_test.exs"
          )
      }
    end

    test "describe blocks", %{src: src} do
      assert Source.has_describe?(src, "CatalogApparatus command")
      assert Source.has_describe?(src, "CatalogApparatusHandler")
      assert Source.has_describe?(src, "ApparatusCataloged event")
      refute Source.has_describe?(src, "EditApparatus command")
    end

    test "moduletag and aliases", %{src: src} do
      assert Source.has_attribute?(src, :moduletag)

      assert Source.has_alias?(
               src,
               "Sportipedia.Catalog.Equipment.Apparatus.Command.CatalogApparatus"
             )
    end

    test "route presence in the web router scope chain" do
      src = source_at_root!("lib/sportipedia_web/router.ex")
      chain = ["/catalog", "/equipment", "/apparatuses"]
      assert Source.route_present?(src, :post, ":catalog_apparatus", chain)
      refute Source.route_present?(src, :post, ":make_tea", chain)
    end
  end

  describe "unparsable file" do
    test "nothing is present" do
      src = Source.parse("defmodule broken do this is not elixir @@@")
      assert src.ast == nil
      refute Source.has_moduledoc?(src)
      refute Source.has_def?(src, :x, 0)
      assert Source.calls(src, :field) == []
    end
  end
end
