defmodule Sportipedia.Codegen.Source do
  @moduledoc """
  Read-only view of an Elixir source file as a parsed AST, answering the delta
  questions of the code generators:

  * which units are already present — module, directives (`use`/`alias`/
    `import`/`require`), attributes (`@moduledoc`/`@behaviour`/`@derive`),
    function clauses by name/arity (optionally by head pattern), and DSL
    entries (`field`, `validates`, `dispatch`, `identify`, `project`,
    `operation`, `plug`, `describe`, …)

  Editing is the job of `Sportipedia.Codegen.Merge`, which appends missing
  units to the parsed tree. `Source` itself never rewrites anything.

  Entry keys are rendered strings (`render_arg/1`): module aliases dotted
  (`CatalogApparatus`), atom arguments with colon (`:title`), `%Event{}`
  patterns as `Event{}`, strings unquoted, everything else via
  `Macro.to_string/1`. Note that in parsed source, atom arguments appear as
  *bare atoms*, while variables are `{name, meta, nil}` tuples.
  """

  defmodule Entry do
    @moduledoc "A located local call."
    defstruct [:macro, :args, :line, :end_line, :node]

    @type t :: %__MODULE__{
            macro: atom(),
            args: [Macro.t()],
            line: pos_integer(),
            end_line: pos_integer(),
            node: Macro.t()
          }

    @doc """
    Rendered value of a keyword argument, when the call carries a keyword
    list, e.g. `Entry.kw(dispatch_entry, :aggregate)`.

    Parsed keyword pairs are `{{:__block__, _, [key]}, value}` tuples;
    constructed ones are `{key, meta, value}` call nodes — both are handled.
    """
    @spec kw(t(), atom()) :: String.t() | nil
    def kw(%Entry{args: args}, key) do
      keyword =
        Enum.find_value(args, fn
          list when is_list(list) -> find_keyword(list, key)
          _ -> nil
        end)

      case keyword do
        {:found, value} -> Sportipedia.Codegen.Source.render_arg(value)
        _ -> nil
      end
    end

    defp find_keyword(list, key) do
      Enum.find_value(list, fn
        {{:__block__, _, [^key]}, value} ->
          {:found, value}

        {atom, _meta, value} when is_atom(atom) ->
          if atom == key, do: {:found, value}

        _ ->
          nil
      end)
    end
  end

  defstruct [:text, :ast, :lines]

  @type t :: %__MODULE__{text: String.t(), ast: Macro.t() | nil, lines: [String.t()]}

  alias Sportipedia.Codegen.Source.Entry

  @doc "Parses source text; unparsable files yield `ast: nil` (nothing is present)."
  @spec parse(String.t()) :: t()
  def parse(text) when is_binary(text) do
    ast =
      try do
        Sourceror.parse_string!(text)
      rescue
        _ -> nil
      end

    %__MODULE__{text: text, lines: String.split(text, "\n"), ast: ast}
  end

  @doc "The dotted module name of the file's `defmodule`, if any."
  @spec module_name(t()) :: String.t() | nil
  def module_name(%__MODULE__{ast: {:defmodule, _, [{:__aliases__, _, parts} | _]}}) do
    Enum.map_join(parts, ".", &to_string/1)
  end

  def module_name(%__MODULE__{}), do: nil

  # ------------------------------------------------------------- directives

  def has_moduledoc?(src), do: body(src) |> Enum.any?(&attr?(&1, :moduledoc))

  @doc "True when the module body carries a `@<attr>` attribute."
  def has_attribute?(src, attr), do: body(src) |> Enum.any?(&attr?(&1, attr))

  @doc "True when `@behaviour A.B` names the dotted `module`."
  def has_behaviour?(src, module), do: attr_names?(src, :behaviour, module)

  @doc "True when `@derive A.B` names the dotted `module`."
  def has_derive?(src, module), do: attr_names?(src, :derive, module)

  def has_use?(src, module), do: calls(src, :use) |> Enum.any?(&named?(&1, module))
  def has_import?(src, module), do: calls(src, :import) |> Enum.any?(&named?(&1, module))
  def has_alias?(src, module), do: calls(src, :alias) |> Enum.any?(&named?(&1, module))
  def has_require?(src, module), do: calls(src, :require) |> Enum.any?(&named?(&1, module))

  defp attr_names?(src, attr, module) do
    src
    |> body()
    |> Enum.any?(fn
      {:@, _meta, [{^attr, _am, values}]} ->
        values |> List.wrap() |> Enum.any?(&(&1 |> unwrap_block() |> render_arg() == module))

      _ ->
        false
    end)
  end

  defp attr?(node, attr), do: match?({:@, _meta, [{^attr, _am, _v}]}, node)
  defp unwrap_block({:__block__, _, [value]}), do: value
  defp unwrap_block(value), do: value

  # ------------------------------------------------------------------ defs

  @doc "True when any clause of `name/arity` is defined."
  def has_def?(src, name, arity) do
    src |> def_clauses() |> Enum.any?(fn c -> c.name == name and c.arity == arity end)
  end

  # clause summaries from the module body, with attribute pairing
  defp def_clauses(%__MODULE__{ast: nil}), do: []

  defp def_clauses(src) do
    {clauses, _pending} =
      src
      |> body()
      |> Enum.reduce({[], %{doc: false, spec: false}}, fn
        {:@, _m, [{attr, _am, _v}]} = _node, {acc, pending} when attr in [:doc, :spec] ->
          {acc, Map.put(pending, attr, true)}

        {:@, _, _}, acc_and_pending ->
          acc_and_pending

        {:def, meta, args} = node, {acc, pending} ->
          {name, arity, head_args} = def_head(args)

          clause = %{
            name: name,
            arity: arity,
            head_args: head_args,
            line: meta[:line],
            end_line: end_line_of(node),
            doc?: pending.doc,
            spec?: pending.spec
          }

          {acc ++ [clause], %{doc: false, spec: false}}

        _other, acc_and_pending ->
          acc_and_pending
      end)

    clauses
  end

  defp def_head([head | _rest]) do
    case head do
      {:when, _meta, [plain | _guards]} -> def_head([plain])
      {name, _meta, nil} -> {name, 0, []}
      {name, _meta, args} when is_list(args) -> {name, length(args), args}
      _ -> {nil, 0, []}
    end
  end

  defp def_head([]), do: {nil, 0, []}

  # --------------------------------------------------------------- entries

  @doc "True when a DSL entry of `macro` exists whose first argument renders to `key`."
  def entry?(src, macro, key) do
    src |> calls(macro) |> Enum.any?(fn %Entry{args: [first | _]} -> render_arg(first) == key end)
  end

  @doc "True when `describe \"subject\"` exists (exact match)."
  def has_describe?(src, subject) do
    src
    |> calls(:describe)
    |> Enum.any?(fn %Entry{args: [first | _]} -> literal_text(first) == subject end)
  end

  @doc """
  True when the dotted `module` occurs anywhere in the file — supervisor
  children are listed by full module name (or aliased), so a text hit counts.
  """
  def has_child?(%__MODULE__{text: text}, module), do: String.contains?(text, module)

  @doc """
  All local (non-remote) calls of `macro` in the module, in source order.

  The walk covers the module body and any non-function blocks (e.g. inside
  `typedstruct do … end` or router `scope`s) but never descends into
  function bodies or other modules.
  """
  @spec calls(t(), atom()) :: [Entry.t()]
  def calls(%__MODULE__{ast: nil}, _macro), do: []

  def calls(src, macro) do
    src
    |> body_node()
    |> scan(macro, [])
    |> Enum.sort_by(& &1.line)
  end

  defp scan(nil, _macro, acc), do: acc

  defp scan({:__block__, _meta, exprs}, macro, acc) do
    Enum.reduce(exprs, acc, &scan(&1, macro, &2))
  end

  defp scan(list, macro, acc) when is_list(list) do
    Enum.reduce(list, acc, &scan(&1, macro, &2))
  end

  # keyword pairs: `[do: block]`, `[enforce: true]` — descend into the value;
  # do-block pairs are `{{:__block__, _, [:do]}, body}` — descend into both
  defp scan({key, value}, macro, acc) when is_atom(key), do: scan(value, macro, acc)

  defp scan({left, right}, macro, acc) do
    acc
    |> then(&scan(left, macro, &1))
    |> then(&scan(right, macro, &1))
  end

  defp scan({name, meta, args} = node, macro, acc) when is_atom(name) and is_list(meta) do
    acc =
      if name == macro and local_call?(meta, args) do
        [
          %Entry{
            macro: name,
            args: List.wrap(args),
            line: meta[:line] || 0,
            end_line: end_line_of(node),
            node: node
          }
          | acc
        ]
      else
        acc
      end

    cond do
      # never look inside other modules or into function bodies
      name == :defmodule -> acc
      name in [:def, :defp, :defmacro, :defmacrop] -> acc
      true -> scan(args, macro, acc)
    end
  end

  defp scan(_other, _macro, acc), do: acc

  # a real call has args (not nil like a bare variable/atom); remote calls
  # (`Ecto.Changeset.field(...)`) carry :alias metadata and are skipped
  defp local_call?(meta, args), do: is_list(args) and not Keyword.has_key?(meta, :alias)

  # ---------------------------------------------------------------- routes

  @doc """
  True when a route (`verb` macro + action atom, e.g. `":catalog_apparatus"`)
  exists inside the scope chain of path strings, e.g.
  `["/catalog", "/equipment", "/apparatuses"]`. Routes are identified by
  action because paths like `"/"` collide across scopes.
  """
  @spec route_present?(t(), atom(), String.t(), [String.t()]) :: boolean()
  def route_present?(src, verb, action_key, scope_paths) do
    case deepest_scope(src, scope_paths) do
      {:ok, scope, _depth} ->
        src
        |> calls(verb)
        |> Enum.any?(fn e ->
          e.line > scope.line && e.line < scope.end_line && action_arg(e) == action_key
        end)

      :none ->
        false
    end
  end

  @doc """
  The deepest existing scope in the chain `paths`, as `{:ok, entry, depth}`
  where `depth` is how many leading path segments were matched, or `:none`.
  """
  @spec deepest_scope(t(), [String.t()]) :: {:ok, Entry.t(), pos_integer()} | :none
  def deepest_scope(src, paths) do
    scopes = calls(src, :scope)
    walk_scopes(scopes, paths, {0, 1_000_000_000}, {nil, 0})
  end

  defp walk_scopes(_scopes, [], _range, best), do: finish_scope(best)

  defp walk_scopes(scopes, [path | rest], {lo, hi}, best) do
    case Enum.find(scopes, fn s ->
           first_rendered(s) == path && s.line > lo && s.end_line < hi
         end) do
      nil ->
        finish_scope(best)

      s ->
        walk_scopes(scopes, rest, {s.line, s.end_line}, {s, elem(best, 1) + 1})
    end
  end

  defp finish_scope({nil, _}), do: :none
  defp finish_scope({s, depth}), do: {:ok, s, depth}

  @doc """
  True when a clause of `name/arity` has `key` (rendered arg) somewhere in
  its head — e.g. `authorize/3` clauses identified by their action atom.
  """
  def def_head_has?(src, name, arity, key) do
    src
    |> def_clauses()
    |> Enum.any?(fn c ->
      c.name == name and c.arity == arity and
        Enum.any?(c.head_args, fn arg -> render_arg(arg) == key end)
    end)
  end

  @doc "True when an entry of `macro` exists that has keyword `key` at all."
  def entry_kw?(src, macro, key) do
    src |> calls(macro) |> Enum.any?(fn e -> not is_nil(Entry.kw(e, key)) end)
  end

  # ------------------------------------------------------------------ bits

  defp body(%__MODULE__{ast: nil}), do: []

  defp body(src) do
    case body_node(src) do
      {:__block__, _, exprs} -> exprs
      nil -> []
      single -> [single]
    end
  end

  @doc false
  def body_node(%__MODULE__{ast: {:defmodule, _, [_name, body]}}) do
    case body do
      [{{:__block__, _, [:do]}, inner}] -> inner
      [do: inner] -> inner
      _ -> nil
    end
  end

  def body_node(%__MODULE__{}), do: nil

  defp end_line_of({_name, meta, args}) do
    candidates =
      [meta[:line]] ++
        List.wrap(get_in(meta, [:end, :line])) ++
        List.wrap(get_in(meta, [:end_of_expression, :line])) ++
        List.wrap(nested_end(args))

    candidates
    |> Enum.filter(&is_integer/1)
    |> case do
      [] -> 0
      lines -> Enum.max(lines)
    end
  end

  # `project %E{}, _md, fn multi -> … end` — the closing `end` belongs to the
  # nested fn; take the deepest `:end`/`:end_of_expression` seen below.
  defp nested_end(args) do
    args
    |> List.wrap()
    |> Enum.map(&nested_end_term/1)
    |> Enum.filter(&is_integer/1)
    |> case do
      [] -> nil
      lines -> Enum.max(lines)
    end
  end

  defp nested_end_term(list) when is_list(list) do
    list |> Enum.map(&nested_end_term/1) |> non_nil_max()
  end

  defp nested_end_term({_, meta, _} = node) do
    direct =
      [get_in(meta, [:end, :line]), get_in(meta, [:end_of_expression, :line])]
      |> Enum.filter(&is_integer/1)

    deeper = nested_end(elem(node, 2))

    case direct ++ List.wrap(deeper) do
      [] -> nil
      lines -> Enum.max(lines)
    end
  end

  defp nested_end_term(other) when is_tuple(other) do
    other |> Tuple.to_list() |> nested_end_term()
  end

  defp nested_end_term(_), do: nil

  defp non_nil_max(list) do
    case Enum.filter(list, &is_integer/1) do
      [] -> nil
      nums -> Enum.max(nums)
    end
  end

  defp named?(%Entry{args: [first | _]}, module), do: render_arg(first) == module
  defp named?(_, _), do: false

  # the action of a route call is its last argument (`post "/x", Ctl, :act`)
  defp action_arg(%Entry{args: args}) when args != [], do: args |> List.last() |> render_arg()
  defp action_arg(_), do: ""

  defp first_rendered(%Entry{args: [first | _]}), do: render_arg(first)
  defp first_rendered(_), do: ""

  @doc """
  Renders a call argument as an entry key (see module docs).
  """
  @spec render_arg(Macro.t() | term()) :: String.t()
  def render_arg({:__aliases__, _, parts}), do: Enum.map_join(parts, ".", &to_string/1)
  def render_arg({:__block__, _meta, [binary]}) when is_binary(binary), do: binary
  def render_arg(atom) when is_atom(atom), do: inspect(atom)
  def render_arg(binary) when is_binary(binary), do: binary
  def render_arg({:_, meta, nil}) when is_list(meta), do: "_"
  def render_arg({var, meta, nil}) when is_atom(var) and is_list(meta), do: to_string(var)
  def render_arg({:<<>>, _, [binary]}) when is_binary(binary), do: binary

  def render_arg({:%, _, [{:__aliases__, _, parts}, _]}),
    do: Enum.map_join(parts, ".", &to_string/1) <> "{}"

  def render_arg({:!, _, [inner]}), do: render_arg(inner) <> "!"
  def render_arg({:=, _, [left | _]}), do: render_arg(left)
  def render_arg({:when, _, [head | _]}), do: render_arg(head)
  def render_arg(list) when is_list(list), do: list |> Macro.to_string() |> normalize_text()
  def render_arg(other), do: other |> Macro.to_string() |> normalize_text()

  defp normalize_text(text), do: text |> String.replace(~r/\s+/, " ") |> String.trim()

  # parsed string literals arrive wrapped in a :__block__ carrying the
  # delimiter/indentation metadata
  defp literal_text({:__block__, _meta, [binary]}) when is_binary(binary), do: binary
  defp literal_text({:<<>>, _, [binary]}) when is_binary(binary), do: binary
  defp literal_text(other) when is_binary(other), do: other
  defp literal_text(_), do: nil
end
