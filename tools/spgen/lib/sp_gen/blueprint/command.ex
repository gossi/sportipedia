defmodule SpGen.Blueprint.Command do
  @moduledoc """
  Executable transfer of `docs/architecture/blueprints/backend/domain/command.md`
  — the command struct file itself.

  Templates follow what the operation does:

  * `--template create` — the public API generates the id, so the command
    carries it enforced; required data fields enforce, optional ones stay free
  * `--template update` — id enforced, data fields all partial
  * `--template delete` — id only

  A command validates with the validators its invariants and constraints
  imply: they are generated as this blueprint's dependencies, together with the
  internal API they call and the lookup queries their accessors read through
  (`SpGen.Blueprint.Validator`).

  Presence-based merging means running this over existing, hand-finished
  commands is a no-op as long as module, `use`s, aliases, fields and
  validations exist. A `validates` line counts as present only when it carries
  every rule the model now states for that field; an incomplete one is reported
  (`Outdated`) rather than appended to, because Vex keys validations per field —
  a second line would replace the first, not extend it.
  """

  use SpGen.Blueprint

  alias SpGen.Templates
  alias SpGen.Blueprint.Validator

  @path "services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/operations/<_operation>/command.ex"
  @module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Command.<Command>"

  def name, do: :command
  def source_kinds, do: [:command]
  def operations, do: [:create, :update, :delete]
  def optional_template?, do: true

  def dependencies(%Context{} = ctx) do
    if ctx.validators == [], do: [], else: [{Validator, ctx.element}]
  end

  @doc "The command's module-name template (referenced by `CommandTest` and `CommandRouter`)."
  def module_template, do: @module

  @doc "The command module's file path (used as a `requires` gate)."
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

  defp validator_module(ctx, v) do
    Context.render(
      "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Validators.#{v.module}",
      ctx
    )
  end

  # ------------------------------------------------------------------- units

  defp units(ctx) do
    [
      %Unit{
        id: :moduledoc,
        check: &Source.has_moduledoc?/1,
        render: fn c ->
          doc =
            Context.render(
              "<Describe what the command does to the aggregate, derived from the domain model.>",
              c
            )

          """
          @moduledoc \"\"\"
          #{doc}
          \"\"\"
          """
        end,
        place: Merge.head(:moduledoc)
      },
      use_unit("TypedStruct"),
      use_unit("ExConstructor"),
      use_unit("Vex.Struct")
    ] ++
      alias_units(ctx) ++
      field_units(ctx) ++
      validates_units(ctx)
  end

  defp use_unit(module) do
    %Unit{
      id: {:use, module},
      check: fn src -> Source.has_use?(src, module) end,
      render: fn _ctx -> "use #{module}" end,
      place: Merge.head(:use)
    }
  end

  defp alias_units(ctx) do
    Enum.map(ctx.validators, fn v ->
      full = validator_module(ctx, v)

      %Unit{
        id: {:alias, full},
        check: fn src -> Source.has_alias?(src, full) end,
        render: fn _ctx -> "alias #{full}" end,
        requires: validator_gate(ctx, v),
        place: Merge.alias_of(full)
      }
    end)
  end

  defp field_units(ctx) do
    Enum.map(ctx.fields, fn f ->
      key = ":#{f.name}"

      %Unit{
        id: {:field, f.name},
        check: fn src -> Source.entry?(src, :field, key) end,
        render: fn _ctx -> Templates.field_line(f) end,
        place: Merge.inside(:typedstruct, fn _ctx, text -> "typedstruct do\n#{text}\nend" end)
      }
    end)
  end

  defp validator_gate(ctx, v) do
    path = Validator.module_file(ctx, v)
    reason = "validator #{v.snake} not generated (spgen command)"
    fn _c -> [{path, reason}] end
  end

  defp validates_units(ctx) do
    ctx.fields
    |> Enum.map(fn f -> {f, Templates.validates_line(f, ctx.validators)} end)
    |> Enum.reject(fn {_f, line} -> is_nil(line) end)
    |> Enum.map(fn {f, line} ->
      %Unit{
        id: {:validates, f.name},
        check: fn src -> validates_complete?(src, f, ctx.validators) end,
        stale: fn src, _c -> stale_validations(src, f, ctx.validators) end,
        render: fn _ctx -> line end,
        requires: fn c -> validator_gates(c, f) end,
        place:
          Merge.after_macro(
            :validates,
            fn _ -> true end,
            Merge.after_directives()
          )
      }
    end)
  end

  # every validator guarding the field gates the line: a `validates` line may
  # never reference a validator whose file does not exist
  defp validator_gates(c, field) do
    field
    |> Templates.validators_for(c.validators)
    |> Enum.map(fn v ->
      {Validator.module_file(c, v), "validator #{v.snake} not generated (spgen command)"}
    end)
  end

  # ------------------------------------------------------ validates currency

  # one `validates` line carries presence plus one `by:` pair per validator
  # (Vex keys validations by field, so a second call would replace the first) —
  # presence of *a* line is therefore not presence of *this* line. A line is
  # never appended twice: an incomplete one is reported instead.
  defp validates_complete?(src, field, validators) do
    line?(src, field) and stale_validations(src, field, validators) == []
  end

  defp stale_validations(src, field, validators) do
    if line?(src, field) do
      src |> Source.entry_kws(:validates, ":#{field.name}") |> stale_details(field, validators)
    else
      []
    end
  end

  defp line?(src, field), do: Source.entry?(src, :validates, ":#{field.name}")

  defp stale_details(kws, field, validators) do
    by_values = for {:by, value} <- kws, do: value

    presence =
      if Templates.validates_presence?(field) and
           not Enum.any?(kws, &match?({:presence, "true"}, &1)) do
        ["add presence: true"]
      else
        []
      end

    missing =
      field
      |> Templates.validators_for(validators)
      |> Enum.reject(fn v ->
        needle = Templates.validates_needle(v)
        Enum.any?(by_values, &String.contains?(&1, needle))
      end)
      |> Enum.map(fn v -> "add " <> Templates.validates_by_pair(v) end)

    presence ++ missing
  end
end
