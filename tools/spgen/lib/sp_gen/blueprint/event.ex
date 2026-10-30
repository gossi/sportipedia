defmodule SpGen.Blueprint.Event do
  @moduledoc """
  Executable transfer of `docs/architecture/blueprints/backend/domain/event.md`
  — the event struct file itself.

  Templates follow what the operation does:

  * `--template create` — full facts, all required fields enforced
  * `--template update` — id enforced, payload partial; a `get_changes/1`
    function accompanies the struct (the projector's partial-update source)
  * `--template delete` — id-only fact
  """

  use SpGen.Blueprint

  alias SpGen.Templates

  @path "services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/events/<_event>.ex"
  @module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Event.<Event>"

  def name, do: :event
  def source_kinds, do: [:event]
  def operations, do: [:create, :update, :delete]
  def optional_template?, do: true

  @doc "The event's module-name template (referenced by `EventTest` and `Projector`)."
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
        place: Merge.head(:moduledoc)
      },
      use_unit("TypedStruct"),
      use_unit("ExConstructor"),
      %Unit{
        id: {:derive, "Jason.Encoder"},
        check: fn src -> Source.has_derive?(src, "Jason.Encoder") end,
        render: fn _ctx -> "@derive Jason.Encoder" end,
        place: Merge.head(:attribute)
      }
    ]

    base ++ field_units(ctx) ++ changes_units(ctx)
  end

  defp use_unit(module) do
    %Unit{
      id: {:use, module},
      check: fn src -> Source.has_use?(src, module) end,
      render: fn _ctx -> "use #{module}" end,
      place: Merge.head(:use)
    }
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
        place: Merge.body_end()
      }
    ]
  end
end
