defmodule SpGen.Blueprint.InternalAPI do
  @moduledoc """
  Executable transfer of `docs/architecture/blueprints/backend/domain/internal-api.md`.

  Maintains the constituent's internal API: `x_by_id/1` plus one accessor per
  unique-field invariant (`x_by_slug/1`, via the slug query from the
  `unique-slug` example). Used within the constituent only.
  """

  use SpGen.Blueprint

  alias SpGen.Blueprint.ReadModel

  @path "services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/internal.ex"
  @module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Internal"
  @read_model_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>ReadModel"
  @repo_module "Sportipedia.<Subdomain>.Repo"

  def name, do: :internal_api
  def source_kinds, do: [:"read-model", :aggregate, :command, :event, :query]

  @doc "The internal API's file path (used as a `requires` gate)."
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

  defp unique_fields(ctx) do
    ctx.validators
    |> Enum.filter(&(&1.kind == :unique))
    |> Enum.map(& &1.field)
  end

  defp query_module_for(ctx, field) do
    pascal_field = Context.pascal(field)

    Context.render(
      "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Queries.<DomainObject>By#{pascal_field}",
      ctx
    )
  end

  defp by_id_clause(ctx) do
    do_ = ctx.constituent
    read_model = Context.pascal(ctx.constituent) <> "ReadModel"

    """
    @doc \"\"\"
    Fetches a #{do_} by its ID. Returns nil if not found.
    \"\"\"
    @spec #{do_}_by_id(String.t()) :: #{read_model}.t() | nil
    def #{do_}_by_id(id) do
      Repo.get(#{read_model}, id)
    end
    """
    |> String.trim_trailing()
  end

  defp accessor_clause(ctx, f) do
    do_ = ctx.constituent
    read_model = Context.pascal(ctx.constituent) <> "ReadModel"
    query = Context.pascal(ctx.constituent) <> "By" <> Context.pascal(f)

    """
    @doc \"\"\"
    Fetches a #{do_} by its #{f}. Returns nil if not found.
    \"\"\"
    @spec #{do_}_by_#{f}(String.t()) :: #{read_model}.t() | nil
    def #{do_}_by_#{f}(#{f}) do
      #{f}
      |> String.downcase()
      |> #{query}.new()
      |> Repo.one()
    end
    """
    |> String.trim_trailing()
  end

  # ------------------------------------------------------------------- units

  defp units(ctx) do
    do_ = ctx.constituent

    base = [
      %Unit{
        id: :moduledoc,
        check: &Source.has_moduledoc?/1,
        render: fn c ->
          "@moduledoc \"\"\"\nInternal API for querying #{c.constituent} read models within the bounded context.\n\"\"\""
        end,
        place: Merge.head(:moduledoc)
      },
      %Unit{
        id: {:def, :"#{do_}_by_id", 1},
        check: fn src -> Source.has_def?(src, :"#{do_}_by_id", 1) end,
        requires: fn c ->
          [{ReadModel.module_file(c), "read model not generated (spgen read_model)"}]
        end,
        render: fn c -> c |> by_id_clause() end,
        place: Merge.before_helpers()
      },
      alias_unit(
        Context.render(@read_model_module, ctx),
        :"#{do_}_by_id",
        fn c -> [{ReadModel.module_file(c), "read model not generated (spgen read_model)"}] end
      ),
      alias_unit(Context.render(@repo_module, ctx), :"#{do_}_by_id", fn _c -> [] end)
    ]

    accessor_units =
      Enum.map(unique_fields(ctx), fn f ->
        accessor = :"#{do_}_by_#{f}"

        [
          %Unit{
            id: {:def, accessor, 1},
            check: fn src -> Source.has_def?(src, accessor, 1) end,
            requires: query_gate(ctx, f),
            render: fn c -> c |> accessor_clause(f) end,
            place: Merge.before_helpers()
          },
          alias_unit(query_module_for(ctx, f), accessor, query_gate(ctx, f))
        ]
      end)
      |> List.flatten()

    base ++ accessor_units
  end

  defp alias_unit(module, owner_def, gate) do
    %Unit{
      id: {:alias, module},
      check: fn src -> Source.has_alias?(src, module) || Source.has_def?(src, owner_def, 1) end,
      render: fn _ctx -> "alias #{module}" end,
      requires: gate,
      place: Merge.alias_of(module)
    }
  end

  # accessor units reference the field-query module; it is only placeable
  # once that query citizen exists
  defp query_gate(ctx, field) do
    file =
      ctx
      |> query_module_for(field)
      |> then(fn mod -> mod |> String.split(".") |> List.last() end)
      |> Macro.underscore()

    path =
      "services/api/lib/sportipedia/#{ctx.subdomain}/#{ctx.composite}/#{ctx.constituent}/queries/#{file}.ex"

    reason = "query for #{field} not generated (spgen query)"
    fn _c -> [{path, reason}] end
  end
end
