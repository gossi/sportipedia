defmodule Sportipedia.Codegen.Blueprints.Query do
  @moduledoc """
  Executable transfer of `docs/architecture/blueprints/backend/domain/query.md`.

  Generates a query module for an ESDM **query** element: `import Ecto.Query`
  plus a `new/n` constructor. The concrete Ecto query depends on the feature
  specification (the last 1% the blueprint leaves to the spec), so the body
  carries a stable `TODO:` marker.

  Fixed shape; tested via the operation test file of the query.
  """

  use Sportipedia.Codegen.Blueprint

  alias Sportipedia.Codegen.{Context, FilePlan, Source, Templates, Unit}
  alias Sportipedia.Codegen.Blueprints.OperationTestFile

  @path "services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/queries/<_query>.ex"
  @module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Queries.<Query>"
  @test_path "services/api/test/sportipedia/<_subdomain>/<composite>/<domain_object>/operation/<_operation>_test.exs"
  @test_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Operation.<Operation>Test"

  def name, do: :query
  def source_kinds, do: [:query]

  def plans(%Context{} = ctx) do
    [
      %FilePlan{
        path: Context.render(@path, ctx),
        role: :module,
        module: Context.render(@module, ctx),
        scaffold: &scaffold/1,
        units: units()
      },
      OperationTestFile.plan(ctx,
        path: @test_path,
        module: @test_module,
        alias_templates: [],
        describes: [{"<Query> query", &describe_body/2}]
      )
    ]
  end

  defp scaffold(ctx) do
    """
    defmodule #{Context.render(@module, ctx)} do
      @moduledoc \"\"\"
      #{doc(ctx)}
      \"\"\"

      import Ecto.Query

    #{def_block(ctx) |> String.trim_trailing() |> Templates.indent(2)}
    end
    """
  end

  defp doc(ctx) do
    ctx.element.doc["description"] || "TODO: describe the #{ctx.element.name} query"
  end

  defp param_type(ctx) do
    if Context.one_of_params(ctx) != [], do: "String.t()", else: "map()"
  end

  defp def_block(ctx) do
    """
    @doc \"\"\"
    Creates a new query to fetch #{ctx.constituent}s.
    \"\"\"
    @spec new(#{param_type(ctx)}) :: Ecto.Query.t()
    def new(params) do
      # TODO: construct and return the query from the read model
      raise "TODO: implement #{ctx.element.name} query (see the feature spec)"
    end
    """
  end

  defp units do
    [
      %Unit{
        id: :moduledoc,
        check: &Source.has_moduledoc?/1,
        render: fn c -> "@moduledoc \"\"\"\n#{doc(c)}\n\"\"\"" end,
        anchor: fn src, _ctx -> {:after_line, Source.module_start_line(src)} end
      },
      %Unit{
        id: {:import, "Ecto.Query"},
        check: fn src -> Source.has_import?(src, "Ecto.Query") end,
        render: fn _ctx -> "import Ecto.Query" end,
        anchor: fn src, _ctx -> {:after_line, Source.module_start_line(src)} end
      },
      %Unit{
        id: {:def, :new, 1},
        check: fn src -> Source.has_def?(src, :new, 1) end,
        render: fn c -> def_block(c) |> String.trim_trailing() |> Templates.indent(2) end,
        anchor: fn src, _ctx -> Source.module_end_anchor(src) end
      }
    ]
  end

  defp describe_body(_ctx, subject) do
    """
    describe "#{subject}" do
      test "is a work in progress until the spec fills it" do
        # the query module body is the 1% the blueprint leaves to the spec
        assert true
      end
    end
    """
  end
end
