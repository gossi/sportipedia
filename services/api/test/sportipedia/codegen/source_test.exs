defmodule Sportipedia.Codegen.SourceTest do
  @moduledoc """
  Exercises presence detection and anchors against the real, hand-written
  apparatus files of this codebase — the strongest guarantee that generated
  code merges into them instead of duplicating what is already there.
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

    test "typedstruct block anchor lands inside the block", %{src: src} do
      {:before_line, line} = Source.inside_block(src, :typedstruct)
      # block body lines are between `typedstruct do` and the closing `end`
      assert line > 16 and line <= 22, "expected inside typedstruct block, got line #{line}"
      assert Enum.at(src.lines, line - 1) =~ ~r/^\s*end$/
    end

    test "alias anchor inserts alphabetically", %{src: src} do
      later = "Sportipedia.Catalog.Equipment.Apparatus.Validators.Zzz"
      earlier = "Sportipedia.Accounts.Mail"

      # existing: alias ...Validators.UniqueSlug (line 9)
      assert {:after_line, line} = Source.alias_anchor(src, later)
      assert Enum.at(src.lines, line - 1) =~ "alias"

      assert {:before_line, line} = Source.alias_anchor(src, earlier)
      assert Enum.at(src.lines, line - 1) =~ "alias"
    end

    test "module body anchors", %{src: src} do
      assert Source.module_start_line(src) == 2
      assert {:before_line, stop} = Source.module_end_anchor(src)
      assert Enum.at(src.lines, stop - 1) == "end"
    end
  end

  describe "defs — real handler.ex" do
    setup do
      %{src: source!("catalog/equipment/apparatus/operation/catalog_apparatus/handler.ex")}
    end

    test "behaviour, doc and spec pairing", %{src: src} do
      assert Source.has_behaviour?(src, "Commanded.Commands.Handler")
      assert Source.has_def?(src, :handle, 2)
      assert Source.has_doc_for?(src, :handle, 2)
      assert Source.has_spec_for?(src, :handle, 2)
      refute Source.has_def?(src, :handle, 1)
      refute Source.has_doc_for?(src, :dispatch, 2)
    end

    test "clause matching by head pattern", %{src: src} do
      matches_event = fn args ->
        Enum.any?(args, fn a -> Source.render_arg(a) == "CatalogApparatus{}" end)
      end

      assert Source.has_def_matching?(src, :handle, 2, matches_event)

      refute Source.has_def_matching?(src, :handle, 2, fn args ->
               Enum.any?(args, fn a -> Source.render_arg(a) == "EditApparatus{}" end)
             end)
    end

    test "def_range and anchor", %{src: src} do
      assert {start, stop} = Source.def_range(src, :handle, 2)
      assert start < stop
      assert {:after_line, ^stop} = Source.def_anchor(src, :handle, 2)
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

    test "project anchors span through the fn end", %{src: src} do
      entries = Source.calls(src, :project)
      assert length(entries) == 3
      [%Source.Entry{line: line, end_line: end_line} | _] = entries
      # first project starts at the `project %ApparatusCataloged{}...` header
      assert line < end_line
      # and its end line is the block's closing `end`
      assert String.trim(Enum.at(src.lines, end_line - 1)) == "end"
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

    test "anchor: after the last dispatch of an aggregate", %{src: src} do
      {:after_line, line} =
        Source.after_entry_kw(src, :dispatch, :aggregate, fn v -> v == "ApparatusAggregate" end)

      # the third apparatus dispatch
      assert src.lines |> Enum.at(line - 1) =~ "dispatch ArchiveApparatus"

      {:after_line, instrument_line} =
        Source.after_entry_kw(src, :dispatch, :aggregate, fn v -> v == "InstrumentAggregate" end)

      assert src.lines |> Enum.at(instrument_line - 1) =~ "dispatch ArchiveInstrument"
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

    test "describe anchor: after last describe block", %{src: src} do
      {:after_line, line} = Source.describe_anchor(src)
      assert line > 100
      assert String.trim(Enum.at(src.lines, line)) in ["", "#", "end", ""]
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
