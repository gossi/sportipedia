defmodule Sportipedia.Codegen.Blueprint.Command do
  @moduledoc """
  Executable transfer of `docs/architecture/blueprints/backend/domain/command.md`
  — the command struct file itself.

  Templates follow what the operation does:

  * `--template create` — the public API generates the id, so the command
    carries it enforced; required data fields enforce, optional ones stay free
  * `--template update` — id enforced, data fields all partial
  * `--template delete` — id only

  Presence-based merging means running this over existing, hand-finished
  commands is a no-op as long as module, `use`s, aliases, fields and
  validations exist.
  """

  use Sportipedia.Codegen.Blueprint

  alias Sportipedia.Codegen.Templates

  @path "services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/operation/<_operation>/command.ex"
  @module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Command.<Command>"

  def name, do: :command
  def source_kinds, do: [:command]
  def operations, do: [:create, :update, :delete]
  def optional_template?, do: true

  @doc "The command's module-name template (referenced by `CommandTest` and `CommandRouter`)."
  def module_template, do: @module

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

  @doc false
  def scaffold(ctx) do
    doc =
      Context.render(
        "<Describe what the command does to the aggregate, derived from the domain model.>",
        ctx
      )

    aliases = alias_block(ctx)
    fields = field_block(ctx)
    validations = validation_block(ctx)

    """
    defmodule #{Context.render(@module, ctx)} do
      @moduledoc \"\"\"
      #{doc}
      \"\"\"

      use TypedStruct
      use ExConstructor
    #{aliases}
      @doc \"\"\"
      Creates a new #{Context.render("<Command>", ctx)} command.
      \"\"\"
      typedstruct do
    #{fields}
      end

      # Validation
      use Vex.Struct
    #{validations}
    end
    """
  end

  defp alias_block(ctx) do
    case ctx.validators do
      [] ->
        "\n"

      validators ->
        "\n" <>
          Enum.map_join(validators, "\n", fn v ->
            "  alias #{validator_module(ctx, v)}"
          end) <> "\n"
    end
  end

  defp field_block(ctx) do
    ctx.fields
    |> Enum.map(fn f -> "    " <> Templates.field_line(f) end)
    |> Enum.join("\n")
  end

  defp validation_block(ctx) do
    lines = Templates.validates_lines(ctx)

    if lines == [] do
      "\n"
    else
      "\n" <> Enum.map_join(lines, "\n", fn l -> "  " <> l end) <> "\n"
    end
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
        place: Merge.inside(:typedstruct)
      }
    end)
  end

  defp validates_units(ctx) do
    ctx.fields
    |> Enum.map(fn f -> {f, Templates.validates_line(f, ctx.validators)} end)
    |> Enum.reject(fn {_f, line} -> is_nil(line) end)
    |> Enum.map(fn {f, line} ->
      key = ":#{f.name}"

      %Unit{
        id: {:validates, f.name},
        check: fn src -> Source.entry?(src, :validates, key) end,
        render: fn _ctx -> line end,
        place:
          Merge.after_macro(
            :validates,
            fn _ -> true end,
            Merge.after_macro(:use, fn first -> first == "Vex.Struct" end)
          )
      }
    end)
  end
end
