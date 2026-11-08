defmodule SpGen.Blueprint.Factory do
  @moduledoc """
  Executable transfer of `docs/architecture/blueprints/backend/domain/test-support.md`
  (factory half).

  Generates the **factory functions** of a composite: one `new_<domain_object>/1`
  pair plus `new_<domain_object>s/1` per read model, appended into the shared
  composite file:

      path:   services/api/test/support/<_subdomain>/<composite>/<composite>.ex
      module: Sportipedia.TestSupport.<Subdomain>.<Composite>

  This file is the append-only ledger, like the router or the supervisor: the
  first read model of the composite creates it, every later one contributes its
  own units — aliases included. It generates even when the read model declares
  no examples: the factory is about the schema's shape, the fixtures are about
  its data.

  The pair accepts both shapes of input, each one contracted explicitly:
  a fixture struct (mapped to attributes, because Ecto's `cast/3` takes a
  `:map`, not a struct) or a plain attribute map — so hand-written seeds keep
  working beside fixture-driven ones. The plural fails fast: a fixture that
  cannot seed raises with the changeset errors, instead of a test that proceeds
  against a half-seeded world.
  """

  use SpGen.Blueprint

  alias SpGen.Blueprint

  @path "services/api/test/support/<_subdomain>/<composite>/<composite>.ex"
  @module "Sportipedia.TestSupport.<Subdomain>.<Composite>"
  @read_model_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>ReadModel"

  def name, do: :factory
  def source_kinds, do: [:"read-model"]

  # the ledger references read models and the Repo — never a citizen this run
  # would have to wake up by sweeping the neighborhood
  def closure_scope, do: :none

  def dependencies(%Context{} = ctx), do: [{Blueprint.ReadModel, ctx.element}]

  @doc "The composite factory file's path (a `requires` gate for tests)."
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

  # ------------------------------------------------------------------ names

  defp rm_module(ctx), do: Context.render(@read_model_module, ctx)
  defp local(ctx), do: rm_module(ctx) |> String.split(".") |> List.last()

  defp seed_name(ctx), do: "new_" <> String.replace(ctx.constituent, "-", "_")
  defp seed_all_name(ctx), do: Context.render("<domain_object>s", ctx) |> then(&"new_#{&1}")

  defp repo_module(ctx), do: "Sportipedia.#{Context.pascal(ctx.subdomain)}.Repo"
  defp repo_alias(ctx), do: "alias #{repo_module(ctx)}"

  defp gate_reason(ctx) do
    "the #{ctx.constituent} read model does not exist (spgen read_model)"
  end

  # ------------------------------------------------------------------ units

  defp units(%Context{} = ctx) do
    [
      %Unit{
        id: :moduledoc,
        check: &Source.has_moduledoc?/1,
        render: fn c ->
          """
          @moduledoc \"\"\"
          Test-support factories for the #{c.composite} composite — they turn
          fixtures (or plain attribute maps) into persisted read models.
          Generated `new_*` units append per read model; the file is a ledger.
          \"\"\"
          """
        end,
        place: Merge.head(:moduledoc)
      },
      repo_alias_unit(ctx),
      read_model_alias_unit(ctx),
      seed_pair_unit(ctx),
      seed_all_unit(ctx)
    ]
  end

  defp repo_alias_unit(%Context{} = ctx) do
    %Unit{
      id: {:alias, repo_module(ctx)},
      check: fn src -> Source.has_alias?(src, repo_module(ctx)) end,
      render: fn c -> repo_alias(c) end,
      place: Merge.alias_of(repo_module(ctx))
    }
  end

  defp read_model_alias_unit(%Context{} = ctx) do
    full = rm_module(ctx)

    %Unit{
      id: {:alias, full},
      check: fn src -> Source.has_alias?(src, full) end,
      render: fn c -> "alias #{rm_module(c)}" end,
      requires: fn c -> [{Blueprint.ReadModel.module_file(c), gate_reason(c)}] end,
      place: Merge.alias_of(full)
    }
  end

  defp seed_pair_unit(%Context{} = ctx) do
    name = String.to_atom(seed_name(ctx))

    %Unit{
      id: {:defs, name},
      # present once the fixture-struct clause is there — the map clause is
      # the original shape every hand-written factory already carries
      check: fn src -> Source.def_head_has?(src, name, 1, "#{local(ctx)}{}") end,
      stale: fn src, c ->
        cond do
          not Source.has_def?(src, name, 1) ->
            []

          Source.def_head_has?(src, name, 1, "#{local(c)}{}") ->
            []

          true ->
            [
              "#{name}/1 has no fixture-struct clause — add `def #{name}(%#{local(c)}{} = fixture), do: #{name}(Map.from_struct(fixture))`"
            ]
        end
      end,
      render: fn c ->
        """
        @spec #{seed_name(c)}(#{local(c)}.t() | map()) ::
                {:ok, #{local(c)}.t()} | {:error, Ecto.Changeset.t()}
        def #{seed_name(c)}(%#{local(c)}{} = fixture) do
          #{seed_name(c)}(Map.from_struct(fixture))
        end

        def #{seed_name(c)}(attributes) when is_map(attributes) do
          %#{local(c)}{}
          |> #{local(c)}.insert_changeset(attributes)
          |> Repo.insert()
        end
        """
      end,
      requires: fn c -> [{Blueprint.ReadModel.module_file(c), gate_reason(c)}] end,
      place: Merge.body_end()
    }
  end

  defp seed_all_unit(%Context{} = ctx) do
    name = String.to_atom(seed_all_name(ctx))
    singular = String.to_atom(seed_name(ctx))
    one = ctx.constituent

    %Unit{
      id: {:def, name, 1},
      check: fn src -> Source.has_def?(src, name, 1) end,
      render: fn c ->
        """
        @spec #{seed_all_name(c)}([#{local(c)}.t() | map()]) :: [#{local(c)}.t()]
        def #{seed_all_name(c)}(attribute_collection) do
          Enum.map(attribute_collection, fn attributes ->
            case #{seed_name(c)}(attributes) do
              {:ok, #{one}} -> #{one}
              {:error, changeset} ->
                raise "seeding #{one} fixture failed: \#{inspect(changeset.errors)}"
            end
          end)
        end
        """
      end,
      requires: fn c -> [{Blueprint.ReadModel.module_file(c), gate_reason(c)}] end,
      place: Merge.after_def(singular, 1)
    }
  end
end
