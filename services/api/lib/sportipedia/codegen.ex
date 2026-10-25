defmodule Sportipedia.Codegen do
  @moduledoc """
  The blueprint code generators (`mix sp.gen.*`).

  Loads a blueprint's `FilePlan`s for one ESDM element and applies them to the
  tree idempotently: a missing file gets its scaffold, an existing file only
  receives the units it lacks (presence-checked through
  `Sportipedia.Codegen.Source`), and every result is canonicalized with the
  project formatter before it is written — files are only touched when bytes
  actually change.

  ## Usage

      mix sp.gen.command <element> --template create|update|delete \\
        [--subdomain catalog] [--composite equipment] [--constituent apparatus] \\
        [--model docs/domain-model] [--check] [--root .]

  `<element>` is an `esdm:` reference, a `*.esdm.yaml` file path, a
  `kind.name`, or a bare (unambiguous) name. Subdomain, composite and
  constituent are inferred from the model and the architecture layout; args
  override, and unresolvable information is an error, never a guess.
  """

  alias Sportipedia.Codegen.{Blueprint, Context, Esdm, FilePlan, Patch, Source, Unit}
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

  @doc "Registry: blueprint name → module."
  def blueprints do
    %{
      aggregate: Sportipedia.Codegen.Blueprints.Aggregate,
      bruno: Sportipedia.Codegen.Blueprints.Bruno,
      command: Sportipedia.Codegen.Blueprints.Command,
      command_handler: Sportipedia.Codegen.Blueprints.CommandHandler,
      controller: Sportipedia.Codegen.Blueprints.Controller,
      event: Sportipedia.Codegen.Blueprints.Event,
      internal_api: Sportipedia.Codegen.Blueprints.InternalAPI,
      policy: Sportipedia.Codegen.Blueprints.Policy,
      projector: Sportipedia.Codegen.Blueprints.Projector,
      public_api: Sportipedia.Codegen.Blueprints.PublicAPI,
      query: Sportipedia.Codegen.Blueprints.Query,
      read_model: Sportipedia.Codegen.Blueprints.ReadModel,
      schema: Sportipedia.Codegen.Blueprints.Schema,
      validator: Sportipedia.Codegen.Blueprints.Validator,
      view: Sportipedia.Codegen.Blueprints.View
    }
  end

  @doc """
  Runs one blueprint's generator against `argv`.

  Returns `{:ok, results}` or `{:error, message}`; printing and exit codes are
  the task's business.
  """
  @spec run(module(), [String.t()]) :: {:ok, [term()]} | {:error, String.t()}
  def run(blueprint, argv) do
    {opts, args, invalid} = OptionParser.parse(argv, strict: @switches)

    cond do
      invalid != [] ->
        {:error, "unknown option(s): " <> Enum.map_join(invalid, ", ", fn {k, _} -> k end)}

      args == [] ->
        {:error, "usage: mix #{blueprint.task()} <element> [options]\n\n#{help()}"}

      length(args) > 1 ->
        {:error, "expected exactly one element, got: #{Enum.join(args, " ")}"}

      true ->
        do_run(blueprint, hd(args), opts)
    end
  end

  defp do_run(blueprint, address, opts) do
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
      plans = blueprint.plans(ctx)
      check? = Keyword.get(opts, :check, false)

      {:ok, apply_all(plans, ctx, repo_root, formatter_cwd, check?)}
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
  Applies plans, returning per-file results:

  * `{:created, path}` — new file written
  * `{:merged, path, [unit_id]}` — missing units spliced into an existing file
  * `{:unchanged, path}` — everything the plan wants is already there
  * `{:checked, path, [unit_id | {:unanchorable, unit_id}]}` — in `--check`
    mode, what *would* change
  * `{:blocked, path, [unit_id]}` — a unit is missing but has no anchor in
    this file (reported, nothing written)
  * `{:error, path, reason}` — e.g. the file exists but holds a foreign module
  """
  def apply_all(plans, ctx, repo_root, formatter_cwd, check?) do
    Enum.map(plans, &apply_plan(&1, ctx, repo_root, formatter_cwd, check?))
  end

  @doc false
  def apply_plan(%FilePlan{path: rel_path} = plan, ctx, repo_root, formatter_cwd, check?) do
    abs_path = Path.join(repo_root, rel_path)

    case File.read(abs_path) do
      {:error, :enoent} -> create(plan, ctx, abs_path, rel_path, formatter_cwd, check?)
      {:ok, text} -> merge(plan, ctx, text, abs_path, rel_path, formatter_cwd, check?)
    end
  end

  defp create(%FilePlan{scaffold: nil}, _ctx, _abs, rel_path, _cwd, _check?) do
    {:error, rel_path, :registration_file_missing}
  end

  defp create(%FilePlan{scaffold: scaffold} = plan, ctx, abs, rel_path, cwd, check?) do
    content =
      if plan.format do
        Patch.render_new(scaffold.(ctx), cwd: cwd)
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

  defp merge(%FilePlan{} = plan, ctx, text, abs, rel_path, cwd, check?) do
    source = Source.parse(text)

    cond do
      foreign_module?(plan, source) ->
        {:error, rel_path, {:unexpected_module, Source.module_name(source)}}

      true ->
        {insertions, unanchorable} = collect_units(plan, source, ctx)

        cond do
          insertions == [] and unanchorable == [] ->
            {:unchanged, rel_path}

          insertions == [] ->
            {:blocked, rel_path, Enum.map(unanchorable, & &1.id)}

          check? ->
            {:checked, rel_path,
             Enum.map(insertions, & &1.id) ++ Enum.map(unanchorable, &{:unanchorable, &1.id})}

          true ->
            new_text = Patch.apply(text, insertions, cwd: cwd)
            File.write!(abs, new_text)
            {:merged, rel_path, Enum.map(insertions, & &1.id)}
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

  defp collect_units(%FilePlan{units: units}, source, ctx) do
    Enum.reduce(units, {[], []}, fn unit, {ins, blocked} ->
      insertion = Unit.insertion(unit, source, ctx)

      cond do
        insertion != nil -> {[insertion | ins], blocked}
        Unit.present?(unit, source) -> {ins, blocked}
        true -> {ins, [unit | blocked]}
      end
    end)
    |> then(fn {ins, blocked} -> {Enum.reverse(ins), Enum.reverse(blocked)} end)
  end
end
