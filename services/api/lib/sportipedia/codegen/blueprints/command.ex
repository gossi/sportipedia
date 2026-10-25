defmodule Sportipedia.Codegen.Blueprints.Command do
  @moduledoc """
  Executable transfer of `docs/architecture/blueprints/backend/domain/command.md`.

  Generates the command struct module, its `describe` block in the operation
  test file, and registers the command in the composite's commanded router
  (`identify`/`dispatch`, aliases).

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

  alias Sportipedia.Codegen.{Context, FilePlan, Templates, Unit}
  alias Sportipedia.Codegen.Blueprints.OperationTestFile

  @path "services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/operation/<_operation>/command.ex"
  @module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Command.<Command>"
  @test_path "services/api/test/sportipedia/<_subdomain>/<composite>/<domain_object>/operation/<_operation>_test.exs"
  @test_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Operation.<Command>Test"
  @router_path "services/api/lib/sportipedia/<_subdomain>/<composite>/router.ex"

  def name, do: :command
  def source_kinds, do: [:command]
  def operations, do: [:create, :update, :delete]
  def optional_template?, do: true

  def plans(%Context{} = ctx) do
    [command_file(ctx), operation_test(ctx), router(ctx)]
  end

  # ------------------------------------------------------------------ module

  defp command_file(ctx) do
    %FilePlan{
      path: Context.render(@path, ctx),
      role: :module,
      module: Context.render(@module, ctx),
      scaffold: &scaffold/1,
      units: units(ctx)
    }
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
    moduledoc_unit()
    |> Kernel.++([use_unit("TypedStruct"), use_unit("ExConstructor"), use_unit("Vex.Struct")])
    |> Kernel.++(alias_units(ctx))
    |> Kernel.++(field_units(ctx))
    |> Kernel.++(validates_units(ctx))
  end

  defp moduledoc_unit do
    %Unit{
      id: :moduledoc,
      check: &Source.has_moduledoc?/1,
      render: fn ctx ->
        doc =
          Context.render(
            "<Describe what the command does to the aggregate, derived from the domain model.>",
            ctx
          )

        """
        @moduledoc \"\"\"
        #{doc}
        \"\"\"
        """
      end,
      anchor: fn src, _ctx -> {:after_line, Source.module_start_line(src)} end
    }
    |> List.wrap()
  end

  defp use_unit(module) do
    %Unit{
      id: {:use, module},
      check: fn src -> Source.has_use?(src, module) end,
      render: fn _ctx -> "use #{module}" end,
      anchor: fn src, _ctx ->
        Source.after_entry(
          src,
          :use,
          fn _ -> true end,
          {:after_line, Source.module_start_line(src)}
        )
      end
    }
  end

  defp alias_units(ctx) do
    Enum.map(ctx.validators, fn v ->
      full = validator_module(ctx, v)

      %Unit{
        id: {:alias, full},
        check: fn src -> Source.has_alias?(src, full) end,
        render: fn _ctx -> "alias #{full}" end,
        anchor: fn src, _ctx -> Source.alias_anchor(src, full) end,
        gap: :tight
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
        anchor: fn src, _ctx -> Source.inside_block(src, :typedstruct) end,
        gap: :tight
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
        anchor: fn src, _ctx ->
          Source.after_entry(
            src,
            :validates,
            fn _ -> true end,
            Source.after_entry(src, :use, &(&1 == "Vex.Struct"), Source.module_end_anchor(src))
          )
        end
      }
    end)
  end

  # -------------------------------------------------------------- test merge

  @doc false
  def operation_test(ctx) do
    OperationTestFile.plan(ctx,
      path: @test_path,
      module: @test_module,
      alias_templates: [@module],
      describes: [{"<Command> command", &describe_body/2}]
    )
  end

  @doc false
  def describe_body(ctx, subject) do
    cmd = Context.render("<Command>", ctx)

    tests =
      [requires_id_test(cmd)] ++
        id_nil_test(ctx, cmd) ++
        presence_tests(ctx, cmd)

    """
    describe "#{subject}" do
    #{tests |> Enum.join("\n\n") |> Templates.indent(2)}
    end
    """
  end

  defp requires_id_test(cmd) do
    """
    test "requires id" do
      assert_raise ArgumentError, fn ->
        struct!(#{cmd}, %{})
      end
    end
    """
  end

  defp id_nil_test(_ctx, cmd) do
    [
      """
      test "id cannot be nil" do
        cmd = %#{cmd}{id: nil}

        assert_raise ArgumentError, fn ->
          Vex.validate(cmd)
        end
      end
      """
    ]
  end

  defp presence_tests(ctx, cmd) do
    ctx.fields
    |> Enum.filter(&(&1.required and &1.name != "id"))
    |> Enum.map(fn f ->
      body =
        ctx.fields
        |> Enum.reject(&(&1.name == f.name))
        |> Enum.map(fn x -> "#{x.name}: #{Templates.sample_value(ctx, x)}" end)
        |> Enum.join(", ")

      """
      test "validates presence of #{f.name}" do
        cmd = %#{cmd}{#{body}, #{f.name}: nil}

        assert {:error, _errors} = Vex.validate(cmd)
      end
      """
    end)
  end

  # ------------------------------------------------------------- registration

  @doc false
  def router(ctx) do
    command = Context.render("<Command>", ctx)
    handler = command <> "Handler"
    aggregate = Context.render("<DomainObject>Aggregate", ctx)

    %FilePlan{
      path: Context.render(@router_path, ctx),
      role: :registration,
      module: nil,
      scaffold: nil,
      units:
        [
          registration_alias(ctx, @module),
          registration_alias(ctx, @module <> "Handler"),
          aggregate_alias(ctx),
          identify_unit(ctx),
          dispatch_unit(ctx, command, handler, aggregate)
        ]
        |> Enum.reject(&is_nil/1)
    }
  end

  defp registration_alias(ctx, module_template) do
    full = Context.render(module_template, ctx)

    %Unit{
      id: {:router_alias, full},
      check: fn src -> Source.has_alias?(src, full) end,
      render: fn _ctx -> "alias #{full}" end,
      anchor: fn src, _ctx -> Source.alias_anchor(src, full) end,
      gap: :tight
    }
  end

  defp aggregate_alias(ctx) do
    full =
      Context.render(
        "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Aggregate",
        ctx
      )

    %Unit{
      id: {:router_alias, full},
      check: fn src -> Source.has_alias?(src, full) end,
      render: fn _ctx -> "alias #{full}" end,
      anchor: fn src, _ctx -> Source.alias_anchor(src, full) end,
      gap: :tight
    }
  end

  defp identify_unit(ctx) do
    aggregate = Context.render("<DomainObject>Aggregate", ctx)

    %Unit{
      id: {:identify, aggregate},
      check: fn src -> Source.entry?(src, :identify, aggregate) end,
      render: fn c ->
        prefix = Context.render("<-composite>/<domain-object>/", c)
        "identify #{aggregate}, by: :id, prefix: \"#{prefix}\""
      end,
      anchor: fn src, _ctx ->
        Source.after_entry(
          src,
          :dispatch,
          fn _ -> true end,
          Source.after_entry(
            src,
            :middleware,
            fn _ -> true end,
            {:after_line, Source.module_start_line(src)}
          )
        )
      end
    }
  end

  defp dispatch_unit(_ctx, command, handler, aggregate) do
    %Unit{
      id: {:dispatch, command},
      check: fn src -> Source.entry?(src, :dispatch, command) end,
      render: fn _ctx ->
        "dispatch #{command}, to: #{handler}, aggregate: #{aggregate}"
      end,
      anchor: fn src, _ctx ->
        Source.after_entry_kw(
          src,
          :dispatch,
          :aggregate,
          fn value -> value == aggregate end,
          Source.after_entry(
            src,
            :identify,
            fn value -> value == aggregate end,
            Source.module_end_anchor(src)
          )
        )
      end
    }
  end
end
