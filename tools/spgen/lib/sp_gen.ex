defmodule SpGen do
  @moduledoc """
  The blueprint code generators (reached through `mix sp.gen.*`, which
  delegate to the `spgen` escript built from this project).

  A **generator** is one `mix sp.gen.<name>` task. It runs a list of
  **blueprints** — one per generated file role: the citizen's own module, its
  test file, and any registration files — all against one resolved
  `Context`. A blueprint also declares the blueprints its generated code calls
  (`SpGen.Blueprint.dependencies/1`): those are planned first, in the same run,
  so a command that validates with a validator generates that validator, the
  internal API it delegates to, and the lookup query and read model behind it.

  Each module yields `FilePlan`s, applied idempotently against the tree: a
  missing file gets its units applied to a fresh module shell (or, for
  un-gated blueprints still on scaffolds, its scaffold text); an existing
  file only receives the units it lacks. Merging is append-only AST editing
  (`SpGen.Merge`): presence is checked on the parsed file (`SpGen.Source`),
  missing units are inserted as new nodes in the module tree, and the whole
  tree is printed and formatted back. Present content is never rewritten,
  and files are only touched when units are actually missing.

  Units whose code references another citizen are **gated**
  (`SpGen.Unit.requires/0`): while the referenced file is missing the unit
  *defers* — reported, exit 0, nothing written — which keeps generated trees
  compilable in any generation order. When a run *creates* a file, a
  **closure pass** re-applies the gated units of the constituent's
  neighborhood (merge-only, never creating), so referencing code lands
  exactly when its subject exists.
  """

  alias SpGen.{Blueprint, Context, Esdm, FilePlan, Formatter, FS, Merge, Source, Unit}
  alias SpGen.Esdm.Element

  @switches [
    template: :string,
    subdomain: :string,
    composite: :string,
    constituent: :string,
    model: :string,
    root: :string,
    check: :boolean
  ]

  @max_closure_rounds 3
  @actors [:domain, :web]

  # The order generators are meant to run in: what a generator writes is gated
  # on the citizens before it, so this pass needs no deferral round-trips.
  # A generator also produces the blueprints its code calls (its
  # `dependencies/1`), so following this order never defers a reference.
  # It is also the order `mix sp.gen` lists them in.
  @generator_order [
    :read_model,
    :event,
    :aggregate,
    :query,
    :internal_api,
    :command,
    :command_handler,
    :projector,
    :policy,
    :public_api,
    :view,
    :schema,
    :controller,
    :bruno
  ]

  @typedoc "The hexagonal actor a generator serves: `:domain` inside the hexagon, `:web` at the HTTP driving adapter"
  @type actor :: :domain | :web

  @doc """
  Registry: generator → the blueprint modules it runs, one per generated file
  role. The head of the list is the generator's primary blueprint — it owns the
  element kinds, `--template` semantics and `actor/0` the whole generator runs
  under.

  Blueprints a run only needs as an implementation detail of another one are
  not in this registry: `Validator`, `InternalAPI`'s lookup queries and the
  registration hosts they call are reached through `SpGen.Blueprint.dependencies/1`
  of the blueprint that references them, so they are never a command the
  operator types.
  """
  def generators do
    alias SpGen.Blueprint, as: B

    %{
      aggregate: [B.Aggregate, B.AggregateTest],
      bruno: [B.Bruno, B.BrunoFolder],
      command: [B.Command, B.CommandTest, B.CommandRouter, B.CommandApplication],
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
      view: [B.View, B.ViewTest]
    }
  end

  @doc "The primary blueprint of a generator (head of its module list)."
  def primary_blueprint(generator) when is_atom(generator) do
    generators()[generator] |> List.first()
  end

  @doc "The actor a generator serves, as declared by its primary blueprint."
  @spec actor(atom()) :: actor()
  def actor(generator) when is_atom(generator), do: primary_blueprint(generator).actor()

  @doc """
  The generators grouped by actor, actors in `#{inspect(@actors)}` order and each
  group in `@generator_order` — the shape `mix sp.gen` lists.
  """
  @spec generators_by_actor() :: [{actor(), [atom()]}]
  def generators_by_actor do
    by_generator = Enum.map(generators(), fn {gen, _mods} -> {gen, actor(gen)} end)

    @actors
    |> Enum.map(fn actor ->
      group = for({gen, ^actor} <- by_generator, do: gen)
      {actor, sort_by_usage(group)}
    end)
    |> Enum.reject(fn {_actor, generators} -> generators == [] end)
  end

  defp sort_by_usage(generators) do
    Enum.sort_by(generators, fn generator ->
      case Enum.find_index(@generator_order, &(&1 == generator)) do
        nil ->
          raise ArgumentError, "generator #{inspect(generator)} needs a place in @generator_order"

        index ->
          index
      end
    end)
  end

  @doc """
  Runs one generator against `argv`.

  Options: `:fs` — the `SpGen.FS` handle to run against (default: the real
  disk). Tests pass an in-memory repository.

  Returns `{:ok, results}` or `{:error, message}`; printing and exit codes are
  the CLI's business.
  """
  @spec run(atom(), [String.t()], keyword()) :: {:ok, [term()]} | {:error, String.t()}
  def run(generator, argv, opts \\ []) when is_atom(generator) do
    case generators()[generator] do
      nil ->
        {:error, "unknown generator: #{inspect(generator)}"}

      modules ->
        primary = hd(modules)
        do_run(generator, modules, primary, argv, opts)
    end
  end

  defp do_run(generator, modules, blueprint, argv, run_opts) do
    {opts, args, invalid} = OptionParser.parse(argv, strict: @switches)

    cond do
      invalid != [] ->
        {:error, "unknown option(s): " <> Enum.map_join(invalid, ", ", fn {k, _} -> k end)}

      args == [] ->
        {:error, "usage: mix sp.gen.#{generator} <element> [options]\n\n#{help()}"}

      length(args) > 1 ->
        {:error, "expected exactly one element, got: #{Enum.join(args, " ")}"}

      true ->
        apply_generator(modules, blueprint, generator, hd(args), opts, run_opts)
    end
  end

  defp apply_generator(modules, blueprint, _generator, address, opts, run_opts) do
    fs = Keyword.get(run_opts, :fs, FS.default())
    repo_root = opts |> Keyword.get(:root, default_root(fs)) |> Path.expand()
    model_root = Path.join(repo_root, Keyword.get(opts, :model, "docs/domain-model"))
    formatter_cwd = Path.join(repo_root, "services/api")

    with {:ok, model} <- Esdm.load(model_root, fs: fs),
         {:ok, element} <-
           model |> Esdm.resolve(address, kinds: blueprint.source_kinds()) |> norm_location(),
         :ok <- accept_kind(blueprint, element),
         {:ok, operation} <- validate_operation(blueprint, opts, element),
         {:ok, ctx} <-
           Context.build(
             model,
             element,
             context_opts(operation, opts)
             |> Keyword.put(:repo_root, repo_root)
             |> Keyword.put(:fs, fs)
           ) do
      plans = plans_for(modules, ctx, model, opts)
      check? = Keyword.get(opts, :check, false)
      formatter_opts = Formatter.opts(formatter_cwd, fs)

      run = new_run(repo_root, formatter_opts, check?, fs)

      {run, seed} = apply_plans(plans, run)
      created? = Enum.any?(seed, &match?({:created, _}, &1))

      backfill =
        if created? and not check? do
          {_run, rows} = closure_rounds(model, ctx, opts, run)

          # rounds repeat unmet gates while they wait; keep the most
          # recent (smallest) deferred report per file
          rows
          |> Enum.reverse()
          |> Enum.uniq_by(fn
            {:deferred, path, _} -> {:deferred, path}
            row -> {make_ref(), row}
          end)
          |> Enum.reverse()
        else
          []
        end

      {:ok, seed ++ backfill}
    else
      {:error, {:unknown_location, var}} ->
        {:error,
         "cannot infer #{var} for #{address} — pass --#{var} <name> (subdomain/composite come from the model layout, constituent from the element scope)"}

      other ->
        other
    end
  end

  defp new_run(repo_root, formatter_opts, check?, fs) do
    %{
      repo_root: repo_root,
      fs: fs,
      formatter_opts: formatter_opts,
      check?: check?,
      merge_only: false,
      creating: false,
      planned: MapSet.new()
    }
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

  defp default_root(fs), do: fs |> cwd() |> find_root(fs)

  defp cwd({SpGen.FS.Local, nil}), do: File.cwd!()
  defp cwd(_fs), do: "/"

  @doc """
  Repo root discovery: the nearest ancestor of `cwd` that holds both
  `services/api` and `docs/domain-model`. Falls back to `cwd` itself (an
  explicit `--root` always overrides).
  """
  @spec find_root(Path.t(), FS.t()) :: String.t()
  def find_root(cwd, fs \\ FS.default()) do
    parent = Path.expand("..", cwd)

    cond do
      repo_marker_dir?(cwd, fs) ->
        cwd

      parent == cwd ->
        cwd

      true ->
        find_root(parent, fs)
    end
  end

  defp repo_marker_dir?(dir, fs) do
    FS.dir?(fs, Path.join(dir, "services/api")) &&
      FS.dir?(fs, Path.join(dir, "docs/domain-model"))
  end

  @doc "CLI help text shared by all sp.gen tasks."
  def help do
    """
    <element> is one of:
      * an esdm: reference — esdm:domain=sport/bounded-context=sport/aggregate=apparatus/command=catalog-apparatus
      * a *.esdm.yaml model file — docs/domain-model/catalog/equipment/command.catalog-apparatus.esdm.yaml
      * kind.name — command.catalog-apparatus
      * a bare name — resolved among the kinds this generator produces
        (so `sp.gen.aggregate widget` finds the aggregate, not the
        same-named read model; `kind.name` or an esdm: reference always
        disambiguates)

    Options:
      --template       what the operation does: create | update | delete | read | collection
                       (default: derived from the domain model)
      --subdomain      override the inferred subdomain
      --composite      override the inferred composite
      --constituent    override the inferred constituent (domain object)
      --model          model root, default docs/domain-model (relative to --root)
      --root           repo root, default inferred from the current directory
      --check          report drift, write nothing
    """
  end

  # -- planning & applying ------------------------------------------------------

  # Per-file result rows of a run:
  #
  # * `{:created, path}` — new file written (shell + units, or scaffold)
  # * `{:merged, path, [unit_id]}` — missing units appended into an existing file
  # * `{:backfill, path, [unit_id]}` — appended by the closure pass after this
  #   run created a citizen that the unit references
  # * `{:unchanged, path}` — everything the plan wants is already there
  # * `{:deferred, path, [{unit_id, reason}]}` — units waiting for a citizen
  #   that has not been generated yet (reported only — generation order is
  #   not an error, and the tree stays compilable)
  # * `{:checked, path, [unit_id | {:unplaceable, unit_id} | {:deferred, unit_id, [reason]}]}`
  #   — in `--check` mode, what *would* change; `[:whole_file]` when the file
  #   itself is missing
  # * `{:blocked, path, [unit_id]}` — a unit is missing but has no home in
  #   this file (reported, nothing written)
  # * `{:error, path, reason}` — unparsable file, foreign module, or a missing
  #   registration file
  @type row ::
          {:created, String.t()}
          | {:merged, String.t(), [term()]}
          | {:backfill, String.t(), [term()]}
          | {:unchanged, String.t()}
          | {:deferred, String.t(), [{term(), String.t()}]}
          | {:checked, String.t(), [term()]}
          | {:blocked, String.t(), [term()]}
          | {:error, String.t(), term()}

  # The plans of a run: `modules` and, before each module, the plans of the
  # blueprints its code calls — a validator with the internal API it delegates
  # to, that accessor with the lookup query and the read model behind it. A
  # dependency is planned from its own element (a read model is not the
  # command's partial field set) and every module plans exactly once, so a
  # dependency shared by several callers appears once, ahead of all of them.
  defp plans_for(modules, %Context{} = ctx, %Esdm{} = model, opts) do
    {plans, _seen} =
      Enum.reduce(modules, {[], MapSet.new()}, &plans_of(&1, ctx, model, opts, &2))

    plans
  end

  defp plans_of(module, ctx, model, opts, {acc, seen}) do
    if MapSet.member?(seen, module) do
      {acc, seen}
    else
      seen = MapSet.put(seen, module)

      {deps, seen} =
        Enum.reduce(
          module.dependencies(ctx),
          {[], seen},
          &plan_dependency(&1, ctx, model, opts, &2)
        )

      {acc ++ deps ++ owned([module], ctx), seen}
    end
  end

  # a dependency with no element to plan from (no read model for the citizen)
  # is skipped: its caller's reference gates defer as they always did
  defp plan_dependency({module, %Element{} = element}, ctx, model, opts, {acc, seen}) do
    case dependency_ctx(model, ctx, element, opts) do
      {:ok, dep_ctx} -> plans_of(module, dep_ctx, model, opts, {acc, seen})
      {:error, _} -> {acc, seen}
    end
  end

  defp plan_dependency(_incomplete, _ctx, _model, _opts, acc), do: acc

  defp dependency_ctx(model, %Context{} = ctx, %Element{} = element, opts) do
    Context.build(
      model,
      element,
      Keyword.take(opts, [:subdomain, :composite, :constituent]) ++
        [repo_root: ctx.repo_root, fs: ctx.fs]
    )
  end

  defp owned(modules, ctx) do
    Enum.flat_map(modules, fn module -> Enum.map(module.plans(ctx), &{&1, ctx}) end)
  end

  @doc "Applies `{plan, context}` pairs, threading the run state (planned paths)."
  @spec apply_plans([{FilePlan.t(), Context.t()}], map()) :: {map(), [row()]}
  def apply_plans(plans, run) do
    {rows, run} =
      Enum.map_reduce(plans, run, fn {plan, ctx}, acc ->
        {rows, acc} = apply_plan(plan, ctx, acc)
        {rows, acc}
      end)

    {run, rows |> List.flatten() |> Enum.reject(&is_nil/1)}
  end

  @doc false
  @spec apply_plan(FilePlan.t(), Context.t(), map()) :: {[row()], map()}
  def apply_plan(%FilePlan{path: rel_path} = plan, ctx, run) do
    abs_path = Path.join(run.repo_root, rel_path)

    case FS.read(run.fs, abs_path) do
      {:error, :enoent} -> create(plan, ctx, abs_path, rel_path, run)
      {:ok, text} -> merge(plan, ctx, text, abs_path, rel_path, run)
    end
  end

  # ------------------------------------------------------------ creation

  defp create(%FilePlan{} = _plan, _ctx, _abs, _rel_path, %{merge_only: true} = run) do
    # the closure pass never creates — a citizen materializes via its own run
    {[], run}
  end

  defp create(%FilePlan{unit_created: true, module: module} = plan, ctx, abs, rel_path, run) do
    # units are applied to the in-memory shell; the file appears only once it
    # has content (`place_units/6`), so a shell alone is never written
    {rows, run} =
      place_units(plan, ctx, Source.parse("defmodule #{module} do\nend\n"), abs, rel_path, %{
        run
        | creating: true
      })

    {rows, %{run | creating: false}}
  end

  defp create(%FilePlan{scaffold: nil} = _plan, _ctx, _abs, rel_path, run) do
    {[{:error, rel_path, :registration_file_missing}], run}
  end

  defp create(%FilePlan{scaffold: scaffold} = plan, ctx, abs, rel_path, run) do
    content =
      if plan.format do
        Merge.render_new(scaffold.(ctx), run.formatter_opts)
      else
        # non-Elixir artifacts (YAML): verbatim, single trailing newline
        scaffold.(ctx) |> String.trim_trailing("\n") |> Kernel.<>("\n")
      end

    if run.check? do
      {[{:checked, rel_path, [:whole_file]}], run}
    else
      FS.write!(run.fs, abs, content)
      {[{:created, rel_path}], mark_planned(run, rel_path)}
    end
  end

  # ------------------------------------------------------------- merge/edit

  defp merge(%FilePlan{} = plan, ctx, text, abs, rel_path, run) do
    unless plan.format do
      # text artifacts are create-only: existing docs are never rewritten
      {[{:unchanged, rel_path}], run}
    else
      source = Source.parse(text)

      cond do
        is_nil(source.ast) ->
          {[{:error, rel_path, :unparsable}], run}

        foreign_module?(plan, source) ->
          {[{:error, rel_path, {:unexpected_module, Source.module_name(source)}}], run}

        true ->
          place_units(plan, ctx, source, abs, rel_path, run)
      end
    end
  end

  defp place_units(%FilePlan{units: units} = plan, ctx, source, abs, rel_path, run) do
    # creation by units starts from a shell nothing is present in; merging
    # only considers the missing units
    missing = Enum.reject(units, &Unit.present?(&1, source))

    if missing == [] do
      {[{:unchanged, rel_path}], run}
    else
      existing? = existing_fn(run)

      {deferred, placeable} =
        Enum.split_with(missing, fn unit -> Unit.deferred(unit, ctx, existing?) != [] end)

      {ast, placed, blocked} =
        Enum.reduce(placeable, {source.ast, [], []}, fn unit, {acc, placed, blocked} ->
          case unit.place.(acc, unit, ctx) do
            {:ok, new_ast} -> {new_ast, placed ++ [unit.id], blocked}
            :blocked -> {acc, placed, blocked ++ [unit.id]}
          end
        end)

      deferred_entries =
        for unit <- deferred,
            {_path, reason} <- Unit.deferred(unit, ctx, existing?),
            do: {unit.id, reason}

      created? = run.creating

      # a file appears only once it gets real content: a bare shell is not
      # code, and a test module without a single `describe` is not a test file.
      # Merging into a file that exists is never held back — it already has
      # content, and the closure must be able to back-fill single units into it
      content? = placed != [] and (not created? or file_content?(plan, placed))

      rows =
        cond do
          run.check? and run.creating ->
            # a missing file is reported whole only if the run would really
            # write it: waiting units are a deferral, not a creation
            cond do
              content? ->
                [{:checked, rel_path, [:whole_file]}]

              deferred_entries != [] ->
                [{:deferred, rel_path, deferred_entries}]

              true ->
                [{:checked, rel_path, ids_for_check(placed, blocked, deferred, deferred_entries)}]
            end

          run.check? ->
            [{:checked, rel_path, ids_for_check(placed, blocked, deferred, deferred_entries)}]

          not content? and blocked == [] ->
            # nothing placeable yet — write nothing, the units wait for the
            # closure of the run that creates the citizen they reference
            [{:deferred, rel_path, deferred_entries}]

          true ->
            if content?, do: FS.write!(run.fs, abs, Merge.render(ast, run.formatter_opts))

            result_rows(placed, blocked, rel_path, run, created?) ++
              if(deferred_entries == [], do: [], else: [{:deferred, rel_path, deferred_entries}])
        end

      run = if content?, do: mark_planned(run, rel_path), else: run
      {rows, run}
    end
  end

  # a test file is created by the first contributor that has a test to write
  defp file_content?(%FilePlan{requires_describe: false}, placed), do: placed != []
  defp file_content?(_plan, placed), do: Enum.any?(placed, &match?({:describe, _}, &1))

  defp ids_for_check(placed, blocked, deferred, deferred_entries) do
    reasons = fn id -> for({^id, reason} <- deferred_entries, do: reason) end

    placed ++
      Enum.map(blocked, &{:unplaceable, &1}) ++
      Enum.map(deferred, fn unit -> {:deferred, unit.id, reasons.(unit.id)} end)
  end

  defp result_rows([], blocked, rel_path, _run, _created?) when blocked != [] do
    [{:blocked, rel_path, blocked}]
  end

  defp result_rows(placed, blocked, rel_path, run, created?) do
    tag = if created?, do: :created, else: if(run.merge_only, do: :backfill, else: :merged)

    main =
      case tag do
        :created -> [{:created, rel_path}]
        :backfill -> [{:backfill, rel_path, placed}]
        :merged -> [{:merged, rel_path, placed}]
      end

    main ++ if(blocked == [], do: [], else: [{:blocked, rel_path, blocked}])
  end

  defp mark_planned(run, rel_path) do
    update_in(run.planned, &MapSet.put(&1, rel_path))
  end

  defp existing_fn(run) do
    fn path ->
      MapSet.member?(run.planned, path) or FS.exists?(run.fs, Path.join(run.repo_root, path))
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

  # ------------------------------------------------- neighborhood closure

  # Creating a citizen flips `requires` gates across its constituent:
  # re-apply every neighborhood generator's plans merge-only (existing files
  # only) until a round places nothing.
  defp closure_rounds(model, seed_ctx, opts, run) do
    elements = neighborhood(model, seed_ctx)

    Enum.reduce_while(1..@max_closure_rounds, {run, []}, fn _round, {run, acc} ->
      {run, rows} =
        Enum.reduce(elements, {run, []}, fn element, {run, rows} ->
          apply_generator_neighborhood(model, element, opts, run, rows)
        end)

      changed? =
        Enum.any?(rows, fn
          {:backfill, _, ids} -> ids != []
          {:created, _} -> true
          _ -> false
        end)

      if changed?, do: {:cont, {run, acc ++ rows}}, else: {:halt, {run, acc}}
    end)
  end

  defp apply_generator_neighborhood(model, element, opts, run, rows_acc) do
    Enum.reduce(generators(), {run, rows_acc}, fn {_generator, modules}, {run, rows} ->
      primary = hd(modules)

      if primary.accepts?(element) do
        case closure_ctx(model, element, opts, run) do
          {:ok, ctx} ->
            # the same dependency expansion as a real run, so a blueprint that
            # is only ever generated as a dependency (the validator) back-fills
            # too — merge-only, so nothing here creates a file
            plans = plans_for(modules, ctx, model, opts)
            {run, new_rows} = apply_plans(plans, %{run | merge_only: true})
            {run, rows ++ Enum.reject(new_rows, &match?({:unchanged, _}, &1))}

          _ ->
            {run, rows}
        end
      else
        {run, rows}
      end
    end)
  end

  defp closure_ctx(model, element, opts, run) do
    Context.build(
      model,
      element,
      Keyword.take(opts, [:subdomain, :composite, :constituent]) ++
        [repo_root: run.repo_root, fs: run.fs]
    )
  end

  defp neighborhood(model, %Context{} = seed) do
    c = seed.constituent

    model.elements
    |> Enum.filter(fn e ->
      case e.kind do
        :aggregate -> e.name == c
        kind when kind in [:command, :event] -> Element.aggregate_name(e) == c
        :query -> Element.read_model_name(e) == c
        :"read-model" -> e.name == c
        _ -> false
      end
    end)
    |> Enum.uniq_by(& &1.address)
  end
end
