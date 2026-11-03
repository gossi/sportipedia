defmodule SpGen.Blueprint.Validator do
  @moduledoc """
  Executable transfer of `docs/architecture/blueprints/backend/domain/validator.md`
  plus the example blueprints `examples/unique-slug.md` and
  `examples/domain-object-exists.md`.

  Generates one Vex validator per invariant/constraint of the domain model:

  * `unique-<field>` invariants → uniqueness against the internal API
    accessor, tolerating the object that already owns the value (edit case)
  * `<domain_object>-exists` command constraints → existence check by id
  * any other rule naming a field of the citizen (cross-field or
    cross-aggregate) → a scaffold the operator implements

  Rules that name no field (operational preconditions) are not validators
  and are skipped.

  Validators are tested as part of the command's tests (`validator.md`'s Test
  section delegates to `command.md`), so this generator contributes no test
  file of its own.
  """

  use SpGen.Blueprint

  alias SpGen.Blueprint.InternalAPI

  @path "services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/validators/<_validator>.ex"
  @module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Validators.<Validator>"
  @internal_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Internal"

  def name, do: :validator
  def source_kinds, do: [:command, :aggregate]

  @doc "The validator module's file path (used as a `requires` gate)."
  @spec module_file(Context.t(), map()) :: String.t()
  def module_file(%Context{} = ctx, validator) do
    Context.render(@path, ctx, %{"validator" => validator.snake})
  end

  def plans(%Context{} = ctx) do
    Enum.map(ctx.validators, fn validator ->
      %FilePlan{
        path: Context.render(@path, ctx, %{"validator" => validator.snake}),
        module: Context.render(@module, ctx, %{"validator" => validator.module}),
        units: units(validator, ctx),
        unit_created: true
      }
    end)
  end

  defp doc(%{kind: :unique} = v, ctx) do
    "Validates that a #{ctx.constituent} #{v.field} is unique within the #{ctx.composite}."
  end

  defp doc(%{kind: :exists}, ctx) do
    "Validates that a #{ctx.constituent} exists."
  end

  defp doc(%{kind: :rule} = v, _ctx) do
    "Validates the '#{v.name}' rule: #{v.rule}"
  end

  defp def_block(validator, ctx) do
    """
    @doc \"\"\"
    Validates the given #{validator.field} value.
    \"\"\"
    @spec validate(String.t(), map()) :: :ok | {:error, term()}
    #{body(validator, ctx) |> String.trim_trailing()}
    """
  end

  defp body(%{kind: :unique} = v, ctx) do
    internal = Context.pascal(ctx.constituent) <> "Internal"
    do_ = ctx.constituent
    helper = "#{v.field}_belongs_to_#{do_}?"

    """
    def validate(value, context) do
      with #{do_} <- #{internal}.#{do_}_by_#{v.field}(value),
           false <- is_nil(#{do_}),
           false <- #{helper}(#{do_}, context) do
        {:error, :#{v.field}_exists}
      else
        _ -> :ok
      end
    end

    defp #{helper}(#{do_}, context) do
      id = Map.get(context, :id)

      id == #{do_}.id
    end
    """
  end

  defp body(%{kind: :exists} = v, ctx) do
    internal = Context.pascal(ctx.constituent) <> "Internal"
    do_ = ctx.constituent

    """
    def validate(#{v.field}, _context) do
      case #{internal}.#{do_}_by_#{v.field}(#{v.field}) do
        nil -> {:error, :not_found}
        _ -> :ok
      end
    end
    """
  end

  # no example shape for the rule (cross-field, cross-aggregate, …):
  # scaffold it, the operator implements what the invariant demands
  defp body(%{kind: :rule} = v, _ctx) do
    """
    def validate(_value, _context) do
      raise "TODO: implement the #{v.name} validator (see the domain model rule)"
    end
    """
  end

  # ------------------------------------------------------------------- units

  defp units(validator, ctx) do
    internal = Context.render(@internal_module, ctx)

    # scaffolded rules call no query; the example shapes need the internal API
    alias_unit =
      if validator.kind == :rule do
        []
      else
        [
          %Unit{
            id: {:alias, internal},
            check: fn src -> Source.has_alias?(src, internal) end,
            render: fn c -> "alias #{Context.render(@internal_module, c)}" end,
            requires: internal_gate(validator),
            place: Merge.alias_of(internal)
          }
        ]
      end

    [
      %Unit{
        id: :moduledoc,
        check: &Source.has_moduledoc?/1,
        render: fn c -> "@moduledoc \"\"\"\n#{doc(validator, c)}\n\"\"\"" end,
        place: Merge.head(:moduledoc)
      },
      %Unit{
        id: {:use, "Vex.Validator"},
        check: fn src -> Source.has_use?(src, "Vex.Validator") end,
        render: fn _ctx -> "use Vex.Validator" end,
        place: Merge.head(:use)
      }
    ] ++
      alias_unit ++
      [
        %Unit{
          id: {:def, :validate, 2},
          check: fn src -> Source.has_def?(src, :validate, 2) end,
          render: fn c -> def_block(validator, c) end,
          requires: internal_gate(validator),
          place: Merge.before_helpers()
        }
      ]
  end

  # the internal API module must exist before the alias/lookup may appear
  defp internal_gate(%{kind: :rule}), do: fn _c -> [] end

  defp internal_gate(_validator) do
    fn c -> [{InternalAPI.module_file(c), "internal API not generated (spgen internal_api)"}] end
  end
end
