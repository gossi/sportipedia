defmodule SpGen.Blueprint.LookupQuery do
  @moduledoc """
  Executable transfer of the query half of
  `docs/architecture/blueprints/backend/domain/examples/unique-slug.md`.

  One `Queries.<DomainObject>By<Field>` module per field a unique invariant
  declares: the single-value lookup the internal API accessor delegates to. It
  is not an ESDM `query` element — the model states the invariant, not the
  read side of it — so this blueprint derives the shape from the pattern, while
  `SpGen.Blueprint.Query` transfers the citizen's modelled queries.

  Reached as a dependency of the internal API, which is a dependency of the
  validator a command needs: the accessor and its query appear together, in one
  run, so no generated code ever calls a module that is not there.
  """

  use SpGen.Blueprint

  alias SpGen.Blueprint.ReadModel

  @path "services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/queries/<_query>.ex"
  @module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Queries.<Query>"

  def name, do: :lookup_query
  def source_kinds, do: [:"read-model", :aggregate, :command]

  def dependencies(%Context{} = ctx) do
    case ctx.read_model do
      nil -> []
      element -> [{ReadModel, element}]
    end
  end

  @doc "The query name of a unique field (`position-by-slug`)."
  @spec query_name(Context.t(), String.t()) :: String.t()
  def query_name(%Context{} = ctx, field), do: "#{ctx.constituent}-by-#{field}"

  @doc "The lookup query's module name for `field` (used to alias it)."
  @spec module_name(Context.t(), String.t()) :: String.t()
  def module_name(%Context{} = ctx, field) do
    Context.render(@module, ctx, %{"query" => query_name(ctx, field)})
  end

  @doc "The lookup query's module name as code refers to it (`PositionBySlug`)."
  @spec short_name(Context.t(), String.t()) :: String.t()
  def short_name(%Context{} = ctx, field) do
    ctx |> module_name(field) |> String.split(".") |> List.last()
  end

  @doc "The lookup query's file path (used as a `requires` gate)."
  @spec module_file(Context.t(), String.t()) :: String.t()
  def module_file(%Context{} = ctx, field) do
    Context.render(@path, ctx, %{"query" => query_name(ctx, field)})
  end

  def plans(%Context{} = ctx) do
    Enum.map(Context.unique_fields(ctx), fn field ->
      %FilePlan{
        path: module_file(ctx, field),
        module: module_name(ctx, field),
        units: units(ctx, field),
        unit_created: true
      }
    end)
  end

  defp read_model(ctx), do: Context.pascal(ctx.constituent) <> "ReadModel"

  defp def_block(ctx, field) do
    """
    @doc \"\"\"
    Creates a new query to fetch a #{ctx.constituent} by #{field}.
    \"\"\"
    @spec new(String.t()) :: Ecto.Query.t()
    def new(#{field}) do
      from(r in #{read_model(ctx)},
        where: r.#{field} == ^#{field}
      )
    end
    """
    |> String.trim_trailing()
  end

  # ------------------------------------------------------------------- units

  defp units(ctx, field) do
    read_model_module = Context.render(read_model_template(), ctx)

    [
      %Unit{
        id: :moduledoc,
        check: &Source.has_moduledoc?/1,
        render: fn c ->
          "@moduledoc \"\"\"\nQuery to fetch a #{c.constituent} by its #{field}.\n\"\"\""
        end,
        place: Merge.head(:moduledoc)
      },
      %Unit{
        id: {:alias, read_model_module},
        check: fn src -> Source.has_alias?(src, read_model_module) end,
        render: fn c -> "alias #{Context.render(read_model_template(), c)}" end,
        requires: read_model_gate(),
        place: Merge.alias_of(read_model_module)
      },
      %Unit{
        id: {:import, "Ecto.Query"},
        check: fn src -> Source.has_import?(src, "Ecto.Query") end,
        render: fn _ctx -> "import Ecto.Query" end,
        place: Merge.head(:import)
      },
      %Unit{
        id: {:def, :new, 1},
        check: fn src -> Source.has_def?(src, :new, 1) end,
        render: fn c -> def_block(c, field) end,
        requires: read_model_gate(),
        place: Merge.body_end()
      }
    ]
  end

  defp read_model_template,
    do: "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>ReadModel"

  defp read_model_gate do
    fn c -> [{ReadModel.module_file(c), "read model not generated (spgen read_model)"}] end
  end
end
