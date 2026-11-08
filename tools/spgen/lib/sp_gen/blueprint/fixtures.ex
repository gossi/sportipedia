defmodule SpGen.Blueprint.Fixtures do
  @moduledoc """
  Executable transfer of `docs/architecture/blueprints/backend/domain/test-support.md`.

  Generates the **fixture file** of a read model: one zero-arity function per
  declared `schema.examples` entry, returning the read model's struct typed
  `@spec`, plus the aggregate function that lists them all. Naming follows
  `docs/architecture/naming-substitution.md`:

      path:   services/api/test/support/<_subdomain>/<composite>/fixtures/<domain_object>s.ex
      module: Sportipedia.TestSupport.<Subdomain>.<Composite>.<DomainObject>Fixtures

  **Projection, not merge**: this file is owned by the model. Each run renders
  it whole and rewrites it when the render differs — an example renamed in the
  YAML renames the function here, and stale call sites surface as
  compile-time `undefined function` errors, which is the integrity contract.
  A read model without examples generates nothing.

  The examples must be valid per `SpGen.Fixtures` — keys that name their own
  home, schema-declared fields only, legal function names. Violations fail the
  run with every message, written nowhere.
  """

  use SpGen.Blueprint

  alias SpGen.{Blueprint, Fixtures}

  @path "services/api/test/support/<_subdomain>/<composite>/fixtures/<domain_object>s.ex"
  @module "Sportipedia.TestSupport.<Subdomain>.<Composite>.<DomainObject>Fixtures"
  @read_model_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>ReadModel"

  def name, do: :fixtures
  def source_kinds, do: [:"read-model"]

  # fixtures reference nothing but their read model — and that citizen arrives
  # as a dependency of this very run, so a creating run sweeps nothing
  def closure_scope, do: :none

  def dependencies(%Context{} = ctx), do: [{Blueprint.ReadModel, ctx.element}]

  @doc "The fixture file's path (used as a `requires` gate by test blueprints)."
  @spec module_file(Context.t()) :: String.t()
  def module_file(%Context{} = ctx), do: Context.render(@path, ctx)

  @doc """
  Model-content gate: the examples must be renderable before anything is
  written. `SpGen` calls this through `Blueprint.validate_hook/2`.
  """
  def validate(%Context{} = ctx) do
    case Fixtures.validate(ctx.element, ctx.composite, plural(ctx)) do
      {:ok, _specs} -> :ok
      {:error, messages} -> {:error, messages}
    end
  end

  def plans(%Context{} = ctx) do
    case Fixtures.examples(ctx.element) do
      [] ->
        []

      _specs ->
        [
          %FilePlan{
            path: Context.render(@path, ctx),
            module: Context.render(@module, ctx),
            projection: true,
            scaffold: &render_source(&1),
            requires: &gates/1
          }
        ]
    end
  end

  defp gates(%Context{} = ctx) do
    [{Blueprint.ReadModel.module_file(ctx), fixture_reason(ctx)}]
  end

  defp fixture_reason(ctx) do
    "the #{ctx.constituent} read model does not exist (spgen read_model)"
  end

  defp plural(%Context{} = ctx), do: Context.render("<domain_object>s", ctx)

  # ------------------------------------------------------------------ render

  defp render_source(%Context{} = ctx) do
    {:ok, specs} = Fixtures.validate(ctx.element, ctx.composite, plural(ctx))
    rm = Context.render(@read_model_module, ctx)
    local = rm |> String.split(".") |> List.last()

    header(ctx, rm) <>
      Enum.map_join(specs, &fixture_function(&1, local)) <>
      aggregate_function(specs, local, ctx) <>
      "\nend\n"
  end

  defp header(%Context{} = ctx, rm) do
    """
    defmodule #{Context.render(@module, ctx)} do
      @moduledoc \"\"\"
      Test fixtures for the #{ctx.constituent} read model — generated from
      `#{element_file(ctx)}` by `mix sp.gen.test_support #{ctx.element.kind}.#{ctx.element.name}`.

      The model's `schema.examples` are the source of truth: this file is a
      projection and is rewritten whole on every run. Declare fixtures in the
      domain model, not here.

      Ids materialize as `UUID.uuid5(:dns, "<composite>:<read-model>:<mnemonic>")`,
      so one mnemonic names one thing in every environment forever.
      \"\"\"

      alias #{rm}
    """
  end

  defp fixture_function(spec, local) do
    attrs =
      spec.attrs
      |> Enum.map(fn {name, source} -> "        #{name}: #{source}" end)
      |> Enum.join(",\n")

    """

      @doc "The `#{spec.key}` fixture."
      @spec #{spec.fname}() :: #{local}.t()
      def #{spec.fname} do
        %#{local}{
          #{attrs}
        }
      end
    """
  end

  defp aggregate_function(specs, local, %Context{} = ctx) do
    names = Enum.map_join(specs, ", ", &"#{&1.fname}()")

    """

      @doc "All #{ctx.constituent} fixtures, in model order."
      @spec #{plural(ctx)}() :: [#{local}.t()]
      def #{plural(ctx)}, do: [#{names}]
    """
  end

  # the model file is stated repo-relative: a VFS- or absolute-loaded model
  # still describes its source the way an operator sees it in the tree
  defp element_file(%Context{element: element, repo_root: root}) do
    case root do
      nil -> element.source
      root -> Path.relative_to(element.source, root)
    end
  end
end
