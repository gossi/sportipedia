defmodule SpGen.Merge do
  @moduledoc """
  Append-only AST editing of an existing Elixir file.

  The generator's merge model: parse the file with Sourceror, insert the AST
  nodes of every *missing* unit at a well-chosen place in the module body,
  and print the whole tree back. Existing nodes are never modified — only new
  siblings appear — so human content survives every run, while layout
  questions (commas, blank lines, indentation) are left to
  `Sourceror.to_string/1` and the project formatter.

  A placement is a function `(ast, unit, ctx) :: {:ok, ast} | :blocked`
  built by the factories below; `:blocked` means the structure the unit
  belongs in does not exist in this file.
  """

  alias Sourceror.Zipper
  alias SpGen.Source

  @type ast :: Macro.t()
  @type place ::
          (ast(), SpGen.Unit.t(), SpGen.Context.t() ->
             {:ok, ast()} | :blocked)

  @directive_ranks %{moduledoc: 0, use: 1, import: 2, alias: 3, require: 4, attribute: 5}

  # --------------------------------------------------------------- factories

  @doc "Append at the end of the module body."
  @spec body_end() :: place()
  def body_end, do: fn ast, unit, ctx -> insert_in_body(ast, [append: true], nodes(unit, ctx)) end

  @doc """
  Insert into the leading directive block. Ranks: `:moduledoc` (first line),
  `:use`, `:import`, `:alias`, `:require`, `:attribute` (after all of these,
  directly above the first line of code).
  """
  @spec head(:moduledoc | :use | :import | :alias | :require | :attribute) :: place()
  def head(kind) do
    rank = Map.fetch!(@directive_ranks, kind)
    fn ast, unit, ctx -> insert_in_body(ast, [rank: rank], nodes(unit, ctx)) end
  end

  @doc "Insert `alias ...` alphabetically inside the alias block."
  @spec alias_of(String.t()) :: place()
  def alias_of(module) do
    fn ast, unit, ctx -> insert_in_body(ast, [rank: 3, sort: module], nodes(unit, ctx)) end
  end

  @doc "Insert before the first `defp` group (public API above private helpers), else append."
  @spec before_helpers() :: place()
  def before_helpers,
    do: fn ast, unit, ctx -> insert_in_body(ast, [before_defp: true], nodes(unit, ctx)) end

  @doc "Insert after the last clause of `name/arity` (keeps clause groups together), else append."
  @spec after_def(atom(), arity()) :: place()
  def after_def(name, arity) do
    fn ast, unit, ctx -> insert_in_body(ast, [after_clauses: {name, arity}], nodes(unit, ctx)) end
  end

  @doc """
  Insert after the last top-level `describe`, else before private helpers,
  else at the end of the body (test files keep describe blocks together).
  """
  @spec describe() :: place()
  def describe,
    do: fn ast, unit, ctx -> insert_in_body(ast, [after_describe: true], nodes(unit, ctx)) end

  @doc """
  Append inside the `macro do ... end` block of the first top-level call to
  `macro`; `:blocked` when no such call (or block) exists.
  """
  @spec inside(atom()) :: place()
  def inside(macro) do
    fn ast, unit, ctx ->
      with_module(ast, fn exprs -> inside_block(exprs, macro, nodes(unit, ctx)) end)
    end
  end

  @doc """
  Insert after the last top-level call to `macro` whose rendered first
  argument satisfies `pred`; falls back to `fallback` placement
  (default: end of body). Keeps DSL clusters grouped (`dispatch` under
  `dispatch`, `project` under `project`).
  """
  @spec after_macro(atom(), (String.t() -> boolean()), place() | nil) :: place()
  def after_macro(macro, pred \\ fn _ -> true end, fallback \\ nil) do
    fn ast, unit, ctx ->
      ns = nodes(unit, ctx)
      finder = fn e -> local_call?(e, macro) and pred.(first_rendered(e)) end

      case with_module(ast, &after_entry(&1, finder, ns)) do
        {:ok, _} = ok -> ok
        :blocked -> (fallback || body_end()).(ast, unit, ctx)
      end
    end
  end

  @doc """
  Insert after the last top-level call to `macro` whose keyword argument
  `key` renders to a value satisfying `pred`; falls back to `fallback`
  placement (default: end of body).
  """
  @spec after_macro_kw(atom(), atom(), (String.t() | nil -> boolean()), place() | nil) :: place()
  def after_macro_kw(macro, key, pred, fallback \\ nil) do
    fn ast, unit, ctx ->
      ns = nodes(unit, ctx)
      finder = fn e -> local_call?(e, macro) and pred.(kw_rendered(e, key)) end

      case with_module(ast, &after_entry(&1, finder, ns)) do
        {:ok, _} = ok -> ok
        :blocked -> (fallback || body_end()).(ast, unit, ctx)
      end
    end
  end

  @doc """
  Append an element to the `children = [...]` list (supervisor child specs),
  at any depth; `:blocked` when the assignment or list does not exist.
  """
  @spec children_list() :: place()
  def children_list do
    fn ast, unit, ctx ->
      ns = nodes(unit, ctx)

      try do
        ast
        |> Zipper.zip()
        |> Zipper.find(&match?({:children, _meta, nil}, &1))
        |> case do
          nil ->
            :blocked

          zipper ->
            with parent when parent != {:error, :no_parent} <- Zipper.up(zipper),
                 {:=, meta, [lhs, rhs]} when not is_nil(rhs) <- Zipper.node(parent),
                 list when is_list(list) <- unwrap_list(rhs) do
              {:ok, Zipper.replace(parent, {:=, meta, [lhs, list ++ ns]}) |> Zipper.root()}
            else
              _ -> :blocked
            end
        end
      rescue
        _ -> :blocked
      end
    end
  end

  @doc """
  Register a route in the web router: append it to the innermost existing
  scope of `chain` (`[{"/catalog", "SportipediaWeb.Catalog"}, ...]`),
  materializing the missing tail of the chain as nested `scope` blocks.
  `:blocked` when even the outermost scope is absent.
  """
  @spec scope([{String.t(), String.t() | nil}]) :: place()
  def scope(chain) do
    fn ast, unit, ctx ->
      text = unit.render.(ctx)

      case deepest_scope(ast, chain) do
        0 ->
          :blocked

        depth ->
          node = build_route(Enum.slice(chain, depth..-1//1), text)
          insert_route(ast, chain, depth, [node])
      end
    end
  end

  # ----------------------------------------------------------- parse / print

  @doc "Parse unit text into top-level AST expressions (flattening `__block__`)."
  @spec parse_exprs(String.t()) :: [Macro.t()]
  def parse_exprs(text) do
    case Sourceror.parse_string!(text) do
      {:__block__, _meta, exprs} -> exprs
      node -> [node]
    end
  end

  defp nodes(unit, ctx), do: parse_exprs(unit.render.(ctx))

  @doc "Render a whole file from its (edited) AST: printer, project formatter, trailing newline."
  @spec render(ast(), keyword()) :: String.t()
  def render(ast, formatter_opts \\ []) do
    ast
    |> Sourceror.to_string(Keyword.take(formatter_opts, [:locals_without_parens]))
    |> SpGen.Formatter.format(formatter_opts)
    |> then(&"#{String.trim_trailing(&1)}\n")
  end

  @doc "Canonicalize a brand-new file's content (formatting path without an AST)."
  @spec render_new(String.t(), keyword()) :: String.t()
  def render_new(text, formatter_opts \\ []) do
    text
    |> SpGen.Formatter.format(formatter_opts)
    |> then(&"#{String.trim_trailing(&1)}\n")
  end

  # ------------------------------------------------------------- module walk

  # Edit the (first) top-level defmodule's body expressions with
  # `fun.(exprs) :: {exprs, changed?}`. Parsed sources wrap the `do` keyword
  # in a `{:__block__, _, [:do]}` key node; both pair forms are handled.
  defp with_module({:defmodule, meta, [name, kw]}, fun) when is_list(kw) do
    case do_pair(kw) do
      nil ->
        :blocked

      {index, key, body} ->
        {exprs, changed?} = fun.(body_exprs(body))

        if changed? do
          {:ok, {:defmodule, meta, [name, List.replace_at(kw, index, {key, rebuild(exprs)})]}}
        else
          :blocked
        end
    end
  end

  defp with_module({:__block__, meta, exprs}, fun) do
    case Enum.find_index(exprs, &match?({:defmodule, _, _}, &1)) do
      nil ->
        :blocked

      index ->
        case with_module(Enum.fetch!(exprs, index), fun) do
          {:ok, module} -> {:ok, {:__block__, meta, List.replace_at(exprs, index, module)}}
          :blocked -> :blocked
        end
    end
  end

  defp with_module(_ast, _fun), do: :blocked

  # {index, key, body} of the `do:` pair in a call's keyword args, or nil
  defp do_pair(args), do: do_pair(args, 0)

  defp do_pair([], _i), do: nil
  defp do_pair([{:do, body} | _rest], i), do: {i, :do, body}
  defp do_pair([{{:__block__, _, [:do]} = key, body} | _rest], i), do: {i, key, body}
  defp do_pair([_ | rest], i), do: do_pair(rest, i + 1)

  defp body_exprs({:__block__, _meta, exprs}), do: exprs
  defp body_exprs(nil), do: []
  defp body_exprs(single), do: [single]

  defp rebuild([]), do: nil
  defp rebuild([single]), do: single
  defp rebuild(exprs), do: {:__block__, [], exprs}

  # ------------------------------------------------------------- body places

  defp insert_in_body(ast, opts, nodes) do
    with_module(ast, fn exprs ->
      case body_index(exprs, opts) do
        nil -> {exprs, false}
        index -> {splice(exprs, index, nodes), true}
      end
    end)
  end

  # insert nodes as sibling body expressions (a __block__ would print as a
  # parenthesized group, hiding defs from clause detection)
  defp splice(exprs, index, nodes) do
    {head, tail} = Enum.split(exprs, index)
    head ++ nodes ++ tail
  end

  defp body_index(exprs, opts) do
    cond do
      opts[:append] -> length(exprs)
      Keyword.has_key?(opts, :rank) -> rank_index(exprs, opts[:rank], opts[:sort])
      opts[:before_defp] -> before_defp_index(exprs)
      Keyword.has_key?(opts, :after_clauses) -> after_clauses_index(exprs, opts[:after_clauses])
      opts[:after_describe] -> after_describe_index(exprs)
      true -> nil
    end
  end

  # directive ranks: 0 @moduledoc, 1 use, 2 import, 3 alias, 4 require, 5 attributes
  defp rank_of({:@, _meta, [{:moduledoc, _, _}]}), do: 0
  defp rank_of({:use, _meta, args}) when is_list(args), do: 1
  defp rank_of({:import, _meta, args}) when is_list(args), do: 2
  defp rank_of({:alias, _meta, args}) when is_list(args), do: 3
  defp rank_of({:require, _meta, args}) when is_list(args), do: 4
  defp rank_of({:@, _meta, [_ | _]}), do: 5
  defp rank_of(_expr), do: nil

  defp rank_index(exprs, rank, sort_key) do
    boundary = Enum.find_index(exprs, &is_nil(rank_of(&1))) || length(exprs)

    target =
      Enum.find_index(Enum.slice(exprs, 0, boundary), fn expr ->
        case {rank_of(expr), rank, sort_key} do
          {3, 3, key} when is_binary(key) -> alias_name(expr) > key
          {existing, mine, _} -> existing > mine
        end
      end) || boundary

    target
  end

  defp alias_name(expr), do: render_arg(first_arg(expr))

  defp before_defp_index(exprs), do: Enum.find_index(exprs, &defp?/1) || length(exprs)

  defp after_clauses_index(exprs, {name, arity}) do
    exprs
    |> Enum.with_index()
    |> Enum.filter(fn {expr, _} -> def_clause?(expr, name, arity) end)
    |> Enum.map(&elem(&1, 1))
    |> case do
      [] -> length(exprs)
      indexes -> List.last(indexes) + 1
    end
  end

  defp after_describe_index(exprs) do
    exprs
    |> Enum.with_index()
    |> Enum.filter(fn {expr, _} -> local_call?(expr, :describe) end)
    |> Enum.map(&elem(&1, 1))
    |> case do
      [] -> before_defp_index(exprs)
      indexes -> List.last(indexes) + 1
    end
  end

  # ------------------------------------------------------------ inside block

  defp inside_block(exprs, macro, nodes) do
    case Enum.find_index(exprs, &local_call?(&1, macro)) do
      nil ->
        {exprs, false}

      index ->
        node = Enum.fetch!(exprs, index)

        case do_kw(node) do
          nil ->
            {exprs, false}

          _pair ->
            new_node = put_do_kw(node, rebuild(body_exprs(do_body(node)) ++ nodes))
            {List.replace_at(exprs, index, new_node), true}
        end
    end
  end

  # the `do:` pair of a call node. Parsed calls carry their keyword args in a
  # nested list (`{:scope, m, [path, alias, [do: body]]}`); the pair may also
  # sit directly in `args` (constructed nodes). Handles both shapes and both
  # pair-key forms (`{:do, _}` / `{{:__block__, _, [:do]}, _}`).
  defp do_kw({_name, _meta, args}) when is_list(args) do
    Enum.find_value(args, fn
      arg when is_list(arg) ->
        Enum.find(arg, fn
          {:do, _value} -> true
          {{:__block__, _, [:do]}, _value} -> true
          _pair -> false
        end)

      _arg ->
        nil
    end)
  end

  defp do_kw(_node), do: nil

  defp do_body(node) do
    case do_kw(node) do
      {_key, value} -> value
      nil -> nil
    end
  end

  defp put_do_kw({name, meta, args}, new_body) do
    args =
      Enum.map(args, fn
        arg when is_list(arg) -> Enum.map(arg, &replace_do_pair(&1, new_body))
        arg -> replace_do_pair(arg, new_body)
      end)

    {name, meta, args}
  end

  defp replace_do_pair({:do, _}, new_body), do: {:do, new_body}

  defp replace_do_pair({{:__block__, km, [:do]}, _}, new_body),
    do: {{:__block__, km, [:do]}, new_body}

  defp replace_do_pair(pair, _new_body), do: pair

  # ------------------------------------------------------------ entry insert

  defp after_entry(exprs, pred, nodes) do
    matches =
      exprs
      |> Enum.with_index()
      |> Enum.filter(fn {expr, _} -> pred.(expr) end)
      |> Enum.map(&elem(&1, 1))

    case matches do
      [] ->
        {exprs, false}

      _ ->
        {splice(exprs, List.last(matches) + 1, nodes), true}
    end
  end

  # ------------------------------------------------------------------- scope

  defp deepest_scope(ast, chain) do
    case module_body_exprs(ast) do
      {:ok, exprs} -> walk_chain(exprs, chain)
      :error -> 0
    end
  end

  defp module_body_exprs(ast) do
    module =
      case ast do
        {:defmodule, _, _} ->
          ast

        {:__block__, _meta, exprs} ->
          Enum.find(exprs, &match?({:defmodule, _, _}, &1))

        _ ->
          nil
      end

    case module do
      {:defmodule, _meta, [_name, kw]} when is_list(kw) ->
        case do_pair(kw) do
          {_i, _key, body} -> {:ok, body_exprs(body)}
          nil -> :error
        end

      _ ->
        :error
    end
  end

  defp walk_chain(_exprs, []), do: 0

  defp walk_chain(exprs, [{path, _alias_name} | rest]) do
    case find_scope(exprs, path) do
      nil -> 0
      scope -> 1 + walk_chain(body_exprs(do_body(scope)), rest)
    end
  end

  defp find_scope(exprs, path) do
    Enum.find(exprs, fn expr -> local_call?(expr, :scope) and first_rendered(expr) == path end)
  end

  # Build the missing tail of the scope chain around the route text as pure
  # string nesting, then parse once — keeps the route's source style intact
  # (no print/reparse round-trip through Sourceror's cwd-based defaults).
  defp build_route([], text), do: Sourceror.parse_string!(text)

  defp build_route(chain, text) do
    wrapped =
      chain
      |> Enum.reverse()
      |> Enum.reduce(text, fn {path, alias_name}, inner ->
        if is_nil(alias_name) do
          "scope \"#{path}\" do\n#{inner}\nend"
        else
          "scope \"#{path}\", #{alias_name} do\n#{inner}\nend"
        end
      end)

    Sourceror.parse_string!(wrapped)
  end

  defp insert_route(ast, chain, depth, nodes) do
    with_module(ast, fn exprs ->
      append_at_depth(exprs, chain, depth, nodes)
    end)
  end

  # `chain` lists paths level by level; `depth` says how many are matched.
  defp append_at_depth(exprs, [{path, _} | _rest], 1, nodes) do
    case Enum.find_index(exprs, fn expr ->
           local_call?(expr, :scope) and first_rendered(expr) == path
         end) do
      nil ->
        {exprs, false}

      index ->
        scope = Enum.fetch!(exprs, index)

        {List.replace_at(
           exprs,
           index,
           put_do_kw(scope, rebuild(body_exprs(do_body(scope)) ++ nodes))
         ), true}
    end
  end

  defp append_at_depth(exprs, [{path, _} | rest], depth, nodes) when depth > 1 do
    case Enum.find_index(exprs, fn expr ->
           local_call?(expr, :scope) and first_rendered(expr) == path
         end) do
      nil ->
        {exprs, false}

      index ->
        scope = Enum.fetch!(exprs, index)
        inner = body_exprs(do_body(scope))
        {new_inner, changed?} = append_at_depth(inner, rest, depth - 1, nodes)
        {List.replace_at(exprs, index, put_do_kw(scope, rebuild(new_inner))), changed?}
    end
  end

  defp append_at_depth(exprs, [], _depth, _nodes), do: {exprs, false}

  # ------------------------------------------------------------- node pieces

  defp local_call?({name, meta, args}, name) when is_list(meta) and is_list(args),
    do: not Keyword.has_key?(meta, :alias)

  defp local_call?(_node, _name), do: false

  defp defp?({:defp, _meta, _args}), do: true
  defp defp?(_), do: false

  defp def_clause?({:def, _meta, args}, name, arity), do: head_match?(args, name, arity)
  defp def_clause?(_expr, _name, _arity), do: false

  defp head_match?(args, name, arity) do
    case args do
      [{:when, _, [head | _]} | rest] -> head_match?([head | rest], name, arity)
      [{^name, _meta, nil} | _] -> arity == 0
      [{^name, _meta, call_args} | _] when is_list(call_args) -> length(call_args) == arity
      _args -> false
    end
  end

  defp first_arg({_name, _meta, [first | _rest]}), do: first
  defp first_arg(_node), do: nil

  defp unwrap_list(list) when is_list(list), do: list
  defp unwrap_list({:__block__, _, [list]}) when is_list(list), do: list
  defp unwrap_list(_node), do: nil

  defp first_rendered(node), do: render_arg(first_arg(node))

  defp render_arg(nil), do: ""
  defp render_arg(node), do: Source.render_arg(node)

  defp kw_rendered(node, key) do
    case node do
      {_name, _meta, args} when is_list(args) ->
        Enum.find_value(args, fn
          list when is_list(list) -> find_kw(list, key)
          _pair -> nil
        end)
        |> case do
          {:found, value} -> render_arg(value)
          _ -> nil
        end

      _node ->
        nil
    end
  end

  defp find_kw(list, key) do
    Enum.find_value(list, fn
      {{:__block__, _, [^key]}, value} ->
        {:found, value}

      {atom, _meta, value} when is_atom(atom) ->
        if atom == key, do: {:found, value}

      _pair ->
        nil
    end)
  end
end
