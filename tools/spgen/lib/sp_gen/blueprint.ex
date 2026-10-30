defmodule SpGen.FilePlan do
  @moduledoc """
  The plan for one generated file: where it lives, what module owns it, and
  how to produce it — whole (`scaffold`) when missing, or unit by unit
  (`units`) when it exists.

  `module` is the expected dotted module name. When a file exists but declares
  a different module, merging aborts — the generator refuses to edit an
  unexpected file.

  `format: false` marks non-Elixir artifacts (YAML): created verbatim,
  never merged into, never formatted.
  """

  @enforce_keys [:path]
  defstruct [:path, :module, :scaffold, units: [], note: nil, format: true]

  @type t :: %__MODULE__{
          path: String.t(),
          module: String.t() | nil,
          # (ctx -> source_text)
          scaffold: (SpGen.Context.t() -> String.t()) | nil,
          # [SpGen.Unit.t()]
          units: [SpGen.Unit.t()],
          note: String.t() | nil,
          format: boolean()
        }
end

defmodule SpGen.Blueprint do
  @moduledoc """
  Contract of a code generator blueprint module — one module per generated
  file (or per file *role*, when a role produces several files of one shape:
  the operation test files of every publishing command, the OpenAPI schemas
  of an element).

  The executable transfer of a markdown blueprint from
  `docs/architecture/blueprints/`:

  * `plans/1` — the `FilePlan`s this module produces for a resolved `Context`
  * `name/0` — the module's id (snake-cased from the alias by default)

  Generators are addressed by **family** (`mix sp.gen.<family>`): the family
  registry in `SpGen.families/0` lists the blueprint modules it
  runs, with the primary module (the head of the list) defining the element
  kinds it consumes (`source_kinds/0`) and the `--template` operations it
  renders (`operations/0`, `optional_template?/0`). Test-file and
  registration modules inherit sane defaults and are not consulted for
  validation.

  Templates keep the placeholder notation of
  `docs/architecture/naming-substitution.md` and the prose slots of the
  blueprints; `Context.render/4` fills them.

  Each `use` validates the behaviour and provides default hooks.
  """

  alias SpGen.{Context, FilePlan}
  alias SpGen.Esdm.Element

  @callback name() :: atom()
  @callback operations() :: [Context.operation()] | :fixed
  @callback optional_template?() :: boolean()
  @callback source_kinds() :: [Element.kind()]
  @callback accepts?(Element.t()) :: boolean()
  @callback plans(Context.t()) :: [FilePlan.t()]

  defmacro __using__(_opts) do
    quote do
      @behaviour SpGen.Blueprint

      alias SpGen.{Context, FilePlan, Merge, Source, Unit}
      alias SpGen.Esdm.Element

      def name,
        do: __MODULE__ |> Module.split() |> List.last() |> Macro.underscore() |> String.to_atom()

      def source_kinds, do: []

      def accepts?(element), do: element.kind in source_kinds()

      def operations, do: :fixed

      def optional_template?, do: false

      defoverridable name: 0, accepts?: 1, operations: 0, source_kinds: 0, optional_template?: 0
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
