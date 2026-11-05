defmodule SpGen.Blueprint.InternalAPI do
  @moduledoc """
  Executable transfer of `docs/architecture/blueprints/backend/domain/internal-api.md`.

  Maintains the constituent's internal API: `x_by_id/1` plus one accessor per
  unique-field invariant (`x_by_slug/1`, via the slug query from the
  `unique-slug` example). Used within the constituent only.

  It is reached two ways: as its own generator, and as the dependency of every
  validator a command generates — the file is generated together with the read
  model it reads and the lookup queries its accessors delegate to, so a
  generated accessor never points at a module that does not exist.
  """

  use SpGen.Blueprint

  alias SpGen.Blueprint.{LookupQuery, ReadModel}

  @path "services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/internal.ex"
  @module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Internal"
  @read_model_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>ReadModel"
  @repo_module "Sportipedia.<Subdomain>.Repo"

  def name, do: :internal_api
  def source_kinds, do: [:"read-model", :aggregate, :command, :event, :query]

  def dependencies(%Context{} = ctx) do
    case ctx.read_model do
      nil ->
        []

      element ->
        [{ReadModel, element}] ++
          if(Context.unique_fields(ctx) == [], do: [], else: [{LookupQuery, element}])
    end
  end

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
    query = LookupQuery.short_name(ctx, f)

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
      # the module is a lookup surface: without its read model nothing is
      # placeable, so the file appears with the first accessor it can hold
      %Unit{
        id: :moduledoc,
        check: &Source.has_moduledoc?/1,
        render: fn c ->
          "@moduledoc \"\"\"\nInternal API for querying #{c.constituent} read models within the bounded context.\n\"\"\""
        end,
        requires: read_model_gate(),
        place: Merge.head(:moduledoc)
      },
      %Unit{
        id: {:def, :"#{do_}_by_id", 1},
        check: fn src -> Source.has_def?(src, :"#{do_}_by_id", 1) end,
        requires: read_model_gate(),
        render: fn c -> c |> by_id_clause() end,
        place: Merge.before_helpers()
      },
      alias_unit(Context.render(@read_model_module, ctx), :"#{do_}_by_id", read_model_gate()),
      alias_unit(Context.render(@repo_module, ctx), :"#{do_}_by_id", fn _c -> [] end)
    ]

    accessor_units =
      Enum.map(Context.unique_fields(ctx), fn f ->
        accessor = :"#{do_}_by_#{f}"

        [
          %Unit{
            id: {:def, accessor, 1},
            check: fn src -> Source.has_def?(src, accessor, 1) end,
            requires: query_gate(f),
            render: fn c -> c |> accessor_clause(f) end,
            place: Merge.before_helpers()
          },
          alias_unit(LookupQuery.module_name(ctx, f), accessor, query_gate(f))
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

  defp read_model_gate do
    fn c -> [{ReadModel.module_file(c), "read model not generated (spgen read_model)"}] end
  end

  # accessor units delegate to the lookup query module; it is only placeable
  # once that module exists (the dependency pass creates it in this same run)
  defp query_gate(field) do
    reason = "lookup query for #{field} not generated (spgen internal_api)"
    fn c -> [{LookupQuery.module_file(c, field), reason}] end
  end
end
