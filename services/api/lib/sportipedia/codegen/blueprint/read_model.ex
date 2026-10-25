defmodule Sportipedia.Codegen.Blueprint.ReadModel do
  @moduledoc """
  Executable transfer of `docs/architecture/blueprints/backend/domain/read-model.md`.

  Generates the shared read model (Ecto schema) and its changesets. Fixed
  shape: `insert_changeset/2` and `update_changeset/2` always both exist.

  Migrations are out of scope (Ecto's own generators handle them).
  """

  use Sportipedia.Codegen.Blueprint

  alias Sportipedia.Codegen.Esdm

  @path "services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/read_model.ex"
  @module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>ReadModel"

  def name, do: :read_model
  def source_kinds, do: [:"read-model"]

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
    fields = schema_fields(ctx)

    """
    defmodule #{Context.render(@module, ctx)} do
      @moduledoc \"\"\"
      #{moduledoc_text(ctx)}
      \"\"\"

      use TypedEctoSchema
      import Ecto.Changeset

      @primary_key {:id, :binary_id, autogenerate: false}
      @timestamps_opts [type: :utc_datetime_usec]
      @schema_prefix "#{ctx.subdomain}"

      typed_schema "#{ctx.constituent}" do
    #{fields |> Enum.map(fn f -> "    field :#{f.name}, #{Context.ecto_type(f)}" end) |> Enum.join("\n")}

        timestamps()
      end

      @doc \"\"\"
      Validates and prepares the #{ctx.constituent} read model for insertion.
      \"\"\"
      def insert_changeset(read_model, attrs) do
        read_model
        |> cast(attrs, [#{all_field_atoms(ctx)}])
        |> validate_required([#{required_field_atoms(ctx)}])
      end

      @doc \"\"\"
      Validates and prepares the #{ctx.constituent} read model for update.
      \"\"\"
      def update_changeset(read_model, attrs) do
        read_model
        |> cast(attrs, [#{updatable_field_atoms(ctx)}])
      end
    end
    """
  end

  defp moduledoc_text(ctx) do
    case Esdm.describe(ctx.element) do
      nil -> "Represents a #{ctx.constituent} in the #{ctx.composite}."
      desc -> desc
    end
  end

  defp schema_fields(ctx), do: Enum.reject(ctx.fields, &(&1.name == "id"))

  defp all_field_atoms(ctx) do
    ["id" | Enum.map(schema_fields(ctx), &":#{&1.name}")] |> Enum.join(", ")
  end

  defp required_field_atoms(ctx) do
    ctx.fields |> Enum.filter(& &1.required) |> Enum.map(&":#{&1.name}") |> Enum.join(", ")
  end

  defp updatable_field_atoms(ctx), do: Enum.map_join(schema_fields(ctx), ", ", &":#{&1.name}")

  # ------------------------------------------------------------------- units

  defp units(ctx) do
    base = [
      %Unit{
        id: :moduledoc,
        check: &Source.has_moduledoc?/1,
        render: fn c -> "@moduledoc \"\"\"\n#{moduledoc_text(c)}\n\"\"\"" end,
        place: Merge.head(:moduledoc)
      },
      %Unit{
        id: {:use, "TypedEctoSchema"},
        check: fn src -> Source.has_use?(src, "TypedEctoSchema") end,
        render: fn _ctx -> "use TypedEctoSchema" end,
        place: Merge.head(:use)
      },
      %Unit{
        id: {:import, "Ecto.Changeset"},
        check: fn src -> Source.has_import?(src, "Ecto.Changeset") end,
        render: fn _ctx -> "import Ecto.Changeset" end,
        place: Merge.head(:import)
      }
    ]

    base ++ attr_units() ++ field_units(ctx) ++ changeset_units(ctx)
  end

  defp attr_units do
    attrs = [
      {:primary_key, "@primary_key {:id, :binary_id, autogenerate: false}"},
      {:timestamps_opts, "@timestamps_opts [type: :utc_datetime_usec]"},
      {:schema_prefix, "@schema_prefix \"TODO-subdomain\""}
    ]

    Enum.map(attrs, fn {attr, text} ->
      %Unit{
        id: {:attribute, attr},
        check: fn src -> Source.has_attribute?(src, attr) end,
        render: fn c -> String.replace(text, "TODO-subdomain", c.subdomain) end,
        place: Merge.head(:attribute)
      }
    end)
  end

  defp field_units(ctx) do
    Enum.map(schema_fields(ctx), fn f ->
      key = ":#{f.name}"

      %Unit{
        id: {:field, f.name},
        check: fn src -> Source.entry?(src, :field, key) end,
        render: fn _ctx -> "field :#{f.name}, #{Context.ecto_type(f)}" end,
        place: Merge.inside(:typed_schema)
      }
    end)
  end

  defp changeset_units(_ctx) do
    for {name, atomize} <- [
          {"insert_changeset", &all_field_atoms/1},
          {"update_changeset", &updatable_field_atoms/1}
        ] do
      %Unit{
        id: {:def, String.to_atom(name), 2},
        check: fn src -> Source.has_def?(src, String.to_atom(name), 2) end,
        render: fn c ->
          """
          @doc \"\"\"
          Validates and prepares the #{c.constituent} read model for #{if name == "insert_changeset", do: "insertion", else: "update"}.
          \"\"\"
          def #{name}(read_model, attrs) do
            read_model
            |> cast(attrs, [#{atomize.(c)}])
          #{if name == "insert_changeset" do
            "    |> validate_required([#{required_field_atoms(c)}])"
          end}
          end
          """
        end,
        place: Merge.body_end()
      }
    end
  end
end
