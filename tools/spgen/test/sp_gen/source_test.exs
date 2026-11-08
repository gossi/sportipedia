defmodule SpGen.SourceTest do
  @moduledoc """
  Presence detection (`SpGen.Source`) — the check that decides whether a unit
  merges or is already there.

  Input is the generated code of the fixture citizen: the repository is built in
  memory (`SpGen.FixtureRepo`), the generators write into it, and each test
  parses what came out. That is the strongest guarantee the detector gives for
  the shapes the generator actually produces — and it never reads the real tree.

  Placement (where a missing unit lands) is `SpGen.MergeTest`'s business.
  """
  use ExUnit.Case, async: true

  alias SpGen.{FixtureRepo, Source}

  setup_all do
    repo = FixtureRepo.build()

    for {generator, args} <- [
          {:read_model, ["read-model.widget"]},
          {:event, ["widget-created"]},
          {:aggregate, ["aggregate.widget"]},
          {:command_handler, ["create-widget"]},
          {:command, ["create-widget", "--template", "create"]},
          {:projector, ["widget-created"]},
          {:policy, ["create-widget"]},
          {:public_api, ["create-widget"]},
          {:controller, ["create-widget"]},
          {:bruno, ["create-widget"]}
        ] do
      assert {:ok, _} = FixtureRepo.run(repo, generator, args), "#{generator} #{inspect(args)}"
    end

    %{repo: repo}
  end

  defp source(repo, rel), do: FixtureRepo.read(repo, rel) |> Source.parse()

  describe "module and directives — generated command.ex" do
    setup %{repo: repo} do
      %{
        src:
          source(
            repo,
            "services/api/lib/sportipedia/catalog/equipment/widget/operations/create_widget/command.ex"
          )
      }
    end

    test "module name", %{src: src} do
      assert Source.module_name(src) ==
               "Sportipedia.Catalog.Equipment.Widget.Command.CreateWidget"
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
               "Sportipedia.Catalog.Equipment.Widget.Validators.UniqueSlug"
             )

      refute Source.has_alias?(
               src,
               "Sportipedia.Catalog.Equipment.Widget.Validators.WidgetExists"
             )
    end

    test "field entries by name", %{src: src} do
      for field <- [":id", ":title", ":slug", ":label"] do
        assert Source.entry?(src, :field, field), "missing #{field}"
      end

      refute Source.entry?(src, :field, ":status")
    end

    test "validates entries by field", %{src: src} do
      assert Source.entry?(src, :validates, ":title")
      assert Source.entry?(src, :validates, ":slug")
      refute Source.entry?(src, :validates, ":description")
    end

    test "the keyword pairs a validates line carries", %{src: src} do
      assert Source.entry_kws(src, :validates, ":title") == [presence: "true"]

      assert Source.entry_kws(src, :validates, ":slug") == [
               presence: "true",
               by: "[function: &UniqueSlug.validate/2, allow_nil: true]"
             ]

      # A generated rule pair carries `allow_nil` on a field the model does not
      # require (templates.ex): the coach reference is optional, and a rule body
      # may read the value.
      assert Source.entry_kws(src, :validates, ":coachId") == [
               by: "[function: &AtMostOneOwner.validate/2, allow_nil: true]"
             ]

      assert Source.entry_kws(src, :validates, ":description") == []
    end

    test "repeated keys survive — two validators guarding one field" do
      src =
        Source.parse("""
        defmodule X do
          use Vex.Struct
          validates :apparatusId, by: [function: &A.validate/2], by: [function: &B.validate/2]
        end
        """)

      assert Source.entry_kws(src, :validates, ":apparatusId") == [
               by: "[function: &A.validate/2]",
               by: "[function: &B.validate/2]"
             ]
    end

    test "moduledoc attribute is seen", %{src: src} do
      assert Source.has_attribute?(src, :moduledoc)
    end
  end

  describe "defs — generated handler.ex" do
    setup %{repo: repo} do
      %{
        src:
          source(
            repo,
            "services/api/lib/sportipedia/catalog/equipment/widget/operations/create_widget/handler.ex"
          )
      }
    end

    test "behaviour and clauses", %{src: src} do
      assert Source.has_behaviour?(src, "Commanded.Commands.Handler")
      assert Source.has_def?(src, :handle, 2)
      refute Source.has_def?(src, :handle, 1)
    end

    test "clause matching by head pattern", %{src: src} do
      assert Source.def_head_has?(src, :handle, 2, "CreateWidget{}")
      refute Source.def_head_has?(src, :handle, 2, "EditWidget{}")
    end
  end

  describe "entries — generated projector.ex" do
    setup %{repo: repo} do
      %{src: source(repo, "services/api/lib/sportipedia/catalog/equipment/widget/projector.ex")}
    end

    test "project entries keyed by event pattern", %{src: src} do
      assert Source.entry?(src, :project, "WidgetCreated{}")
      assert Source.entry?(src, :project, "WidgetEdited{}")
      refute Source.entry?(src, :project, "GadgetCreated{}")
    end

    test "use with keyword options matches by module only", %{src: src} do
      assert Source.has_use?(src, "Commanded.Projections.Ecto")
    end

    test "project calls found with line ranges", %{src: src} do
      # four clauses: widget-rename-logged is declared `none` and materializes nothing
      entries = Source.calls(src, :project)
      assert length(entries) == 4
      [%Source.Entry{line: line, end_line: end_line} | _] = entries
      assert line < end_line
    end
  end

  describe "commanded router — the fixture host file plus what the run added" do
    setup %{repo: repo} do
      %{src: source(repo, "services/api/lib/sportipedia/catalog/equipment/router.ex")}
    end

    test "dispatch entries and aggregate keyword", %{src: src} do
      assert Source.entry?(src, :dispatch, "CreateWidget")
      assert Source.entry?(src, :dispatch, "CreateGadget")
      refute Source.entry?(src, :dispatch, "EditWidget")

      aggregates =
        src
        |> Source.calls(:dispatch)
        |> Enum.map(&Source.Entry.kw(&1, :aggregate))

      assert aggregates == ["GadgetAggregate", "WidgetAggregate"]
    end

    test "identify entries", %{src: src} do
      assert Source.entry?(src, :identify, "WidgetAggregate")
      assert Source.entry?(src, :identify, "GadgetAggregate")
    end

    test "dispatch clustering by aggregate via Entry.kw", %{src: src} do
      widgets =
        src
        |> Source.calls(:dispatch)
        |> Enum.count(&(Source.Entry.kw(&1, :aggregate) == "WidgetAggregate"))

      assert widgets == 1
    end
  end

  describe "supervisor" do
    test "children by text presence", %{repo: repo} do
      src = source(repo, "services/api/lib/sportipedia/catalog/supervisor.ex")
      assert Source.has_child?(src, "Sportipedia.Catalog.Equipment.Widget.WidgetProjector")
      refute Source.has_child?(src, "Sportipedia.Catalog.Skill.SkillProjector")
    end
  end

  describe "test files" do
    test "describe blocks in the event's own test file", %{repo: repo} do
      src =
        source(
          repo,
          "services/api/test/sportipedia/catalog/equipment/widget/events/widget_created_test.exs"
        )

      assert Source.has_describe?(src, "Event")
      assert Source.has_describe?(src, "Aggregate")
      assert Source.has_attribute?(src, :moduletag)

      assert Source.has_alias?(
               src,
               "Sportipedia.Catalog.Equipment.Widget.Event.WidgetCreated"
             )
    end

    test "describe blocks in the operation test file", %{repo: repo} do
      src =
        source(
          repo,
          "services/api/test/sportipedia/catalog/equipment/widget/operations/create_widget_test.exs"
        )

      assert Source.has_describe?(src, "Command")
      assert Source.has_describe?(src, "Command Handler")
      refute Source.has_describe?(src, "Event")
      refute Source.has_describe?(src, "EditWidget command")
    end
  end

  test "route presence in the web router scope chain", %{repo: repo} do
    src = source(repo, "services/api/lib/sportipedia_web/router.ex")
    chain = ["/catalog", "/equipment", "/widgets"]
    assert Source.route_present?(src, :post, ":create_widget", chain)
    refute Source.route_present?(src, :post, ":make_tea", chain)
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
