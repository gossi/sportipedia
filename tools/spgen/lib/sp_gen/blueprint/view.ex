defmodule SpGen.Blueprint.View do
  @moduledoc """
  Executable transfer of `docs/architecture/blueprints/backend/web/view.md`
  — the JSON:API view file itself.

  Generates the JSON:API view for a **read model** element: `use JSONAPI.View`
  with the singular type, the resource `path/0`, and `fields/0` from the read
  model's schema (id and timestamps excluded — they are not attributes).
  """

  use SpGen.Blueprint

  @path "services/api/lib/sportipedia_web/<_subdomain>/<composite>/<domain_object>/<domain_object>_view.ex"
  @module "SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>View"
  @read_model_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>ReadModel"

  def name, do: :view
  def source_kinds, do: [:"read-model"]

  @doc false
  def module_template, do: @module

  @doc "The view's file path (used as a `requires` gate)."
  @spec module_file(Context.t()) :: String.t()
  def module_file(%Context{} = ctx), do: Context.render(@path, ctx)
  @doc false
  def read_model_template, do: @read_model_module

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

  @doc "Viewable attributes of the read model (no id, no timestamps)."
  def view_fields(%Context{} = ctx) do
    ctx.fields
    |> Enum.reject(&(&1.name in ["id", "inserted_at", "updated_at"]))
    |> Enum.map(&":#{&1.name}")
  end

  @doc "The JSON:API resource path, e.g. `catalog/equipment/apparatuses`."
  def view_path(%Context{} = ctx) do
    Context.render("<-subdomain>/<composite>/<domain-object>s", ctx)
  end

  # ------------------------------------------------------------------- units

  defp units(_ctx) do
    [
      %Unit{
        id: :moduledoc,
        check: &Source.has_moduledoc?/1,
        render: fn c ->
          "@moduledoc \"\"\"\nRenders #{c.constituent} resources in JSON:API format.\n\"\"\""
        end,
        place: Merge.head(:moduledoc)
      },
      %Unit{
        id: {:use, "JSONAPI.View"},
        check: fn src -> Source.has_use?(src, "JSONAPI.View") end,
        render: fn c -> "use JSONAPI.View, type: \"#{c.constituent}\"" end,
        place: Merge.head(:use)
      },
      %Unit{
        id: {:def, :path, 0},
        check: fn src -> Source.has_def?(src, :path, 0) end,
        render: fn c -> "def path, do: \"#{view_path(c)}\"" end,
        place: Merge.body_end()
      },
      %Unit{
        id: {:def, :fields, 0},
        check: fn src -> Source.has_def?(src, :fields, 0) end,
        render: fn c -> "def fields, do: [#{Enum.join(view_fields(c), ", ")}]" end,
        place: Merge.body_end()
      }
    ]
  end
end
