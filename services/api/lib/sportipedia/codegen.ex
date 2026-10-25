defmodule Sportipedia.Codegen do
  @moduledoc """
  The blueprint code generators (`mix sp.gen.*`).

  Generators are addressed by **family** (one `mix sp.gen.<family>` task).
  A family lists its blueprint modules — one per generated file role: the
  citizen's own module, its test output, and any registration files — and
  runs them against one resolved `Context`.

  Each module yields `FilePlan`s, applied idempotently against the tree: a
  missing file gets its scaffold, an existing file only receives the units it
  lacks. Merging is append-only AST editing (`Sportipedia.Codegen.Merge`):
  presence is checked on the parsed file (`Sportipedia.Codegen.Source`),
  missing units are inserted as new nodes in the module tree, and the whole
  tree is printed and formatted back. Present content is never rewritten, and
  files are only touched when units are actually missing.

  ## Usage

      mix sp.gen.command <element> --template create|update|delete \\
        [--subdomain catalog] [--composite equipment] [--constituent apparatus] \\
        [--model docs/domain-model] [--check] [--root .]

  `<element>` is an `esdm:` reference, a `*.esdm.yaml` file path, a
  `kind.name`, or a bare (unambiguous) name. Subdomain, composite and
  constituent are inferred from the model and the architecture layout; args
  override, and unresolvable information is an error, never a guess.
  """

  alias Sportipedia.Codegen.{Blueprint, Context, Esdm, FilePlan, Formatter, Merge, Source, Unit}
  alias Sportipedia.Codegen.Esdm.Element

  @switches [
    template: :string,
    subdomain: :string,
    composite: :string,
    constituent: :string,
    model: :string,
    root: :string,
    check: :boolean
  ]

  @doc """
  Registry: generator family → its blueprint modules, one per generated file
  role. The head of the list is the family's primary module — it owns the
  element kinds and `--template` semantics the whole family runs under.
  """
  def families do
    alias Sportipedia.Codegen.Blueprint, as: B

    %{
      aggregate: [B.Aggregate, B.AggregateTest],
      bruno: [B.Bruno, B.BrunoFolder],
      command: [B.Command, B.CommandTest, B.CommandRouter],
      command_handler: [B.CommandHandler, B.CommandHandlerTest],
      controller: [B.Controller, B.ControllerTest, B.WebRouter],
      event: [B.Event, B.EventTest],
      internal_api: [B.InternalAPI],
      policy: [B.Policy, B.PolicyTest],
      projector: [B.Projector, B.ProjectorSupervisor, B.ProjectorTest],
      public_api: [B.PublicAPI, B.PublicAPITest],
      query: [B.Query, B.QueryTest],
      read_model: [B.ReadModel],
      schema: [B.Schema, B.SchemaTest],
      validator: [B.Validator],
      view: [B.View, B.ViewTest]
    }
  end

  @doc "The primary module of a family (head of its module list)."
  def primary(family) when is_atom(family), do: families()[family] |> List.first()

  @doc """
  Runs one generator family against `argv`.

  Returns `{:ok, results}` or `{:error, message}`; printing and exit codes are
  the task's business.
  """
  @spec run(atom(), [String.t()]) :: {:ok, [term()]} | {:error, String.t()}
  def run(family, argv) when is_atom(family) do
    case families()[family] do
      nil ->
        {:error, "unknown generator family: #{inspect(family)}"}

      modules ->
        primary = hd(modules)
        do_run(family, modules, primary, argv)
    end
  end

  defp do_run(family, modules, blueprint, argv) do
    {opts, args, invalid} = OptionParser.parse(argv, strict: @switches)

    cond do
      invalid != [] ->
        {:error, "unknown option(s): " <> Enum.map_join(invalid, ", ", fn {k, _} -> k end)}

      args == [] ->
        {:error, "usage: mix sp.gen.#{family} <element> [options]\n\n#{help()}"}

      length(args) > 1 ->
        {:error, "expected exactly one element, got: #{Enum.join(args, " ")}"}

      true ->
        apply_family(modules, blueprint, family, hd(args), opts)
    end
  end

  defp apply_family(modules, blueprint, _family, address, opts) do
    repo_root = Keyword.get(opts, :root, default_root())
    model_root = Path.join(repo_root, Keyword.get(opts, :model, "docs/domain-model"))
    formatter_cwd = Path.join(repo_root, "services/api")

    with {:ok, model} <- Esdm.load(model_root),
         {:ok, element} <- model |> Esdm.resolve(address) |> norm_location(),
         :ok <- accept_kind(blueprint, element),
         {:ok, operation} <- validate_operation(blueprint, opts, element),
         {:ok, ctx} <-
           Context.build(
             model,
             element,
             Keyword.put(context_opts(operation, opts), :repo_root, repo_root)
           ) do
      plans = modules |> Enum.flat_map(& &1.plans(ctx))
      check? = Keyword.get(opts, :check, false)
      formatter_opts = Formatter.opts(formatter_cwd)

      {:ok, apply_all(plans, ctx, repo_root, formatter_opts, check?)}
    else
      {:error, {:unknown_location, var}} ->
        {:error,
         "cannot infer #{var} for #{address} — pass --#{var} <name> (subdomain/composite come from the model layout, constituent from the element scope)"}

      other ->
        other
    end
  end

  defp norm_location({:ok, element}), do: {:ok, element}

  defp norm_location({:error, reason}) do
    {:error, "cannot resolve element: " <> Esdm.format_error(reason)}
  end

  defp accept_kind(blueprint, %Element{} = element) do
    if blueprint.accepts?(element) do
      :ok
    else
      {:error,
       "#{blueprint.name()} generates from #{inspect(Enum.map(blueprint.source_kinds(), &to_string/1))} " <>
         "elements, got #{element.kind} (#{element.address})"}
    end
  end

  defp validate_operation(blueprint, opts, element) do
    given = Keyword.get(opts, :template)
    requested = if given, do: String.to_atom(given), else: nil

    case Blueprint.validate_operation(blueprint, requested, given, element.kind) do
      {:ok, :fixed} -> {:ok, nil}
      other -> other
    end
  end

  defp context_opts(operation, opts) do
    base = if operation && operation != :fixed, do: [operation: operation], else: []

    Enum.reduce([:subdomain, :composite, :constituent], base, fn key, acc ->
      case Keyword.get(opts, key) do
        nil -> acc
        value -> Keyword.put(acc, key, value)
      end
    end)
  end

  defp default_root do
    cwd = File.cwd!()

    cond do
      File.dir?(Path.join(cwd, "lib/sportipedia")) -> Path.expand("../..", cwd)
      File.dir?(Path.join(cwd, "services/api")) -> cwd
      true -> cwd
    end
  end

  @doc "CLI help text shared by all sp.gen tasks."
  def help do
    """
    <element> is one of:
      * an esdm: reference — esdm:domain=sport/bounded-context=sport/aggregate=apparatus/command=catalog-apparatus
      * a *.esdm.yaml model file — docs/domain-model/catalog/equipment/command.catalog-apparatus.esdm.yaml
      * kind.name — command.catalog-apparatus
      * a unique bare name — catalog-apparatus

    Options:
      --template       what the operation does: create | update | delete | read | collection
      --subdomain      override the inferred subdomain
      --composite      override the inferred composite
      --constituent    override the inferred constituent (domain object)
      --model          model root, default docs/domain-model (relative to --root)
      --root           repo root, default inferred from the current directory
      --check          report drift, write nothing
    """
  end

  # -- planning & applying ------------------------------------------------------

  @doc """
  Applies file plans, returning per-file results:

  * `{:created, path}` — new file written
  * `{:merged, path, [unit_id]}` — missing units appended into an existing file
  * `{:unchanged, path}` — everything the plan wants is already there
    (nothing was written)
  * `{:checked, path, [unit_id | {:unplaceable, unit_id}]}` — in `--check`
    mode, what *would* change
  * `{:blocked, path, [unit_id]}` — a unit is missing but has no home in
    this file (reported, nothing written)
  * `{:error, path, reason}` — unparsable file, foreign module, or a missing
    registration file
  """
  def apply_all(plans, ctx, repo_root, formatter_opts, check?) do
    Enum.map(plans, &apply_plan(&1, ctx, repo_root, formatter_opts, check?))
  end

  @doc false
  def apply_plan(%FilePlan{path: rel_path} = plan, ctx, repo_root, formatter_opts, check?) do
    abs_path = Path.join(repo_root, rel_path)

    case File.read(abs_path) do
      {:error, :enoent} -> create(plan, ctx, abs_path, rel_path, formatter_opts, check?)
      {:ok, text} -> merge(plan, ctx, text, abs_path, rel_path, formatter_opts, check?)
    end
  end

  defp create(%FilePlan{scaffold: nil}, _ctx, _abs, rel_path, _formatter_opts, _check?) do
    {:error, rel_path, :registration_file_missing}
  end

  defp create(%FilePlan{scaffold: scaffold} = plan, ctx, abs, rel_path, formatter_opts, check?) do
    content =
      if plan.format do
        Merge.render_new(scaffold.(ctx), formatter_opts)
      else
        # non-Elixir artifacts (YAML): verbatim, single trailing newline
        scaffold.(ctx) |> String.trim_trailing("\n") |> Kernel.<>("\n")
      end

    if check? do
      {:checked, rel_path, [:whole_file]}
    else
      File.mkdir_p!(Path.dirname(abs))
      File.write!(abs, content)
      {:created, rel_path}
    end
  end

  defp merge(%FilePlan{} = plan, ctx, text, abs, rel_path, formatter_opts, check?) do
    unless plan.format do
      # text artifacts are create-only: existing docs are never rewritten
      {:unchanged, rel_path}
    else
      source = Source.parse(text)

      cond do
        is_nil(source.ast) ->
          {:error, rel_path, :unparsable}

        foreign_module?(plan, source) ->
          {:error, rel_path, {:unexpected_module, Source.module_name(source)}}

        true ->
          merge_units(plan, ctx, source, abs, rel_path, formatter_opts, check?)
      end
    end
  end

  defp merge_units(%FilePlan{units: units}, ctx, source, abs, rel_path, formatter_opts, check?) do
    missing = Enum.reject(units, &Unit.present?(&1, source))

    if missing == [] do
      {:unchanged, rel_path}
    else
      {ast, placed, blocked} =
        Enum.reduce(missing, {source.ast, [], []}, fn unit, {acc, placed, blocked} ->
          case unit.place.(acc, unit, ctx) do
            {:ok, new_ast} -> {new_ast, placed ++ [unit.id], blocked}
            :blocked -> {acc, placed, blocked ++ [unit.id]}
          end
        end)

      cond do
        placed == [] ->
          {:blocked, rel_path, blocked}

        check? ->
          {:checked, rel_path, placed ++ Enum.map(blocked, &{:unplaceable, &1})}

        true ->
          File.write!(abs, Merge.render(ast, formatter_opts))
          {:merged, rel_path, placed}
      end
    end
  end

  defp foreign_module?(%FilePlan{module: nil}, _source), do: false

  defp foreign_module?(%FilePlan{module: module}, source) do
    case Source.module_name(source) do
      nil -> false
      ^module -> false
      _other -> true
    end
  end
end
