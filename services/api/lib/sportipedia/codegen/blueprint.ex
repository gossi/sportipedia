defmodule Sportipedia.Codegen.FilePlan do
  @moduledoc """
  The plan for one generated file: where it lives, what module owns it, and
  how to produce it — either whole (`scaffold`) when missing, or unit by unit
  (`units`) when it exists.

  `role` disambiguates output reports:

  * `:module` — the citizen's own file (command.ex, projector.ex, …)
  * `:test` — a test file (own file or shared operation test the units merge into)
  * `:registration` — a shared file the unit is registered into (commanded
    router, web router, supervisor)

  `module` is the expected dotted module name. When a file exists but declares
  a different module, merging aborts — the generator refuses to splice into an
  unexpected file.
  """

  @enforce_keys [:path, :role]
  defstruct [:path, :role, :module, :scaffold, units: [], note: nil, format: true]

  @type role :: :module | :test | :registration | :doc

  @type t :: %__MODULE__{
          path: String.t(),
          role: role(),
          module: String.t() | nil,
          # (ctx -> source_text)
          scaffold: (Sportipedia.Codegen.Context.t() -> String.t()) | nil,
          # [Sportipedia.Codegen.Unit.t()]
          units: [Sportipedia.Codegen.Unit.t()],
          note: String.t() | nil,
          # false for non-Elixir artifacts (YAML): written verbatim, not formatted
          format: boolean()
        }
end

defmodule Sportipedia.Codegen.Blueprint do
  @moduledoc """
  Contract of a code generator blueprint — the executable transfer of a
  markdown blueprint from `docs/architecture/blueprints/`.

  A blueprint knows

  * `name/0` — its id, and `task/0` — the `mix sp.gen.<name>` invocation
  * `operations/0` — the `--template` values it renders, or `:fixed` when the
    citizen's shape does not depend on what the operation does
  * `optional_template?/0` — template-driven but derivable from the domain
    model when `--template` is absent (the `Context` default)
  * `plans/1` — the `FilePlan`s to produce for a resolved `Context`: the
    module file, its test output, and any registration files
  * `accepts?/1` — which ESDM element kinds it can generate from

  Templates keep the placeholder notation of
  `docs/architecture/naming-substitution.md` and the prose slots of the
  blueprints; `Context.render/4` fills them.

  Each `use` validates the behaviour and provides default hooks.
  """

  alias Sportipedia.Codegen.{Context, FilePlan}
  alias Sportipedia.Codegen.Esdm.Element

  @callback name() :: atom()
  @callback task() :: String.t()
  @callback operations() :: [Context.operation()] | :fixed
  @callback optional_template?() :: boolean()
  @callback source_kinds() :: [Element.kind()]
  @callback accepts?(Element.t()) :: boolean()
  @callback plans(Context.t()) :: [FilePlan.t()]

  defmacro __using__(_opts) do
    quote do
      @behaviour Sportipedia.Codegen.Blueprint

      alias Sportipedia.Codegen.{Context, FilePlan, Source, Unit}
      alias Sportipedia.Codegen.Esdm.Element

      def task, do: "sp.gen." <> Atom.to_string(name())

      def source_kinds, do: []

      def accepts?(element), do: element.kind in source_kinds()

      def operations, do: :fixed

      def optional_template?, do: false

      defoverridable task: 0, accepts?: 1, operations: 0, source_kinds: 0, optional_template?: 0
    end
  end

  @doc """
  Validates `--template` against a blueprint and the element kind.

  * `:fixed` blueprints accept no template
  * a missing template is an error unless the blueprint is
    `optional_template?/0` — then `{:ok, nil}` and the `Context` derives the
    operation from the domain model
  * a given template must be supported by the blueprint and fit the kind:
    commands/events perform `create | update | delete`, queries `read | collection`
  """
  @spec validate_operation(module(), Context.operation() | nil, String.t() | nil, Element.kind()) ::
          {:ok, :fixed | Context.operation() | nil} | {:error, String.t()}
  def validate_operation(blueprint, requested, given_arg, kind) do
    ops = blueprint.operations()
    kind_ops = operations_for(kind)

    cond do
      ops == :fixed and is_nil(given_arg) ->
        {:ok, :fixed}

      ops == :fixed ->
        {:error, "#{blueprint.name()} is fixed — it takes no --template (remove it)"}

      is_nil(requested) and blueprint.optional_template?() ->
        {:ok, nil}

      is_nil(requested) ->
        {:error, "#{blueprint.name()} needs --template, one of: #{Enum.join(ops, ", ")}"}

      requested not in ops ->
        {:error,
         "template #{inspect(requested)} not supported by #{blueprint.name()} — one of: #{Enum.join(ops, ", ")}"}

      kind_ops != :any and requested not in kind_ops ->
        {:error,
         "template #{inspect(requested)} does not fit a #{kind} element — one of: #{Enum.join(kind_ops, ", ")}"}

      true ->
        {:ok, requested}
    end
  end

  @doc "The templates an element kind can perform (`:any` = unconstrained)."
  @spec operations_for(Element.kind()) :: [Context.operation()] | :any
  def operations_for(kind) do
    case kind do
      k when k in [:command, :event] -> [:create, :update, :delete]
      :query -> [:read, :collection]
      _ -> :any
    end
  end
end
