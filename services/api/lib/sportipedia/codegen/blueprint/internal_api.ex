defmodule Sportipedia.Codegen.Blueprint.InternalAPI do
  @moduledoc """
  Executable transfer of `docs/architecture/blueprints/backend/domain/internal-api.md`.

  Maintains the constituent's internal API: `x_by_id/1` plus one accessor per
  unique-field invariant (`x_by_slug/1`, via the slug query from the
  `unique-slug` example). Used within the constituent only.
  """

  use Sportipedia.Codegen.Blueprint

  alias Sportipedia.Codegen.Templates

  @path "services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/internal.ex"
  @module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Internal"
  @read_model_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>ReadModel"
  @repo_module "Sportipedia.<Subdomain>.Repo"

  def name, do: :internal_api
  def source_kinds, do: [:"read-model", :aggregate, :command, :event, :query]

  def plans(%Context{} = ctx) do
    [
      %FilePlan{
        path: Context.render(@path, ctx),
        module: Context.render(@module, ctx),
        scaffold: &scaffold/1,
        units: units(ctx)
      }
    ]
  end

  defp scaffold(ctx) do
    by_id = by_id_clause(ctx)
    by_slugs = Enum.map(unique_fields(ctx), fn f -> accessor_clause(ctx, f) end)

    aliases =
      [
        "  alias #{Context.render(@read_model_module, ctx)}",
        "  alias #{Context.render(@repo_module, ctx)}"
      ] ++ query_alias_lines(ctx)

    """
    defmodule #{Context.render(@module, ctx)} do
      @moduledoc \"\"\"
      Internal API for querying #{ctx.constituent} read models within the bounded context.
      \"\"\"

    #{Enum.join(aliases, "\n")}

    #{Templates.indent(by_id, 2)}
    #{(by_slugs ++ []) |> Enum.join("\n\n") |> then(fn s -> if s == "", do: "", else: "\n" <> Templates.indent(s, 2) end)}
    end
    """
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

  defp query_alias_lines(ctx) do
    Enum.map(unique_fields(ctx), fn f -> "  alias #{query_module_for(ctx, f)}" end)
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
        render: fn c -> c |> by_id_clause() end,
        place: Merge.before_helpers()
      },
      alias_unit(Context.render(@read_model_module, ctx), :"#{do_}_by_id"),
      alias_unit(Context.render(@repo_module, ctx), :"#{do_}_by_id")
    ]

    accessor_units =
      Enum.map(unique_fields(ctx), fn f ->
        accessor = :"#{do_}_by_#{f}"

        [
          %Unit{
            id: {:def, accessor, 1},
            check: fn src -> Source.has_def?(src, accessor, 1) end,
            render: fn c -> c |> accessor_clause(f) end,
            place: Merge.before_helpers()
          },
          alias_unit(query_module_for(ctx, f), accessor)
        ]
      end)
      |> List.flatten()

    base ++ accessor_units
  end

  defp alias_unit(module, owner_def) do
    %Unit{
      id: {:alias, module},
      check: fn src -> Source.has_alias?(src, module) || Source.has_def?(src, owner_def, 1) end,
      render: fn _ctx -> "alias #{module}" end,
      place: Merge.alias_of(module)
    }
  end
end
