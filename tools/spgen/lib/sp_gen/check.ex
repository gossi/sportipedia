defmodule SpGen.Check do
  @moduledoc """
  Engine of `mix sp.check`: does the domain model carry everything the blueprint
  generators need to materialize code? Nothing is generated, nothing is written.

  The checks are the generators' own contracts, read through the same modules —
  so a model that passes `sp.check` can always be generated, and `sp.check`
  never judges by a second standard:

  * **fixture contract** (`SpGen.Fixtures`) — for every read model with
    `schema.examples`: keys are `<composite>:<read-model>:<mnemonic>` and name
    their own home; examples carry no field the schema does not declare, carry
    every field it requires; reference values are fixture keys or UUIDs; the
    code names stay legal, unique, and clear of the aggregate function.
  * **prose slots** — commands, events and queries declare a `description`.
    Without it the generated `@moduledoc`s and controller operation summaries
    materialize as `TODO:` markers, leaving hand-work for an implementer who
    was promised generated code.
  * **declared operations (integrity)** — a read model's
    `metadata.annotations."spgen.operation.<event>"` keys and their
    `projections` stand in bijection: every projection has a
    `create|update|delete` decision, every decision without a projection is
    exactly `none` ("decided: does not materialize"), and no key names a
    stranger event.
  * **declared operations (completeness)** — every command carries
    `metadata.annotations."spgen.operation"` with `create|update|delete|none`;
    without it no generator can run, because guessing what a command does is
    not a decision. `none` is: dispatch facts, materialize no read model.
  * **reference resolution** (whole-model mode only) — every fixture key
    *referenced* from an example is *defined* by one. This is the closed world
    the fixture graph promises; scoped runs skip it, because a subset cannot
    see the whole.

  Arguments: none (the whole model), directories (every element under them),
  or element addresses as `mix sp.gen` accepts them (`esdm:` references,
  `*.esdm.yaml` paths, `kind.name`, bare names).
  """

  alias SpGen.{Context, Esdm, FS, Fixtures}
  alias SpGen.Esdm.Element

  @typedoc "A finding: where in the model, which element, what is missing."
  @type finding :: %{file: String.t(), element: String.t(), message: String.t()}

  @prose_kinds [:command, :event, :query]

  @switches [model: :string, root: :string]

  @doc """
  Run the checks over the model in `argv`. Returns `{:ok, findings}` — an
  empty list is a green model — or `{:error, message}` for usage problems
  (unknown options, unresolvable addresses).

  Options: `:fs` — the `SpGen.FS` handle (default: the real disk).
  """
  @spec run([String.t()], keyword()) :: {:ok, [finding()]} | {:error, String.t()}
  def run(argv, run_opts \\ []) do
    {opts, args, invalid} = OptionParser.parse(argv, strict: @switches)

    if invalid != [] do
      {:error, "unknown option(s): " <> Enum.map_join(invalid, ", ", fn {k, _} -> k end)}
    else
      fs = Keyword.get(run_opts, :fs, FS.default())
      repo_root = opts |> Keyword.get(:root, SpGen.find_root(cwd(fs), fs)) |> Path.expand()
      model_root = Path.join(repo_root, Keyword.get(opts, :model, "docs/domain-model"))

      with {:ok, model} <- Esdm.load(model_root, fs: fs) do
        case targets(model, args, fs) do
          {:ok, elements} ->
            findings = Enum.flat_map(elements, &element_findings(model, &1))
            whole? = args == []
            extra = if whole?, do: unresolved_references(model), else: []
            {:ok, relativize(findings ++ extra, repo_root)}

          {:error, _message} = error ->
            error
        end
      end
    end
  end

  # operators read paths, messages included, from the repo root — the model
  # was loaded with absolute ones
  defp relativize(findings, repo_root) do
    prefix = repo_root <> "/"

    Enum.map(findings, fn finding ->
      %{
        finding
        | file: String.replace_prefix(finding.file, prefix, ""),
          message: String.replace(finding.message, prefix, "")
      }
    end)
  end

  defp cwd({SpGen.FS.Local, nil}), do: File.cwd!()
  defp cwd(_fs), do: "/"

  # no args → the whole model; a directory argument → the elements loaded from
  # it; anything else is an address resolved against the whole model. The
  # directory test is only attempted for paths a filesystem can stat: VFS
  # rejects relative paths outright, and an address never looks like one.
  defp targets(model, [], _fs) do
    {:ok, model.elements}
  end

  defp targets(model, args, fs) do
    Enum.reduce_while(args, {:ok, []}, fn arg, {:ok, found} ->
      if dir_arg?(arg, fs) do
        {:ok, sub} = Esdm.load(arg, fs: fs)
        {:cont, {:ok, found ++ sub.elements}}
      else
        case Esdm.resolve(model, arg) do
          {:ok, element} -> {:cont, {:ok, found ++ [element]}}
          {:error, reason} -> {:halt, {:error, "#{arg}: " <> Esdm.format_error(reason)}}
        end
      end
    end)
    |> case do
      {:ok, elements} -> {:ok, Enum.uniq_by(elements, & &1.address)}
      {:error, _} = error -> error
    end
  end

  defp dir_arg?(arg, fs) do
    case {String.starts_with?(arg, "/"), local_fs?(fs)} do
      {true, _} -> FS.dir?(fs, arg)
      {false, true} -> FS.dir?(fs, arg)
      {false, false} -> false
    end
  end

  defp local_fs?({SpGen.FS.Local, _state}), do: true
  defp local_fs?(_fs), do: false

  defp element_findings(model, %Element{} = element) do
    prose_findings(element) ++
      fixture_findings(model, element) ++ operation_findings(model, element)
  end

  # --------------------------------------------- declared operations (annotations)
  #
  # What a command does, what each event does to its read model, and what kind of
  # read a query is are DECISIONS recorded in metadata.annotations under the
  # `spgen.` namespace — generation refuses to guess. The checks here are the
  # halves of that contract:
  #
  # * integrity: a read model's `spgen.operation.<event>` keys and their
  #   projections agree, one decision per event, `none` only without a
  #   projection; a query's declaration and its `result` shape agree;
  # * completeness: every command declares `spgen.operation`, so any generator
  #   run can proceed without --template. A query need not: `result.type: array`
  #   already answers `read | collection`, so absence is silence, not a gap.

  defp operation_findings(model, %Element{kind: :"read-model"} = element) do
    read_model_ledger(model, element)
  end

  defp operation_findings(_model, %Element{kind: :command} = element) do
    prefixed =
      for({key, _} <- operation_keys(element), key != Esdm.operation_key(), do: {key, nil})

    command_operation(element) ++
      misplaced(
        prefixed,
        element,
        "commands declare a bare #{Esdm.operation_key()}, never #{Esdm.effect_prefix()}<event>"
      )
  end

  defp operation_findings(_model, %Element{kind: :query} = element) do
    prefixed =
      for({key, _} <- operation_keys(element), key != Esdm.operation_key(), do: {key, nil})

    query_operation(element) ++
      misplaced(
        prefixed,
        element,
        "queries declare a bare #{Esdm.operation_key()} (read|collection), never a per-event key"
      )
  end

  defp operation_findings(_model, %Element{kind: :event} = element) do
    # events carry no operations — their read model decides; a key here is a
    # second source for one fact
    misplaced(operation_keys(element), element, "read models declare event effects")
  end

  defp operation_findings(_model, element) do
    misplaced(operation_keys(element), element, nil)
  end

  defp operation_keys(element) do
    element
    |> Esdm.annotations()
    |> Enum.filter(fn {key, _} ->
      key == Esdm.operation_key() or String.starts_with?(key, Esdm.effect_prefix())
    end)
  end

  defp misplaced([], _element, _note), do: []

  defp misplaced(keys, element, note) do
    names = keys |> Enum.map(&elem(&1, 0)) |> Enum.join(", ")

    [
      finding(
        element,
        "#{Esdm.operation_key()} annotations belong elsewhere — found #{names} on a #{element.kind}" <>
          if(note, do: "; #{note}", else: "")
      )
    ]
  end

  defp command_operation(%Element{} = element) do
    case Esdm.annotations(element)[Esdm.operation_key()] do
      v when v in ["create", "update", "delete", "none"] ->
        []

      nil ->
        [
          finding(
            element,
            "no metadata.annotations.#{Esdm.operation_key()} (create|update|delete|none) — generation must not guess what #{element.name} does"
          )
        ]

      other ->
        [
          finding(
            element,
            "#{Esdm.operation_key()}: #{inspect(other)} is not create|update|delete|none"
          )
        ]
    end
  end

  # A query's declaration is optional, but a made declaration is binding: it is
  # what lets `SpGen.Blueprint.Query` generate a body instead of leaving a TODO,
  # so it must be in the query vocabulary and it must agree with the `result` the
  # model already states — a `collection` over a single object, or a `read` that
  # returns an array, would have the generators build two different citizens.
  defp query_operation(%Element{} = element) do
    case Esdm.annotations(element)[Esdm.operation_key()] do
      nil ->
        []

      v when v in ["read", "collection"] ->
        operation_agreement(element, v)

      other ->
        [
          finding(
            element,
            "#{Esdm.operation_key()}: #{inspect(other)} is not #{Enum.join(Esdm.query_operations(), "|")}"
          )
        ]
    end
  end

  defp operation_agreement(%Element{doc: doc} = element, declared) do
    case get_in(doc, ["result", "type"]) do
      type when is_binary(type) ->
        array? = type == "array"
        declares_collection? = declared == "collection"

        if array? == declares_collection? do
          []
        else
          [
            finding(
              element,
              "#{Esdm.operation_key()}: #{declared} contradicts result.type: #{type} — a collection reads an array"
            )
          ]
        end

      _ ->
        []
    end
  end

  defp read_model_ledger(model, %Element{} = element) do
    annotations = Esdm.annotations(element)
    effects = Esdm.declared_effects(element)
    projected = element |> Esdm.projections() |> Enum.map(& &1["event"])

    Enum.flat_map(projected, &ledger_entry(element, effects, &1)) ++
      Enum.flat_map(effects, fn {event, value} ->
        if event in projected, do: [], else: orphan_entry(model, element, event, value)
      end) ++
      bare_operation_note(element, annotations)
  end

  defp ledger_entry(element, effects, event) do
    case Map.get(effects, event) do
      nil ->
        [
          finding(
            element,
            "projection of #{event} has no #{Esdm.effect_prefix()}#{event} decision"
          )
        ]

      :none ->
        [
          finding(
            element,
            "#{Esdm.effect_prefix()}#{event}: none, but the read model projects #{event}"
          )
        ]

      :invalid ->
        [
          finding(
            element,
            "#{Esdm.effect_prefix()}#{event} has a value outside create|update|delete|none"
          )
        ]

      _ ->
        []
    end
  end

  defp orphan_entry(model, element, event, value) do
    known_event = Enum.any?(Esdm.events_of(model, element.name), &(&1.name == event))

    cond do
      value != :none ->
        [
          finding(
            element,
            "#{Esdm.effect_prefix()}#{event}: #{value} declares materialization, but the read model has no projection of #{event}"
          )
        ]

      not known_event ->
        [
          finding(
            element,
            "#{Esdm.effect_prefix()}#{event} names no event of aggregate #{element.name}"
          )
        ]

      true ->
        []
    end
  end

  defp bare_operation_note(element, annotations) do
    if Map.has_key?(annotations, Esdm.operation_key()) do
      [
        finding(
          element,
          "a read model decides per event — use #{Esdm.effect_prefix()}<event> keys, not a bare #{Esdm.operation_key()}"
        )
      ]
    else
      []
    end
  end

  # -------------------------------------------------------------------- prose

  defp prose_findings(%Element{kind: kind} = element) when kind in @prose_kinds do
    case Esdm.describe(element) do
      desc when is_binary(desc) and desc != "" ->
        []

      _ ->
        [
          finding(
            element,
            "no description — generated docs and operation summaries would materialize as TODO markers"
          )
        ]
    end
  end

  defp prose_findings(_element), do: []

  # ------------------------------------------------------------------ fixtures

  defp fixture_findings(model, %Element{kind: :"read-model"} = element) do
    if Fixtures.examples(element) == [] do
      []
    else
      case Context.build(model, element) do
        {:ok, ctx} ->
          plural = Context.render("<domain_object>s", ctx)

          case Fixtures.validate(element, ctx.composite, plural) do
            {:ok, _specs} -> []
            {:error, messages} -> Enum.map(messages, &finding(element, &1))
          end

        {:error, {:unknown_location, var}} ->
          [
            finding(
              element,
              "cannot infer #{var} from the model layout — fixture keys cannot be checked"
            )
          ]
      end
    end
  end

  defp fixture_findings(_model, _element), do: []

  # whole-model mode: every referenced key resolves to a defined fixture id
  defp unresolved_references(%Esdm{} = model) do
    defined =
      model.elements
      |> Enum.filter(&(&1.kind == :"read-model"))
      |> Enum.flat_map(&Fixtures.defined_keys/1)
      |> MapSet.new()

    for element <- model.elements,
        element.kind == :"read-model",
        key <- Fixtures.referenced_keys(element),
        not MapSet.member?(defined, key) do
      finding(element, "references fixture key #{inspect(key)}, which no read model defines")
    end
  end

  defp finding(%Element{} = element, message) do
    %{file: element.source, element: element.address, message: message}
  end
end
