defmodule SpGen.Blueprint.Validator do
  @moduledoc """
  Executable transfer of `docs/architecture/blueprints/backend/domain/validator.md`
  plus the example blueprints `examples/unique-slug.md` and
  `examples/domain-object-exists.md`.

  Generates one Vex validator per invariant/constraint the
  `SpGen.Invariant` registry resolved for the citizen:

  * `unique-<field>` invariants → uniqueness against the internal API
    accessor, tolerating the object that already owns the value (edit case)
  * `<domain_object>-exists` command constraints → existence check by id,
    guarded by `Sportipedia.Support.Validators.UuidValidator.valid_uuid?/1`
    so no value that cannot denote the resource (nil, blank, malformed)
    reaches `Repo.get/2` — those raise, and a raise answers the client a 500
  * any other rule naming a field of the citizen (cross-field or
    cross-aggregate) → a scaffold the operator implements

  Rules that name no field (operational preconditions) are not validators;
  they stay visible in `SpGen.Context.unresolved`.

  This blueprint is not a generator: the command that validates with the
  validator owns it, the way it owns its router registration. Generating a
  validator generates the internal API it calls and the lookup query that
  accessor reads through — see `SpGen.Blueprint.InternalAPI` and
  `SpGen.Blueprint.LookupQuery`.

  Validators are tested as part of the command's tests (`validator.md`'s Test
  section delegates to `command.md`), so this blueprint contributes no test
  file of its own.
  """

  use SpGen.Blueprint

  alias SpGen.Blueprint.InternalAPI

  @path "services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/validators/<_validator>.ex"
  @module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Validators.<Validator>"
  @internal_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Internal"
  # the total UUID guard the exists shape puts in front of the by-id lookup
  @uuid_validator "Sportipedia.Support.Validators.UuidValidator"

  def name, do: :validator
  def source_kinds, do: [:command]

  def dependencies(%Context{} = ctx) do
    if Enum.any?(ctx.validators, &(&1.kind != :rule)), do: [{InternalAPI, ctx.element}], else: []
  end

  @doc "The validator module's file path (used as a `requires` gate)."
  @spec module_file(Context.t(), map()) :: String.t()
  def module_file(%Context{} = ctx, validator) do
    Context.render(@path, ctx, %{"validator" => validator.snake})
  end

  def plans(%Context{} = ctx) do
    # One rule is one validator module even when it names several fields: the
    # descriptors multiply per field, the file does not.
    ctx.validators
    |> Enum.uniq_by(& &1.snake)
    |> Enum.map(fn validator ->
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
    """
    Validates that a #{ctx.constituent} exists.

    The rule is asked of an address: only a value that can denote a
    #{ctx.constituent} is looked up. A malformed id addresses nothing, so no
    #{ctx.constituent} can hold it, and the answer is the one the pattern gives
    for an unknown id. An absent or blank id is not this rule's to answer —
    `presence` owns it, and the command's `validates` line keeps this validator
    off it.
    """
  end

  defp doc(%{kind: :rule} = v, _ctx) do
    "Validates the '#{v.name}' rule: #{v.rule}"
  end

  defp def_block(%{kind: :exists} = validator, ctx) do
    """
    @doc \"\"\"
    Validates the given #{validator.field} value.
    \"\"\"
    # `term()`, not `String.t()`: the value reaches here straight off the request,
    # and a request can name an id with anything at all.
    @spec validate(term(), map()) :: :ok | {:error, :not_found}
    #{body(validator, ctx) |> String.trim_trailing()}
    """
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
      # The existence check is a round trip on the primary key, and `Repo.get/2`
      # raises on a value it cannot put in that clause: nil, a blank string, an
      # id of the wrong shape. A raise here reaches the client as 500. A
      # value that cannot denote the resource denotes no resource — the pattern's
      # own verdict for an unknown id, given without leaving the process.
      if UuidValidator.valid_uuid?(#{v.field}) do
        case #{internal}.#{do_}_by_#{v.field}(#{v.field}) do
          nil -> {:error, :not_found}
          _#{do_} -> :ok
        end
      else
        {:error, :not_found}
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
            render: fn c -> alias_lines(validator, c) end,
            requires: internal_gate(validator),
            place: Merge.alias_of(internal)
          }
        ]
      end

    [
      # a validator of an example shape is a call into the internal API: with
      # no internal API to alias, nothing is placeable and the file stays away
      %Unit{
        id: :moduledoc,
        check: &Source.has_moduledoc?/1,
        render: fn c ->
          "@moduledoc \"\"\"\n#{doc(validator, c) |> String.trim_trailing()}\n\"\"\""
        end,
        requires: internal_gate(validator),
        place: Merge.head(:moduledoc)
      },
      %Unit{
        id: {:use, "Vex.Validator"},
        check: fn src -> Source.has_use?(src, "Vex.Validator") end,
        render: fn _ctx -> "use Vex.Validator" end,
        requires: internal_gate(validator),
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

  # The exists shape guards the lookup with `Sportipedia.Support.Validators.UuidValidator`,
  # and that alias travels inside this unit on purpose: a validator file that predates
  # the guard already carries the internal alias, so this unit counts as present and the
  # old file stays untouched — as a unit of its own, the alias would be appended to every
  # old file, unused by the unguarded body still sitting there.
  defp alias_lines(%{kind: :exists}, ctx) do
    "alias #{Context.render(@internal_module, ctx)}\nalias #{@uuid_validator}"
  end

  defp alias_lines(_validator, ctx), do: "alias #{Context.render(@internal_module, ctx)}"
end
