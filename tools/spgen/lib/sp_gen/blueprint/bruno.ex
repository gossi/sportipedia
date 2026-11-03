defmodule SpGen.Blueprint.Bruno do
  @moduledoc """
  Executable transfer of `docs/architecture/blueprints/backend/web/bruno.md`
  — the request documentation file for one endpoint.

  Documents one endpoint (ESDM command or query) for direct usage in the
  Bruno collection at the repo root:

  * `bruno/<Subdomain>/<Composite>/<Constituent>/<Operation Title>.yml`

  Content follows the blueprint: the verb rule (POST commands, GET queries),
  `{{apiUrl}}`-templated URLs (collection variables live in
  `bruno/environments/`), JSON:API bodies mirroring the operation data
  (`create` carries attributes only — the id is generated; `update`/`delete`
  address the row by `id`), and `examples:` generated from the domain
  model's feature scenarios. Commands sort before queries via `seq:`
  (assignment order — run command generators first).

  Docs artifacts are create-only: existing files are never rewritten, so
  hand-tuned responses and extra examples survive every run.
  """

  use SpGen.Blueprint

  alias SpGen.Blueprint.Controller

  @dir "bruno/<Subdomain>/<Composite>/<Constituent>"
  @sample_id "d290f1ee-6c54-4b01-90e6-d701748f0851"

  def name, do: :bruno
  def source_kinds, do: [:command, :query]
  def layer, do: :web

  def plans(%Context{} = ctx) do
    [request_plan(ctx)]
  end

  # ------------------------------------------------------------ request file

  defp request_plan(ctx) do
    path =
      Context.render("#{@dir}/<Operation Title>.yml", ctx, %{}, %{
        "Operation Title" => operation_title(ctx)
      })

    %FilePlan{
      path: path,
      module: nil,
      scaffold: fn c -> request_scaffold(c, path) end,
      units: [],
      format: false
    }
  end

  defp request_scaffold(ctx, path) do
    route = route(ctx)

    """
    info:
      name: #{operation_title(ctx)}
      type: http
      seq: #{request_seq(ctx, path)}

    http:
    #{http_block(ctx, route)}

    settings:
      encodeUrl: true
      timeout: 0
      followRedirects: true
      maxRedirects: 5
    #{examples_block(ctx)}
    """
    |> String.trim_trailing()
    |> Kernel.<>("\n")
  end

  defp http_block(ctx, route) do
    method = if ctx.element.kind == :command, do: "POST", else: "GET"

    "  method: #{method}\n" <>
      "  url: \"{{apiUrl}}#{route}\"\n" <>
      request_block(ctx) <>
      "  auth: inherit"
  end

  defp request_block(ctx) do
    case ctx.element.kind do
      :command ->
        body = body_json(ctx, scenario_data(ctx)) |> indent(6)

        "  body:\n    type: json\n    data: |-\n#{body}\n"

      :query ->
        if Context.collection?(ctx) do
          ""
        else
          param = Context.read_param(ctx)

          "  params:\n    - name: #{param}\n      value: #{@sample_id}\n      type: path\n"
        end
    end
  end

  # JSON:API body: type, id (update/delete), attributes (visible fields)
  @doc false
  def body_json(ctx, data) do
    inner = ["    \"type\": \"#{ctx.constituent}\""]

    inner =
      if ctx.element.kind == :command and ctx.operation in [:update, :delete] do
        inner ++ ["    \"id\": \"#{Map.get(data, "id", @sample_id)}\""]
      else
        inner
      end

    case Enum.reject(ctx.fields, &(&1.internal or &1.name == "id")) do
      [] ->
        wrap(inner)

      attrs ->
        attr_lines =
          attrs
          |> Enum.map(fn f -> "      \"#{f.name}\": #{json_str(value(data, f))}" end)
          |> Enum.join(",\n")

        wrap(inner ++ ["    \"attributes\": {\n#{attr_lines}\n    }"])
    end
  end

  defp wrap(lines), do: "{\n  \"data\": {\n" <> Enum.join(lines, ",\n") <> "\n  }\n}"

  defp value(data, f), do: Map.get(data, f.name) || "sample-#{f.name}"

  defp json_str(value) when is_binary(value), do: inspect(value)
  defp json_str(value), do: inspect(to_string(value))

  defp scenario_data(ctx) do
    case ctx.scenarios do
      [%{"when" => %{"data" => data}} | _] when map_size(data) > 0 -> data
      _ -> %{}
    end
  end

  # ---------------------------------------------------------------- examples

  defp examples_block(ctx) do
    scenarios = if ctx.scenarios == [], do: [%{"name" => ctx.element.name}], else: ctx.scenarios

    entries =
      scenarios
      |> Enum.map(&example_entry(ctx, &1))
      |> Enum.join("")

    "\nexamples:\n" <> entries
  end

  defp example_entry(ctx, scenario) do
    data = get_in(scenario, ["when", "data"]) || %{}
    method = if ctx.element.kind == :command, do: "POST", else: "GET"

    request =
      case ctx.element.kind do
        :command ->
          body = body_json(ctx, data) |> indent(10)

          "    request:\n      url: \"{{apiUrl}}#{route(ctx)}\"\n      method: #{method}\n" <>
            "      body:\n        type: json\n        data: |-\n#{body}\n"

        :query ->
          "    request:\n      url: \"{{apiUrl}}#{example_route(ctx, data)}\"\n      method: #{method}\n"
      end

    "  - name: #{example_name(ctx, scenario, data)}\n#{request}"
  end

  defp example_route(ctx, data) do
    if ctx.element.kind == :query and not Context.collection?(ctx) do
      param = Context.read_param(ctx)
      value = Map.get(data, param) || Map.get(data, "id") || @sample_id
      String.replace(route(ctx), ":#{param}", to_string(value))
    else
      route(ctx)
    end
  end

  defp example_name(ctx, scenario, data) do
    cond do
      is_map_key(data, "title") ->
        "#{action_word(ctx)} #{data["title"]}"

      is_binary(scenario["description"]) ->
        scenario["description"]

      true ->
        scenario["name"]
        |> to_string()
        |> String.split("-")
        |> Enum.map(&String.capitalize/1)
        |> Enum.join(" ")
    end
  end

  defp action_word(ctx) do
    ctx.element.name |> String.split("-") |> hd() |> String.capitalize()
  end

  defp indent(text, width) do
    pad = String.duplicate(" ", width)

    text
    |> String.split("\n")
    |> Enum.map(fn line -> pad <> line end)
    |> Enum.join("\n")
  end

  # --------------------------------------------------------------------- seq

  defp request_seq(ctx, path) do
    dir = ctx.repo_root && Path.join(ctx.repo_root, Path.dirname(path))

    existing =
      with true <- dir && File.dir?(dir),
           {:ok, files} <- File.ls(dir) do
        files |> Enum.filter(&String.ends_with?(&1, ".yml")) |> Enum.reject(&(&1 == "folder.yml"))
      else
        _ -> []
      end

    length(existing) + 1
  end

  # -------------------------------------------------------------------- text

  defp operation_title(ctx) do
    ctx.element.name |> String.split("-") |> Enum.map(&String.capitalize/1) |> Enum.join(" ")
  end

  defp route(ctx) do
    base = Controller.collection_path(ctx)

    case {ctx.element.kind, ctx.operation} do
      {:command, _} ->
        "#{base}/#{ctx.element.name}"

      {:query, _} ->
        if Context.collection?(ctx), do: base, else: "#{base}/:#{Context.read_param(ctx)}"
    end
  end
end
