defmodule SpGen.MergeTest do
  @moduledoc """
  Tree-merge machinery: whole-file print fidelity and every placement strategy
  (`SpGen.Merge` factories) — including the `:blocked` cases where the target
  structure is absent.

  The sources are the generated citizen of `SpGen.FixtureRepo`: an in-memory
  repository, so the shapes tested are the ones the generator produces and no
  test reads the working tree.
  """
  use ExUnit.Case, async: true

  alias SpGen.{FixtureRepo, Formatter, Merge, Source, Unit}

  @command "services/api/lib/sportipedia/catalog/equipment/widget/operations/create_widget/command.ex"
  @read_model "services/api/lib/sportipedia/catalog/equipment/widget/read_model.ex"
  @aggregate "services/api/lib/sportipedia/catalog/equipment/widget/aggregate.ex"
  @projector "services/api/lib/sportipedia/catalog/equipment/widget/projector.ex"
  @router "services/api/lib/sportipedia/catalog/equipment/router.ex"
  @supervisor "services/api/lib/sportipedia/catalog/supervisor.ex"
  @web_router "services/api/lib/sportipedia_web/router.ex"
  @op_test "services/api/test/sportipedia/catalog/equipment/widget/operations/create_widget_test.exs"

  setup_all do
    repo = FixtureRepo.build()

    for {generator, args} <- [
          {:read_model, ["read-model.widget"]},
          {:event, ["widget-created"]},
          {:aggregate, ["aggregate.widget"]},
          {:command_handler, ["create-widget"]},
          {:command, ["create-widget", "--template", "create"]},
          {:projector, ["widget-created"]},
          {:controller, ["create-widget"]}
        ] do
      assert {:ok, _} = FixtureRepo.run(repo, generator, args), "#{generator} #{inspect(args)}"
    end

    opts = Formatter.opts(Path.join(repo.root, "services/api"), repo.fs)
    %{repo: repo, opts: opts}
  end

  defp read!(repo, rel), do: FixtureRepo.read(repo, rel)
  defp ast!(repo, rel), do: read!(repo, rel) |> Sourceror.parse_string!()

  defp unit(text, place) do
    %Unit{id: :test, check: fn _ -> false end, render: fn _ -> text end, place: place}
  end

  defp merge!(repo, opts, rel, text, place) do
    u = unit(text, place)
    {:ok, ast} = u.place.(ast!(repo, rel), u, nil)
    Merge.render(ast, opts)
  end

  defp line_of(text, needle) do
    text |> String.split("\n") |> Enum.find_index(&String.contains?(&1, needle))
  end

  # the project formatter may print `timestamps()` without parens
  defp timestamps_line(text) do
    text
    |> String.split("\n")
    |> Enum.find_index(&(String.trim(&1) in ["timestamps()", "timestamps"]))
  end

  # ------------------------------------------------------------- print fidelity

  describe "whole-file print round-trip" do
    test "generated command.ex prints back byte-identical", %{repo: repo, opts: opts} do
      assert Merge.render(ast!(repo, @command), opts) == read!(repo, @command)
    end

    test "projector with fn blocks prints back byte-identical", %{repo: repo, opts: opts} do
      assert Merge.render(ast!(repo, @projector), opts) == read!(repo, @projector)
    end

    test "web router with nested scopes prints back byte-identical", %{repo: repo, opts: opts} do
      assert Merge.render(ast!(repo, @web_router), opts) == read!(repo, @web_router)
    end
  end

  # ----------------------------------------------------------------- placements

  describe "alias placement" do
    test "inserts into the alias block, above the first line of code", %{
      repo: repo,
      opts: opts
    } do
      rendered =
        merge!(
          repo,
          opts,
          @command,
          "alias Sportipedia.Catalog.Zed",
          Merge.alias_of("Sportipedia.Catalog.Zed")
        )

      src = Source.parse(rendered)
      assert Source.has_alias?(src, "Sportipedia.Catalog.Zed")

      assert line_of(rendered, "alias Sportipedia.Catalog.Zed") <
               line_of(rendered, "typedstruct do")
    end

    test "keeps aliases sorted", %{repo: repo, opts: opts} do
      rendered = merge!(repo, opts, @command, "alias Aaa", Merge.alias_of("Aaa"))
      assert line_of(rendered, "alias Aaa") < line_of(rendered, "alias Sportipedia.Catalog")
    end
  end

  describe "inside(typedstruct)" do
    test "appends a field inside the struct block", %{repo: repo, opts: opts} do
      rendered =
        merge!(repo, opts, @command, "field :capacity, :integer", Merge.inside(:typedstruct))

      assert Source.entry?(Source.parse(rendered), :field, ":capacity")
      assert line_of(rendered, "typedstruct do") < line_of(rendered, "field :capacity")
    end

    test "blocked when the block does not exist", %{repo: repo} do
      u = unit("field :x, :integer", Merge.inside(:typedstruct))
      assert :blocked = u.place.(ast!(repo, @web_router), u, nil)
    end
  end

  describe "inside with before_trailing" do
    test "inserts before the trailing timestamps() call", %{repo: repo, opts: opts} do
      rendered =
        merge!(
          repo,
          opts,
          @read_model,
          "field :capacity, :integer",
          Merge.inside(:typed_schema, nil, before_trailing: :timestamps)
        )

      assert line_of(rendered, "field :capacity") < timestamps_line(rendered)
    end

    test "appends when the block has no trailing call", %{repo: repo, opts: opts} do
      rendered =
        merge!(
          repo,
          opts,
          @command,
          "field :capacity, :integer",
          Merge.inside(:typedstruct, nil, before_trailing: :timestamps)
        )

      assert line_of(rendered, "field :capacity") > line_of(rendered, "field :slug")
    end
  end

  describe "after_macro on the commanded router" do
    test "dispatch lands after the last dispatch of its aggregate", %{repo: repo, opts: opts} do
      rendered =
        merge!(
          repo,
          opts,
          @router,
          "dispatch NewThing, to: NewThingHandler, aggregate: WidgetAggregate",
          Merge.after_macro_kw(:dispatch, :aggregate, fn v -> v == "WidgetAggregate" end)
        )

      assert Source.entry?(Source.parse(rendered), :dispatch, "NewThing")
      # appended below the widget cluster's last entry
      assert line_of(rendered, "dispatch CreateWidget") < line_of(rendered, "dispatch NewThing")
    end

    test "identify lands after the dispatch cluster", %{repo: repo, opts: opts} do
      rendered =
        merge!(
          repo,
          opts,
          @router,
          "identify NewAggregate, by: :id, prefix: \"x/\"",
          Merge.after_macro(:dispatch, fn _ -> true end)
        )

      assert Source.entry?(Source.parse(rendered), :identify, "NewAggregate")

      assert line_of(rendered, "dispatch CreateWidget") <
               line_of(rendered, "identify NewAggregate")
    end
  end

  describe "children_list" do
    test "appends a child to the supervisor list", %{repo: repo, opts: opts} do
      rendered =
        merge!(
          repo,
          opts,
          @supervisor,
          "Sportipedia.Catalog.Equipment.Gadget.GadgetProjector",
          Merge.children_list()
        )

      assert rendered =~ "Sportipedia.Catalog.Equipment.Gadget.GadgetProjector"
      # still valid Elixir and the list is intact
      assert Source.has_child?(
               Source.parse(rendered),
               "Sportipedia.Catalog.Equipment.Widget.WidgetProjector"
             )
    end

    test "blocked when there is no children list", %{repo: repo} do
      u = unit("Foo", Merge.children_list())
      assert :blocked = u.place.(ast!(repo, @router), u, nil)
    end
  end

  describe "scope (web router)" do
    @chain [
      {"/catalog", "SportipediaWeb.Catalog"},
      {"/equipment", "Equipment"},
      {"/gadgets", "Gadget"}
    ]

    test "route lands inside the deepest existing scope", %{repo: repo, opts: opts} do
      rendered =
        merge!(
          repo,
          opts,
          @web_router,
          "post \"/x-thing\", XController, :x_thing",
          Merge.scope(@chain)
        )

      assert Source.route_present?(
               Source.parse(rendered),
               :post,
               ":x_thing",
               Enum.map(@chain, &elem(&1, 0))
             )
    end

    test "missing tail of the chain is materialized", %{opts: opts} do
      router = """
      defmodule SportipediaWeb.Router do
        scope "/catalog", SportipediaWeb.Catalog do
          scope "/gadgets", Gadgets do
            post "/y", YController, :y
          end
        end
      end
      """

      chain = [
        {"/catalog", "SportipediaWeb.Catalog"},
        {"/widgets", "Widget"}
      ]

      ast = Sourceror.parse_string!(router)
      u = unit("post \"/create-widget\", WidgetController, :create_widget", Merge.scope(chain))
      {:ok, ast} = u.place.(ast, u, nil)

      assert Merge.render(ast, opts) =~ "scope \"/widgets\", Widget do"
    end

    test "blocked when the outermost scope is absent", %{repo: repo} do
      u = unit("post \"/x\", X, :x", Merge.scope(@chain))
      assert :blocked = u.place.(ast!(repo, @router), u, nil)
    end
  end

  describe "clause and describe grouping" do
    test "after_def keeps apply/2 clauses together", %{repo: repo, opts: opts} do
      rendered =
        merge!(
          repo,
          opts,
          @aggregate,
          "def apply(_a, %Zz{}), do: :ok",
          Merge.after_def(:apply, 2)
        )

      assert line_of(rendered, "def apply(_a, %Zz{})") > line_of(rendered, "def apply(%")
    end

    test "describe appends after the last describe", %{repo: repo, opts: opts} do
      rendered =
        merge!(
          repo,
          opts,
          @op_test,
          "describe \"Zed\" do\n  test(\"t\", do: :ok)\nend",
          Merge.describe()
        )

      assert Source.has_describe?(Source.parse(rendered), "Zed")
      assert line_of(rendered, "describe \"Zed\"") > line_of(rendered, "describe \"Command\"")
    end

    test "before_helpers lands above the first defp" do
      src = """
      defmodule V do
        def a, do: :ok

        defp helper, do: :ok
      end
      """

      ast = Sourceror.parse_string!(src)
      u = unit("def b, do: :ok", Merge.before_helpers())
      {:ok, ast} = u.place.(ast, u, nil)
      rendered = Sourceror.to_string(ast)

      assert line_of(rendered, "def b") < line_of(rendered, "defp helper")
    end
  end

  # ------------------------------------------------------------------- head/body

  describe "head ranks" do
    test "moduledoc first, use next, attributes after aliases" do
      src = """
      defmodule M do
        def go, do: :ok
      end
      """

      ast = Sourceror.parse_string!(src)
      alias_u = unit("alias A", Merge.alias_of("A"))
      {:ok, ast} = alias_u.place.(ast, alias_u, nil)

      use_u = unit("use ExUnit.Case", Merge.head(:use))
      {:ok, ast} = use_u.place.(ast, use_u, nil)

      doc_u = unit("@moduledoc \"hi\"", Merge.head(:moduledoc))
      {:ok, ast} = doc_u.place.(ast, doc_u, nil)

      attr_u = unit("@moduletag :integration", Merge.head(:attribute))
      {:ok, ast} = attr_u.place.(ast, attr_u, nil)

      rendered = Sourceror.to_string(ast)
      assert line_of(rendered, "@moduledoc") < line_of(rendered, "use ExUnit.Case")
      assert line_of(rendered, "use ExUnit.Case") < line_of(rendered, "alias A")
      assert line_of(rendered, "alias A") < line_of(rendered, "@moduletag")
      assert line_of(rendered, "@moduletag") < line_of(rendered, "def go")
    end
  end
end
