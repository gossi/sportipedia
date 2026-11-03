defmodule SpGen.Blueprint.Query do
  @moduledoc """
  Executable transfer of `docs/architecture/blueprints/backend/domain/query.md`
  — the query module file itself.

  Generates a query module for an ESDM **query** element: `import Ecto.Query`
  plus a `new/n` constructor. The concrete Ecto query depends on the feature
  specification (the last 1% the blueprint leaves to the spec), so the body
  carries a stable `TODO:` marker.

  Fixed shape; tested via `SpGen.Blueprint.QueryTest`.
  """

  use SpGen.Blueprint

  @path "services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/queries/<_query>.ex"
  @module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Queries.<Query>"

  def name, do: :query
  def source_kinds, do: [:query]

  @doc "The query module's file path (used as a `requires` gate)."
  @spec module_file(Context.t()) :: String.t()
  def module_file(%Context{} = ctx), do: Context.render(@path, ctx)

  def plans(%Context{} = ctx) do
    [
      %FilePlan{
        path: Context.render(@path, ctx),
        module: Context.render(@module, ctx),
        units: units(ctx),
        unit_created: true
      }
    ]
  end

  defp doc(ctx) do
    ctx.element.doc["description"] || "TODO: describe the #{ctx.element.name} query"
  end

  defp param_type(ctx) do
    if Context.one_of_params(ctx) != [], do: "String.t()", else: "map()"
  end

  # the scaffold is a warning-free `TODO:` marker: an unused parameter stays
  # underscore-prefixed until the body implements the query
  defp def_block(ctx) do
    """
    @doc \"\"\"
    Creates a new query to fetch #{ctx.constituent}s.
    \"\"\"
    @spec new(#{param_type(ctx)}) :: Ecto.Query.t()
    def new(_params) do
      # TODO: construct and return the query from the read model
      raise "TODO: implement #{ctx.element.name} query (see the feature spec)"
    end
    """
  end

  defp units(ctx) do
    base = [
      %Unit{
        id: :moduledoc,
        check: &Source.has_moduledoc?/1,
        render: fn c -> "@moduledoc \"\"\"\n#{doc(c)}\n\"\"\"" end,
        place: Merge.head(:moduledoc)
      },
      %Unit{
        id: {:def, :new, 1},
        check: fn src -> Source.has_def?(src, :new, 1) end,
        render: fn c -> def_block(c) |> String.trim_trailing() end,
        place: Merge.body_end()
      }
    ]

    # the scaffold raises; `Ecto.Query` becomes an unused import until the
    # query is written, so the import joins once the body implements it
    if implemented?(ctx) do
      import_unit() ++ base
    else
      base
    end
  end

  defp import_unit do
    [
      %Unit{
        id: {:import, "Ecto.Query"},
        check: fn src -> Source.has_import?(src, "Ecto.Query") end,
        render: fn _ctx -> "import Ecto.Query" end,
        place: Merge.head(:import)
      }
    ]
  end

  # the query is implemented once the file exists without the `TODO:` marker
  defp implemented?(%Context{} = ctx) do
    file = module_file(ctx)
    abs = if ctx.repo_root, do: Path.join(ctx.repo_root, file), else: file

    case File.read(abs) do
      {:ok, text} -> not (text =~ "TODO: implement")
      _ -> false
    end
  end
end
