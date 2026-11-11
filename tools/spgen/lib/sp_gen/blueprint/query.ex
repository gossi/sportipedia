defmodule SpGen.Blueprint.Query do
  @moduledoc """
  Executable transfer of `docs/architecture/blueprints/backend/domain/query.md`
  — the query module file itself.

  Generates a query module for an ESDM **query** element: the `new/n`
  constructor and the module shell. What the constructor's body is depends on
  what the model declares the query to be:

  * `spgen.operation: collection` — a JSON:API collection read. Its parameters
    *are* the standard set (`filter`/`sort`/`page`/`fields`), so the body is the
    one-liner that delegates to the shared `Sportipedia.Support.JSONAPI.QueryBuilder`.
    Nothing in the model is left unimplemented: the blueprint ships the working
    body, not a marker.
  * anything else — a read whose Ecto query depends on the feature specification
    (the last 1% the blueprint leaves to the spec), so the body carries a stable
    `TODO:` marker that raises.

  The `import Ecto.Query` is NOT managed here: only the implementing body knows
  whether it speaks query macros at all — a body delegating to the shared
  QueryBuilder needs none, and an unused import is a compile warning this tool
  must not manufacture. Whoever writes the body owns its imports; the compiler
  checks both ways.

  Fixed shape; tested via `SpGen.Blueprint.QueryTest`.
  """

  use SpGen.Blueprint

  alias SpGen.Blueprint.ReadModel

  @path "services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/queries/<_query>.ex"
  @module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Queries.<Query>"
  @read_model_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>ReadModel"
  @query_builder "Sportipedia.Support.JSONAPI.QueryBuilder"

  def name, do: :query
  def source_kinds, do: [:query]

  @doc "The query module's file path (used as a `requires` gate)."
  @spec module_file(Context.t()) :: String.t()
  def module_file(%Context{} = ctx), do: Context.render(@path, ctx)

  @doc "The query module's name template (the public API calls through it)."
  def module_template, do: @module

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

  @doc """
  A collection query delegates to the shared QueryBuilder over the read model, so
  the read model is the citizen this blueprint's code calls. A read query leaves
  its body to the spec and calls nothing yet.
  """
  def dependencies(%Context{operation: :collection} = ctx) do
    case ctx.read_model do
      nil -> []
      element -> [{ReadModel, element}]
    end
  end

  def dependencies(_ctx), do: []

  defp doc(ctx) do
    ctx.element.doc["description"] || "TODO: describe the #{ctx.element.name} query"
  end

  defp param_type(ctx) do
    cond do
      ctx.operation == :collection -> "JSONAPI.Config.t()"
      Context.one_of_params(ctx) != [] -> "String.t()"
      true -> "map()"
    end
  end

  defp read_model(ctx), do: Context.pascal(ctx.constituent) <> "ReadModel"

  # the delegating body of a declared collection read — no macros, no TODO
  defp def_block(%Context{operation: :collection} = ctx) do
    """
    @doc \"\"\"
    Creates a new query to fetch #{plural(ctx)}.
    \"\"\"
    @spec new(#{param_type(ctx)}) :: Ecto.Query.t()
    def new(query) do
      QueryBuilder.build(query, #{read_model(ctx)})
    end
    """
  end

  # the scaffold is a warning-free `TODO:` marker: an unused parameter stays
  # underscore-prefixed until the body implements the query
  defp def_block(ctx) do
    """
    @doc \"\"\"
    Creates a new query to fetch #{plural(ctx)}.
    \"\"\"
    @spec new(#{param_type(ctx)}) :: Ecto.Query.t()
    def new(_params) do
      # TODO: construct and return the query from the read model
      raise "TODO: implement #{ctx.element.name} query (see the feature spec)"
    end
    """
  end

  # prose through the placeholder engine, so an irregular stem stays right:
  # one apparatus, several apparatuses — `<> "s"` on the constituent would not be
  defp plural(%Context{} = ctx), do: Context.render("<domain_object>s", ctx)

  defp units(%Context{} = ctx) do
    [
      %Unit{
        id: :moduledoc,
        check: &Source.has_moduledoc?/1,
        render: fn c -> "@moduledoc \"\"\"\n#{doc(c)}\n\"\"\"" end,
        place: Merge.head(:moduledoc)
      },
      %Unit{
        id: {:def, :new, 1},
        check: fn src -> def_present?(src, ctx) end,
        stale: fn src, c -> stale_body(src, c) end,
        render: fn c -> def_block(c) |> String.trim_trailing() end,
        place: Merge.body_end()
      }
    ] ++ alias_units(ctx)
  end

  # A collection body is present only when it actually reads: a marker an earlier
  # run left there counts as missing, so it reaches `stale` and is reported —
  # never appended as a second clause, which would shadow the first.
  #
  # A read query's marker IS the delivery (its body is the spec's 1%), so there
  # `new/1` being defined is enough: reporting it every run would be noise, and
  # appending it would duplicate the clause.
  defp def_present?(%Source{} = src, %Context{operation: :collection}) do
    Source.has_def?(src, :new, 1) and not marker?(src.text)
  end

  defp def_present?(%Source{} = src, _ctx), do: Source.has_def?(src, :new, 1)

  # The merge never rewrites a line, so a body an earlier run left as a marker
  # stays standing after the model declares the read it is. The tool owns the
  # notice, the operator owns the edit.
  defp stale_body(%Source{text: text} = src, %Context{operation: :collection} = ctx) do
    cond do
      not Source.has_def?(src, :new, 1) ->
        []

      not marker?(text) ->
        []

      true ->
        [
          "new/1 still raises the marker the scaffold left — a collection read needs no " <>
            "spec work: replace the body with QueryBuilder.build(query, #{read_model(ctx)}) " <>
            "and alias that read model and Sportipedia.Support.JSONAPI.QueryBuilder"
        ]
    end
  end

  defp stale_body(_src, _ctx), do: []

  # the aliases a delegating body names; a TODO body names nothing, and an unused
  # alias is a compile warning this tool must not manufacture
  defp alias_units(%Context{operation: :collection} = ctx) do
    read_model_full = Context.render(@read_model_module, ctx)

    [
      alias_unit(read_model_full, fn c ->
        [{ReadModel.module_file(c), "read model not generated (spgen read_model)"}]
      end),
      alias_unit(@query_builder, fn _c -> [] end)
    ]
  end

  defp alias_units(_ctx), do: []

  defp alias_unit(module, requires) do
    %Unit{
      id: {:alias, module},
      check: fn src -> Source.has_alias?(src, module) or marker?(src.text) end,
      render: fn _c -> "alias #{module}" end,
      requires: requires,
      place: Merge.alias_of(module)
    }
  end

  # an unimplemented body: the scaffold's `raise "TODO …"`, which is exactly the
  # file this blueprint must not push aliases into
  defp marker?(text), do: text =~ "raise \"TODO"
end
