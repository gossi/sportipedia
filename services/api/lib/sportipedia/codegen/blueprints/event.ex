defmodule Sportipedia.Codegen.Blueprints.Event do
  @moduledoc """
  Executable transfer of `docs/architecture/blueprints/backend/domain/event.md`.

  Generates the event struct module and contributes its `describe` block to
  the operation test file(s) of the command(s) publishing it.

  Templates follow what the operation does:

  * `--template create` — full facts, all required fields enforced
  * `--template update` — id enforced, payload partial; a `get_changes/1`
    function accompanies the struct (the projector's partial-update source)
  * `--template delete` — id-only fact
  """

  use Sportipedia.Codegen.Blueprint

  alias Sportipedia.Codegen.{Context, FilePlan, Source, Templates, Unit}
  alias Sportipedia.Codegen.Blueprints.OperationTestFile

  @path "services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/events/<_event>.ex"
  @module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Event.<Event>"
  @test_path "services/api/test/sportipedia/<_subdomain>/<composite>/<domain_object>/operation/<_operation>_test.exs"
  @test_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Operation.<Command>Test"

  def name, do: :event
  def source_kinds, do: [:event]
  def operations, do: [:create, :update, :delete]
  def optional_template?, do: true

  def plans(%Context{} = ctx) do
    [event_file(ctx)] ++ test_plans(ctx)
  end

  # ------------------------------------------------------------------ module

  defp event_file(ctx) do
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
      Context.render("<Describe what happened in the domain, derived from the event name.>", ctx)

    """
    defmodule #{Context.render(@module, ctx)} do
      @moduledoc \"\"\"
      #{doc}
      \"\"\"

      use TypedStruct
      use ExConstructor

      @derive Jason.Encoder
      @doc \"\"\"
      Creates a new #{Context.render("<Event>", ctx)} event.
      \"\"\"
      typedstruct do
    #{field_block(ctx)}
      end
    #{changes_block(ctx)}
    end
    """
  end

  defp field_block(ctx) do
    ctx.fields
    |> Enum.map(fn f -> "    " <> Templates.field_line(f) end)
    |> Enum.join("\n")
  end

  # get_changes/1 only for partial-update events
  defp changes_block(%Context{operation: op}) when op in [:create, :delete], do: "\n"

  defp changes_block(_ctx) do
    "\n\n" <>
      Templates.indent(
        """
        @doc \"\"\"
        Returns a map of only the non-nil changed fields (excluding id).
        \"\"\"
        @spec get_changes(t()) :: map()
        def get_changes(%__MODULE__{} = event) do
          event
          |> Map.from_struct()
          |> Map.drop([:id])
          |> Enum.reject(fn {_k, v} -> is_nil(v) end)
          |> Map.new()
        end
        """,
        2
      ) <>
      "\n"
  end

  # ------------------------------------------------------------------- units

  defp units(ctx) do
    base = [
      %Unit{
        id: :moduledoc,
        check: &Source.has_moduledoc?/1,
        render: fn c ->
          doc =
            Context.render(
              "<Describe what happened in the domain, derived from the event name.>",
              c
            )

          """
          @moduledoc \"\"\"
          #{doc}
          \"\"\"
          """
        end,
        anchor: fn src, _ctx -> {:after_line, Source.module_start_line(src)} end
      },
      use_unit("TypedStruct"),
      use_unit("ExConstructor"),
      %Unit{
        id: {:derive, "Jason.Encoder"},
        check: fn src -> Source.has_derive?(src, "Jason.Encoder") end,
        render: fn _ctx -> "@derive Jason.Encoder" end,
        anchor: fn src, _ctx ->
          Source.after_entry(
            src,
            :use,
            fn _ -> true end,
            {:after_line, Source.module_start_line(src)}
          )
        end
      }
    ]

    field_units(ctx) ++ changes_units(ctx) ++ base
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

  defp changes_units(%Context{operation: op}) when op in [:create, :delete], do: []

  defp changes_units(_ctx) do
    [
      %Unit{
        id: {:def, :get_changes, 1},
        check: fn src -> Source.has_def?(src, :get_changes, 1) end,
        render: fn _ctx ->
          """
          @doc \"\"\"
          Returns a map of only the non-nil changed fields (excluding id).
          \"\"\"
          @spec get_changes(t()) :: map()
          def get_changes(%__MODULE__{} = event) do
            event
            |> Map.from_struct()
            |> Map.drop([:id])
            |> Enum.reject(fn {_k, v} -> is_nil(v) end)
            |> Map.new()
          end
          """
        end,
        anchor: fn src, _ctx -> Source.module_end_anchor(src) end
      }
    ]
  end

  # -------------------------------------------------------------------- test

  # the event's tests live in the operation test file of every command that
  # publishes it
  defp test_plans(ctx) do
    ctx
    |> Context.publishing_commands()
    |> Enum.map(fn command ->
      extra_vars = %{"operation" => command.name, "command" => command.name}

      OperationTestFile.plan(ctx,
        path: @test_path,
        module: @test_module,
        extra_vars: extra_vars,
        alias_templates: [@module],
        describes: [{"<Event> event", &describe_body/2}]
      )
    end)
  end

  @doc false
  def describe_body(ctx, subject) do
    event = Context.render("<Event>", ctx)
    body = Templates.struct_body(ctx)

    tests = [
      """
      test "creates #{event} with required fields" do
        event = struct!(#{event}, %{#{body}})

        assert event.id != nil
      end
      """,
      """
      test "requires enforced fields" do
        assert_raise ArgumentError, fn ->
          struct!(#{event}, %{})
        end
      end
      """,
      """
      test "serializes to JSON" do
        event = struct!(#{event}, %{#{body}})

        assert {:ok, _json} = Jason.encode(event)
      end
      """
    ]

    """
    describe "#{subject}" do
    #{tests |> Enum.join("\n\n") |> Templates.indent(2)}
    end
    """
  end
end
