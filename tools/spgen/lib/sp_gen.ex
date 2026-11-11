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

  A unit that is present **but incomplete** — today a `validates` line for a
  field the model gave another rule — is never appended: a second line for the
  same key would shadow the first (`Vex.Struct.validates/2` stores validations
  per field). It reports under `Outdated` with the exact part to add. Rules the
  model states that no `SpGen.Invariant` pattern realizes report under
  `Unresolved rules`, because nothing is generated for them.
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
  # the only run options a closure sweep depends on: the location overrides
  # `closure_ctx/4` and `dependency_ctx/4` pass through to the context
  @closure_opts [:subdomain, :composite, :constituent]
  # process-owned memo table for closure sweeps (see `closure_sweep/4`)
  @memo :spgen_closure_memo

  # The order generators are meant to run in: what a generator writes is gated
  # on the citizens before it, so this pass needs no deferral round-trips.
  # A generator also produces the blueprints its code calls (its
  # `dependencies/1`), so following this order never defers a reference.
  # It is also the order `mix sp.gen` lists them in.
  @generator_order [
    :read_model,
    :test_support,
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
      test_support: [B.Fixtures, B.Factory],
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
           ),
         :ok <- Blueprint.validate_hook(blueprint, ctx),
         :ok <- require_operation(element, ctx) do
      plans = plans_for(modules, ctx, model, opts)
      check? = Keyword.get(opts, :check, false)
      formatter_opts = Formatter.opts(formatter_cwd, fs)

      run = new_run(repo_root, formatter_opts, check?, fs)

      {run, seed} = apply_plans(plans, run)
      created? = Enum.any?(seed, &match?({:created, _}, &1)) and blueprint.closure_scope() == :all

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

      {:ok, seed ++ backfill ++ unresolved_rows(ctx) ++ effect_gap_rows(ctx)}
    else
      {:error, {:unknown_location, var}} ->
        {:error,
         "cannot infer #{var} for #{address} — pass --#{var} <name> (subdomain/composite come from the model layout, constituent from the element scope)"}

      other ->
        other
    end
  end

  # The citizen's rules that no `SpGen.Invariant` pattern realizes are not an
  # error and generate nothing — so they are named in the report instead of
  # living only in `Context`, where no operator would find them.
  defp unresolved_rows(%Context{unresolved: []}), do: []

  defp unresolved_rows(%Context{} = ctx) do
    details =
      Enum.map(Context.unresolved(ctx), fn {name, rule} ->
        text = if(rule == "", do: "", else: " — #{rule}")

        "#{name}#{text}: no invariant pattern realizes it (implement it by hand — see the validator blueprint)"
      end)

    [{:unresolved, "#{ctx.element.kind}.#{ctx.element.name}", details}]
  end

  defp new_run(repo_root, formatter_opts, check?, fs) do
    %{
      repo_root: repo_root,
      fs: fs,
      formatter_opts: formatter_opts,
      check?: check?,
      merge_only: false,
      creating: false,
      planned: MapSet.new(),
      # `Source.parse` results by the exact text they were parsed from. A closure
      # round applies ~243 plans over ~25 files, so without this the same file is
      # tokenized once per plan that mentions it — the dominant cost of a round.
      # Keyed by content rather than path because a write changes the content and
      # must never be answered with the previous parse.
      parses: %{}
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

  # What a command does is a decision, not a reading exercise: a run that
  # finds neither an annotation nor an explicit --template is refused here,
  # where the message names both possible fixes.
  defp require_operation(%Element{kind: :command, name: name, source: source}, %{operation: nil}) do
    {:error,
     "no operation declared for command #{name} — add metadata.annotations.spgen.operation " <>
       "(create|update|delete|none) to #{source}, or pass --template"}
  end

  defp require_operation(_element, _ctx), do: :ok

  # Effect-bearing runs report open questions instead of inventing answers:
  # an event the read model never decided on generates no projector clause and
  # no aggregate fold — the gap is stated until a declaration closes it.
  defp effect_gap_rows(%Context{element: %Element{kind: :event} = e} = ctx) do
    case Context.effect_for_event(ctx, e.name) do
      nil -> [{:unresolved, e.address, [effect_gap_text(e.name)]}]
      _ -> []
    end
  end

  defp effect_gap_rows(%Context{element: %Element{kind: :aggregate} = agg, model: model} = ctx) do
    details =
      for e <- Esdm.events_of(model, agg.name),
          is_nil(Context.effect_for_event(ctx, e.name)),
          do: effect_gap_text(e.name)

    if details == [], do: [], else: [{:unresolved, agg.address, details}]
  end

  defp effect_gap_rows(_ctx), do: []

  defp effect_gap_text(event_name) do
    "no operation declared by the read model for #{event_name} — metadata.annotations.spgen.operation.#{event_name} " <>
      "(create|update|delete|none) decides materialization; projector clause and apply fold skipped"
  end

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
      --template       what the operation does: create | update | delete | none | read | collection
                       (default: the operation DECLARED in the model —
                       metadata.annotations."spgen.operation" on commands,
                       "spgen.operation.<event>" on read models — or, for
                       queries, the shape of the result)
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
  # * `{:rewritten, path}` — a projection's render differs from the file on
  #   disk; the whole file is replaced (its model is the only author)
  # * `{:deferred, path, [{unit_id, reason}]}` — units waiting for a citizen
  #   that has not been generated yet (reported only — generation order is
  #   not an error, and the tree stays compilable)
  # * `{:stale, path, [{unit_id, [detail]}]}` — a unit whose line exists but
  #   does not carry everything the model states now; never appended (a second
  #   line would shadow the first), always reported
  # * `{:unresolved, element, [detail]}` — rules the domain model states that no
  #   `SpGen.Invariant` pattern realizes: nothing is generated for them and the
  #   operator has to implement them (see `docs/…/validator.md`)
  # * `{:checked, path, [unit_id | {:unplaceable, unit_id} | {:deferred, unit_id, [reason]} | {:stale, unit_id, [detail]}]}`
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
          | {:rewritten, String.t()}
          | {:deferred, String.t(), [{term(), String.t()}]}
          | {:stale, String.t(), [{term(), [String.t()]}]}
          | {:unresolved, String.t(), [String.t()]}
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
  def apply_plan(%FilePlan{projection: true, path: rel_path} = plan, ctx, run) do
    abs_path = Path.join(run.repo_root, rel_path)
    # a projection is gated, not merge-restricted: the closure pass that flips
    # its gate may land the file wholesale — its content depends on nothing
    # but the model, so a re-render of equal content is `Ignored`, never a
    # rewrite, no matter which run triggered it
    unmet = plan.requires.(ctx) |> Enum.reject(fn {path, _reason} -> existing_fn(run).(path) end)

    if unmet != [] do
      rows = [
        {:deferred, rel_path, Enum.map(unmet, fn {_p, reason} -> {:whole_file, reason} end)}
      ]

      {rows, run}
    else
      rewrite_projection(plan, ctx, abs_path, rel_path, run)
    end
  end

  def apply_plan(%FilePlan{path: rel_path} = plan, ctx, run) do
    abs_path = Path.join(run.repo_root, rel_path)

    case FS.read(run.fs, abs_path) do
      {:error, :enoent} -> create(plan, ctx, abs_path, rel_path, run)
      {:ok, text} -> merge(plan, ctx, text, abs_path, rel_path, run)
    end
  end

  # a projection is rendered whole and compared: an unchanged file is `Ignored`,
  # a differing one is rewritten (or only reported, under `--check`)
  defp rewrite_projection(%FilePlan{scaffold: scaffold}, ctx, abs_path, rel_path, run) do
    content = Merge.render_new(scaffold.(ctx), run.formatter_opts)

    case FS.read(run.fs, abs_path) do
      {:ok, ^content} ->
        {[{:unchanged, rel_path}], run}

      {:ok, _stale_content} ->
        if run.check? do
          {[{:checked, rel_path, [:rewrite]}], run}
        else
          FS.write!(run.fs, abs_path, content)
          {[{:rewritten, rel_path}], mark_planned(run, rel_path)}
        end

      {:error, :enoent} ->
        if run.check? do
          {[{:checked, rel_path, [:whole_file]}], run}
        else
          FS.write!(run.fs, abs_path, content)
          {[{:created, rel_path}], mark_planned(run, rel_path)}
        end
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
      {source, run} = parse_cached(run, text)

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

  defp parse_cached(%{parses: parses} = run, text) do
    case Map.fetch(parses, text) do
      {:ok, source} ->
        {source, run}

      :error ->
        source = Source.parse(text)
        {source, %{run | parses: Map.put(parses, text, source)}}
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

      # a unit whose line is present but incomplete is never appended: a second
      # line for the same field would shadow the first (`Vex.Struct.validates/2`
      # keys validations by field), so the gap belongs in the report
      {stale, placeable} =
        Enum.split_with(placeable, fn unit -> Unit.stale(unit, source, ctx) != [] end)

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

      stale_entries = for unit <- stale, do: {unit.id, Unit.stale(unit, source, ctx)}
      stale_rows = if stale_entries == [], do: [], else: [{:stale, rel_path, stale_entries}]

      deferred_rows =
        if deferred_entries == [], do: [], else: [{:deferred, rel_path, deferred_entries}]

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
                deferred_rows ++ stale_rows

              true ->
                [
                  {:checked, rel_path,
                   ids_for_check(placed, blocked, deferred, deferred_entries, stale_entries)}
                ]
            end

          run.check? ->
            [
              {:checked, rel_path,
               ids_for_check(placed, blocked, deferred, deferred_entries, stale_entries)}
            ]

          not content? and blocked == [] ->
            # nothing to append: the units either wait for a citizen (deferred)
            # or need a human edit inside an existing line (stale)
            deferred_rows ++ stale_rows

          true ->
            if content?, do: FS.write!(run.fs, abs, Merge.render(ast, run.formatter_opts))

            result_rows(placed, blocked, rel_path, run, created?) ++
              deferred_rows ++ stale_rows
        end

      run = if content?, do: mark_planned(run, rel_path), else: run
      {rows, run}
    end
  end

  # a test file is created by the first contributor that has a test to write
  defp file_content?(%FilePlan{requires_describe: false}, placed), do: placed != []
  defp file_content?(_plan, placed), do: Enum.any?(placed, &match?({:describe, _}, &1))

  defp ids_for_check(placed, blocked, deferred, deferred_entries, stale_entries) do
    reasons = fn id -> for({^id, reason} <- deferred_entries, do: reason) end

    placed ++
      Enum.map(blocked, &{:unplaceable, &1}) ++
      Enum.map(deferred, fn unit -> {:deferred, unit.id, reasons.(unit.id)} end) ++
      Enum.map(stale_entries, fn {id, details} -> {:stale, id, details} end)
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
  #
  # Rounds differ only in the tree they meet, so the sweep is resolved ONCE,
  # before them: a `Context` and a generator's plans — dependency expansion
  # included — are pure functions of model, element and options and read no
  # file. Rebuilding the sweep's ~90 plan groups (243 plans) per round was the
  # pass, not the merging: a creating run cost ~190ms of which the merging was
  # the smaller part.
  #
  # The first round is a full pass, which is what keeps `pickup` honest: a tree
  # a human edited by hand gets every deferred unit re-checked, everywhere. After
  # it, a unit can only have become placeable because a file it watches was
  # written by the previous round, so the remaining rounds re-apply the plan
  # groups watching those paths — a cascade still converges, a confirming round
  # costs what it looks at instead of the whole neighbourhood.
  defp closure_rounds(model, seed_ctx, opts, run) do
    sweep = closure_sweep(model, seed_ctx, opts, run)
    mrun = %{run | merge_only: true}

    # rows accumulate in reverse: appending to a list per plan group is O(n²)
    # over 243 groups, and the report order does not matter (the CLI groups by
    # file and prints the furthest-along state per path)
    Enum.reduce_while(1..@max_closure_rounds, {mrun, [], :all}, fn _round, {mrun, acc, touched} ->
      {mrun, rows, changed} =
        Enum.reduce(round_candidates(sweep, touched), {mrun, [], MapSet.new()}, fn
          {plans, _watches}, {mrun, rows, ch} ->
            {mrun, new_rows} = apply_plans(plans, mrun)
            reported = Enum.reject(new_rows, &match?({:unchanged, _}, &1))

            {mrun, reported ++ rows, Enum.reduce(reported, ch, &row_paths(&2, &1))}
        end)

      rows = Enum.reverse(rows)

      if MapSet.size(changed) == 0 do
        {:halt, {mrun, acc}}
      else
        {:cont, {mrun, acc ++ rows, changed}}
      end
    end)
  end

  defp round_candidates(sweep, :all), do: sweep

  defp round_candidates(sweep, touched) do
    for {plans, watches} <- sweep, MapSet.disjoint?(watches, touched) == false do
      {plans, watches}
    end
  end

  # the paths of a row that says this plan group wrote something
  defp row_paths(changed, row) do
    case row do
      {:backfill, path, ids} when ids != [] -> MapSet.put(changed, path)
      {:created, path} -> MapSet.put(changed, path)
      {:updated, path} -> MapSet.put(changed, path)
      {:rewritten, path} -> MapSet.put(changed, path)
      _ -> changed
    end
  end

  # every generator that accepts a neighbourhood element, with its plans already
  # expanded — the list a round used to recompute from the model.
  #
  # Cached per process: the sweep is a pure function of the model, the run
  # options and the repository it plans into, and a build sequence runs thirty
  # generators over the same constituent, so recomputing 90 `plans/1` calls per
  # run was 87ms of arithmetic on an answer the process had already produced.
  # The key carries a fingerprint of the model itself, so a test that edits a
  # model file and re-runs gets a fresh sweep — a stale plan list is never
  # possible, and the `fs` handle pins the repository.
  defp closure_sweep(model, seed_ctx, opts, run) do
    key = {seed_ctx.constituent, model_key(model), opts_key(opts), run.repo_root, run.fs}

    case memo_fetch(key) do
      :miss ->
        sweep = build_sweep(model, seed_ctx, opts, run)
        memo_put(key, sweep)
        sweep

      sweep ->
        sweep
    end
  end

  defp build_sweep(model, seed_ctx, opts, run) do
    for element <- neighborhood(model, seed_ctx),
        modules <- Map.values(generators()),
        primary = hd(modules),
        primary.accepts?(element),
        # a context the element cannot support (no location to infer) has no
        # plans: its gates defer as they always did
        {:ok, ctx} <- [closure_ctx(model, element, opts, run)] do
      # the same dependency expansion as a real run, so a blueprint that is only
      # ever generated as a dependency (the validator) back-fills too —
      # merge-only, so nothing here creates a file
      plans = plans_for(modules, ctx, model, opts) |> freeze_gates()
      {plans, watched_paths(plans)}
    end
  end

  # A unit's `requires` is a function of its context and nothing else — it
  # renders the citizen paths it mentions — yet every round of every run called
  # it again for all ~1300 units of the neighbourhood: 42ms of the ~100ms a
  # creating run took, answering a question whose answer had not changed. The
  # sweep is memoized per context, so the paths are computed once here and the
  # unit is handed back a function that already knows them.
  defp freeze_gates(plans) do
    Enum.map(plans, fn {plan, ctx} ->
      units =
        Enum.map(plan.units, fn unit ->
          paths = unit.requires.(ctx)
          %{unit | requires: fn _ -> paths end}
        end)

      {%{plan | units: units}, ctx}
    end)
  end

  # every file this plan group reads a gate from, plus the files it writes: the
  # narrow question a later round asks is "did any of these change?"
  defp watched_paths(plans) do
    plans
    |> Enum.flat_map(fn {%FilePlan{} = plan, ctx} ->
      [plan.path | plan_gates(plan, ctx)]
    end)
    |> Enum.reject(&is_nil/1)
    |> MapSet.new()
  end

  # the files a plan group reads a verdict from: every unit's `requires`, plus a
  # projection's own file-level gate
  defp plan_gates(%FilePlan{units: units} = plan, ctx) do
    units
    |> Enum.flat_map(fn unit -> unit.requires.(ctx) end)
    |> Enum.map(fn {path, _reason} -> path end)
    |> Kernel.++(projection_gates(plan, ctx))
  end

  defp projection_gates(%FilePlan{projection: true, requires: requires}, ctx) do
    requires.(ctx) |> Enum.map(fn {path, _reason} -> path end)
  end

  defp projection_gates(%FilePlan{}, _ctx), do: []

  defp model_key(model), do: :erlang.phash2(model)

  defp opts_key(opts), do: opts |> Keyword.take(@closure_opts) |> Enum.sort()

  # -- closure memo: private to the calling process ----------------------------
  #
  # A named table would be owned by whichever process created it and vanish when
  # that process exits, silently costing every other caller its cached sweeps —
  # and a `whereis` on every lookup is a global registry hit per plan group.
  # The caller's own process is the right lifetime: a build sequence runs its
  # generators in one process (so they share the memo), a test's memo dies with
  # the test, and the CLI — one run per process — never allocates more than the
  # sweep it is about to use.
  defp memo_fetch(key) do
    case Process.get(@memo) do
      nil -> :miss
      table -> :ets.lookup_element(table, key, 2, :miss)
    end
  end

  defp memo_put(key, value) do
    :ets.insert(memo_table(), {key, value})
    :ok
  end

  defp memo_table do
    case Process.get(@memo) do
      nil ->
        table = :ets.new(@memo, [:set, read_concurrency: true])
        Process.put(@memo, table)
        table

      table ->
        table
    end
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
