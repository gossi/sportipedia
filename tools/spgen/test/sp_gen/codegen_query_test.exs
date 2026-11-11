defmodule SpGen.QueryAcceptanceTest do
  @moduledoc """
  Queries: a declared collection read delegates to the shared QueryBuilder, and
  a collection's OpenAPI query parameters are derived from the model, never
  transcribed.
  """
  use ExUnit.Case, async: true

  alias SpGen.FixtureRepo

  # ------------------------------------------------- collection queries delegate

  # A query the model declares `spgen.operation: collection` is a JSON:API read:
  # its parameters are the standard set, so there is no 1% left to the spec and
  # the generator ships the working body — the shared QueryBuilder over the read
  # model — instead of a marker that raises.
  describe "a declared collection query delegates to the QueryBuilder" do
    setup do
      %{repo: FixtureRepo.build()}
    end

    @list_query "services/api/lib/sportipedia/catalog/equipment/widget/queries/list_widgets.ex"
    @read_query "services/api/lib/sportipedia/catalog/equipment/widget/queries/read_widget.ex"
    @public_api "services/api/lib/sportipedia/catalog/equipment/widget/public_api.ex"

    test "the generated body is the delegation, with the aliases it names", %{repo: repo} do
      {:ok, _} = FixtureRepo.run(repo, :read_model, ["read-model.widget"])
      {:ok, _} = FixtureRepo.run(repo, :query, ["list-widgets"])

      generated = FixtureRepo.read(repo, @list_query)

      assert generated =~ "QueryBuilder.build(query, WidgetReadModel)"
      assert generated =~ "alias Sportipedia.Catalog.Equipment.Widget.WidgetReadModel"
      assert generated =~ "alias Sportipedia.Support.JSONAPI.QueryBuilder"
      assert generated =~ "@spec new(JSONAPI.Config.t()) :: Ecto.Query.t()"
      # no marker left standing, and no import of macros the body never uses
      refute generated =~ "raise \"TODO"
      refute generated =~ "import Ecto.Query"
    end

    test "the collection function runs the query citizen, not the builder", %{repo: repo} do
      {:ok, _} = FixtureRepo.run(repo, :public_api, ["list-widgets"])

      generated = FixtureRepo.read(repo, @public_api)

      assert generated =~ "Repo.all(ListWidgets.new(query))"
      assert generated =~ "alias Sportipedia.Catalog.Equipment.Widget.Queries.ListWidgets"
      # the port names no builder: the query owns how a config becomes a query
      refute generated =~ "QueryBuilder"

      # and the module it calls is not left as the file nothing generated
      assert FixtureRepo.exists?(repo, @list_query)
      assert FixtureRepo.read(repo, @list_query) =~ "QueryBuilder.build(query, WidgetReadModel)"
    end

    test "a read query keeps the marker — its body is still the spec's 1%", %{repo: repo} do
      {:ok, _} = FixtureRepo.run(repo, :read_model, ["read-model.widget"])
      {:ok, _} = FixtureRepo.run(repo, :query, ["read-widget"])

      generated = FixtureRepo.read(repo, @read_query)
      assert generated =~ "raise \"TODO: implement read-widget query"
      # nothing to alias yet: an unused alias is a warning this tool must not write
      refute generated =~ "alias Sportipedia.Support.JSONAPI.QueryBuilder"
    end

    test "a marker an earlier run left is reported, never rewritten", %{repo: repo} do
      {:ok, _} = FixtureRepo.run(repo, :read_model, ["read-model.widget"])

      # what a run before this blueprint knew the shape left standing
      FixtureRepo.write(
        repo,
        @list_query,
        """
        defmodule Sportipedia.Catalog.Equipment.Widget.Queries.ListWidgets do
          @moduledoc \"\"\"
          List all widgets with filtering, sorting, and pagination
          \"\"\"
          @doc \"\"\"
          Creates a new query to fetch widgets.
          \"\"\"
          @spec new(map()) :: Ecto.Query.t()
          def new(_params) do
            # TODO: construct and return the query from the read model
            raise "TODO: implement list-widgets query (see the feature spec)"
          end
        end
        """
      )

      # the merge owns the notice, the operator owns the edit — it never rewrites
      # a standing line, and never pushes an alias a raising body would not use
      assert {:ok, results} = FixtureRepo.check(repo, :query, ["list-widgets"])

      assert Enum.any?(results, fn
               {:checked, @list_query, ids} ->
                 Enum.any?(ids, fn
                   {:stale, {:def, :new, 1}, [detail | _]} ->
                     detail =~ "QueryBuilder.build(query, WidgetReadModel)"

                   _ ->
                     false
                 end)

               _ ->
                 false
             end)

      assert {:ok, _} = FixtureRepo.run(repo, :query, ["list-widgets"])
      assert FixtureRepo.read(repo, @list_query) =~ "raise \"TODO"

      refute FixtureRepo.read(repo, @list_query) =~
               "alias Sportipedia.Support.JSONAPI.QueryBuilder"
    end

    test "a port that still builds the query inline is reported, not duplicated", %{
      repo: repo
    } do
      {:ok, _} = FixtureRepo.run(repo, :public_api, ["list-widgets"])

      inline =
        FixtureRepo.read(repo, @public_api)
        |> String.replace(
          "Repo.all(ListWidgets.new(query))",
          "Repo.all(QueryBuilder.build(query, WidgetReadModel))"
        )
        |> String.replace(
          "  alias Sportipedia.Catalog.Equipment.Widget.Queries.ListWidgets\n",
          "  alias Sportipedia.Support.JSONAPI.QueryBuilder\n"
        )

      FixtureRepo.write(repo, @public_api, inline)

      assert {:ok, results} = FixtureRepo.check(repo, :public_api, ["list-widgets"])

      assert Enum.any?(results, fn
               {:checked, @public_api, ids} ->
                 Enum.any?(ids, fn
                   {:stale, {:def, :list_widgets, 1}, [detail | _]} ->
                     detail =~ "Repo.all(ListWidgets.new(query))"

                   _ ->
                     false
                 end)

               _ ->
                 false
             end)

      # the notice is the whole delivery: no second clause, no second alias
      assert {:ok, _} = FixtureRepo.run(repo, :public_api, ["list-widgets"])
      assert FixtureRepo.read(repo, @public_api) == inline
    end
  end

  # ------------------------------------------------ collection parameters derived

  # A collection's `filter`/`sort`/`page`/`fields` are the same names the
  # controller's `JSONAPI.QueryParser` validates and the QueryBuilder applies.
  # The schema therefore *derives* them, exactly as a response derives from the
  # view — a transcribed list is a second source, and second sources drift.
  describe "a collection's query parameters are derived, not transcribed" do
    setup do
      %{repo: FixtureRepo.build()}
    end

    @query_params "services/api/lib/sportipedia_web/catalog/equipment/widget/schemas/list_widgets_query_params.ex"

    test "the schema calls the shared builder with the model's own names", %{repo: repo} do
      {:ok, _} = FixtureRepo.run(repo, :view, ["read-model.widget"])
      {:ok, _} = FixtureRepo.run(repo, :schema, ["list-widgets"])

      generated = FixtureRepo.read(repo, @query_params)

      assert generated =~
               "OpenApiSpex.schema(\n" <>
                 "    OpenApiSchema.query_params(WidgetView,"

      assert generated =~ "title: \"equipment.ListWidgetsQueryParams\""
      assert generated =~ "filter: [title: \"Filter widgets by title (partial match)\"]"
      assert generated =~ "sort: ~w(title slug)"
      assert generated =~ "page: :numbered"
      # nothing hand-rolled: the members belong to the builder
      refute generated =~ "%OpenApiSpex.Schema{"
      assert generated =~ "alias SportipediaWeb.Catalog.Equipment.Widget.WidgetView"
      assert generated =~ "alias Sportipedia.Support.JSONAPI.OpenApiSchema"
    end

    test "a schema that transcribes its members is reported, never rewritten", %{repo: repo} do
      {:ok, _} = FixtureRepo.run(repo, :view, ["read-model.widget"])
      {:ok, _} = FixtureRepo.run(repo, :schema, ["list-widgets"])

      transcribed = """
      defmodule SportipediaWeb.Catalog.Equipment.Widget.Schemas.ListWidgetsQueryParams do
        @moduledoc \"\"\"
        OpenAPI schema for documenting list-widgets collection query parameters.
        \"\"\"
        require OpenApiSpex

        OpenApiSpex.schema(%{
          title: "equipment.ListWidgetsQueryParams",
          type: :object,
          properties: %{
            sort: %OpenApiSpex.Schema{type: :string, enum: ["title", "-title"]}
          }
        })
      end
      """

      FixtureRepo.write(repo, @query_params, transcribed)

      assert {:ok, results} = FixtureRepo.check(repo, :schema, ["list-widgets"])

      assert Enum.any?(results, fn
               {:checked, @query_params, ids} ->
                 Enum.any?(ids, fn
                   {:stale, :schema_body, [detail | _]} -> detail =~ "call the builder"
                   _ -> false
                 end)

               _ ->
                 false
             end)

      # the notice is the delivery: no alias pushed into a body that uses none,
      # no second `OpenApiSpex.schema` beside the standing one
      assert {:ok, _} = FixtureRepo.run(repo, :schema, ["list-widgets"])
      written = FixtureRepo.read(repo, @query_params)
      assert written == transcribed
      refute written =~ "alias Sportipedia.Support.JSONAPI.OpenApiSchema"
    end
  end

  # --------------------------------------------- query bodies own their imports

  describe "query bodies own their imports" do
    setup do
      %{repo: FixtureRepo.build()}
    end

    @list_query "services/api/lib/sportipedia/catalog/equipment/widget/queries/list_widgets.ex"

    test "a delegating body is left untouched by creating runs — no import is added", %{
      repo: repo
    } do
      {:ok, _} = FixtureRepo.run(repo, :read_model, ["read-model.widget"])
      {:ok, _} = FixtureRepo.run(repo, :query, ["list-widgets"])

      delegating = """
      defmodule Sportipedia.Catalog.Equipment.Widget.Queries.ListWidgets do
        @moduledoc "Delegates to the shared QueryBuilder — no query macros at all."

        alias Sportipedia.Catalog.Equipment.Widget.WidgetReadModel
        alias Sportipedia.Support.JSONAPI.QueryBuilder

        def new(query) do
          QueryBuilder.build(query, WidgetReadModel)
        end
      end
      """

      FixtureRepo.write(repo, @list_query, delegating)

      # any creating run sweeps the neighborhood — none may touch this file
      {:ok, _} = FixtureRepo.run(repo, :event, ["widget-created"])
      {:ok, _} = FixtureRepo.run(repo, :query, ["list-widgets"])

      assert FixtureRepo.read(repo, @list_query) == delegating
    end
  end
end
