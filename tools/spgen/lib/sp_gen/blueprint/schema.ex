defmodule SpGen.Blueprint.Schema do
  @moduledoc """
  Executable transfer of `docs/architecture/blueprints/backend/web/schema.md`
  — the OpenAPI schema module files.

  OpenAPI schemas documenting the endpoints, driven by the element kind:

  * **read model** → `<DomainObject>Response` + `<DomainObject>CollectionResponse`
    (both derived from the JSON:API view via `OpenApiSchema.from_view/2`)
  * **command** (`create`/`update`) → `<Command>Request` derived from the
    command's data fields (the generated id is excluded; `delete` carries no
    request schema — its id rides in the body as `data.id`)
  * **query** (collection) → `<Operation>QueryParams`, derived from the view and
    the query's declared filterable/sortable fields via
    `OpenApiSchema.query_params/2` — the request-side sibling of `from_view/2`,
    so a JSON:API parameter list is stated once and transcribed nowhere

  Every schema module is paired with its own ExUnit test file
  (`SpGen.Blueprint.SchemaTest`).
  """

  use SpGen.Blueprint

  alias SpGen.Blueprint.View

  @dir "services/api/lib/sportipedia_web/<_subdomain>/<composite>/<domain_object>/schemas"
  @ns "SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>.Schemas"
  @view_module "SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>View"
  @open_api_schema "Sportipedia.Support.JSONAPI.OpenApiSchema"

  def name, do: :schema
  def source_kinds, do: [:"read-model", :command, :query]
  def actor, do: :web

  @doc "The schema module's file path for one role (used as a `requires` gate)."
  @spec module_file(Context.t(), atom()) :: String.t()
  def module_file(%Context{} = ctx, which) do
    n = names(ctx, which)
    Context.render("#{@dir}/" <> n[:stem] <> ".ex", ctx)
  end

  def operations, do: [:create, :update, :delete, :none, :read, :collection]
  def optional_template?, do: true

  def plans(%Context{} = ctx) do
    Enum.map(whiches(ctx), fn which -> plan(ctx, which) end)
  end

  @doc "The schema roles this element generates files for."
  @spec whiches(Context.t()) :: [atom()]
  def whiches(%Context{} = ctx) do
    case {ctx.element.kind, ctx.operation} do
      {:"read-model", _} ->
        [:response, :collection_response]

      {:command, op} when op in [:create, :update, :none] ->
        [:request]

      {:query, _} ->
        if Context.collection?(ctx) and ctx.element.doc["parameters"],
          do: [:query_params],
          else: []

      _ ->
        []
    end
  end

  # ------------------------------------------------------------- definitions

  defp spec(:response),
    do: {"<domain_object>_response", "<DomainObject>Response", "<composite>.<DomainObject>"}

  defp spec(:collection_response),
    do:
      {"<domain_object>_collection_response", "<DomainObject>CollectionResponse",
       "<composite>.<DomainObject>s"}

  defp spec(:request),
    do: {"<_operation>_request", "<Command>Request", "<composite>.<Command>Request"}

  defp spec(:query_params),
    do:
      {"<_operation>_query_params", "<Operation>QueryParams",
       "<composite>.<Operation>QueryParams"}

  @doc "Stem/short/full/title names for one schema role."
  @spec names(Context.t(), atom()) :: %{
          stem: String.t(),
          short: String.t(),
          full: String.t(),
          title: String.t()
        }
  def names(ctx, which) do
    {stem_tpl, module_tpl, title_tpl} = spec(which)

    %{
      stem: Context.render(stem_tpl, ctx),
      short: Context.render(module_tpl, ctx),
      full: Context.render("#{@ns}.#{module_tpl}", ctx),
      title: Context.render(title_tpl, ctx)
    }
  end

  # ------------------------------------------------------------ plan: module

  defp plan(ctx, which) do
    n = names(ctx, which)

    %FilePlan{
      path: module_file(ctx, which),
      module: n[:full],
      units: units(ctx, which, n),
      unit_created: true
    }
  end

  defp moduledoc(ctx, which) do
    case which do
      :response ->
        "OpenAPI schema for documenting #{ctx.constituent} endpoints."

      :collection_response ->
        "OpenAPI schema for documenting #{ctx.constituent} collection endpoints."

      :request ->
        "OpenAPI schema for documenting the #{ctx.element.name} request parameters."

      :query_params ->
        "OpenAPI schema for documenting #{ctx.element.name} collection query parameters."
    end
  end

  # ------------------------------------------------------------------ bodies

  # A body renders its own code and nothing else: the `require` and the `alias`
  # lines are units of this plan, and repeating them inside the body would make
  # every created schema file carry its header twice.
  defp body(ctx, which, n) when which in [:response, :collection_response] do
    view_short = Context.pascal(ctx.constituent) <> "View"
    many = if which == :collection_response, do: ", many: true", else: ""
    what = if which == :response, do: "response", else: "collection response"

    """
    @doc \"\"\"
    Returns the OpenAPI schema for the #{ctx.constituent} #{what}.
    \"\"\"
    OpenApiSpex.schema(
      OpenApiSchema.from_view(#{view_short}, title: "#{n[:title]}"#{many})
    )
    """
  end

  defp body(ctx, :request, n) do
    fields = Enum.reject(ctx.fields, & &1.internal)

    props =
      fields
      |> Enum.map(fn f ->
        nullable = if f.required, do: "", else: ", nullable: true"

        "      #{f.name}: %OpenApiSpex.Schema{type: #{openapi_type(f)}#{nullable}, " <>
          "description: #{inspect(f.description || "The #{f.name}")}}"
      end)
      |> Enum.join(",\n")

    required =
      fields
      |> Enum.filter(& &1.required)
      |> Enum.map(&":#{&1.name}")

    required_line =
      if required == [], do: "", else: ",\n      required: [#{Enum.join(required, ", ")}]"

    """
    @doc \"\"\"
    Returns the OpenAPI schema for the #{ctx.element.name} request.
    \"\"\"
    OpenApiSpex.schema(%{
      title: "#{n[:title]}",
      type: :object,
      properties: %{
    #{props}
      }#{required_line}
    })
    """
  end

  defp body(ctx, :query_params, n) do
    view_short = Context.pascal(ctx.constituent) <> "View"

    options =
      [
        "      title: #{inspect(n[:title])}"
      ] ++
        filter_option(ctx) ++
        sort_option(ctx) ++
        ["      page: :#{Context.page_style(ctx)}"]

    """
    @doc \"\"\"
    Returns the OpenAPI schema for the #{ctx.element.name} collection query parameters.
    \"\"\"
    OpenApiSpex.schema(
      OpenApiSchema.query_params(#{view_short},
    #{Enum.join(options, ",\n")}
      )
    )
    """
  end

  # the members the model names nothing for are not documented — a collection
  # that filters by nothing has no `filter` parameter to promise
  defp filter_option(%Context{} = ctx) do
    filters =
      ctx
      |> Context.query_parameters()
      |> get_in(["filter", "properties"])
      |> Kernel.||(%{})
      |> Enum.map(fn {name, spec} ->
        desc = spec["description"] || "Filter #{ctx.constituent} by #{name} (partial match)"
        "#{name}: #{inspect(desc)}"
      end)

    if filters == [], do: [], else: ["      filter: [#{Enum.join(filters, ", ")}]"]
  end

  defp sort_option(%Context{} = ctx) do
    case Context.sortable_fields(ctx) do
      [] -> []
      fields -> ["      sort: ~w(#{Enum.join(fields, " ")})"]
    end
  end

  defp openapi_type(%{type: "string"}), do: ":string"
  defp openapi_type(%{type: "integer"}), do: ":integer"
  defp openapi_type(%{type: "number"}), do: ":number"
  defp openapi_type(%{type: "boolean"}), do: ":boolean"
  defp openapi_type(_), do: ":string"

  # ------------------------------------------------------------------ units

  defp units(ctx, which, n) do
    view_gate = fn c -> [{View.module_file(c), "view not generated (spgen view)"}] end

    [
      %Unit{
        id: :moduledoc,
        check: &Source.has_moduledoc?/1,
        render: fn c -> "@moduledoc \"\"\"\n#{moduledoc(c, which)}\n\"\"\"" end,
        place: Merge.head(:moduledoc)
      },
      %Unit{
        id: {:require, "OpenApiSpex"},
        check: fn src -> Source.has_require?(src, "OpenApiSpex") end,
        render: fn _ctx -> "require OpenApiSpex" end,
        place: Merge.head(:require)
      }
    ] ++
      alias_units(ctx, which) ++
      [
        %Unit{
          id: :schema_body,
          check: fn src -> derived_body_present?(src, which) end,
          stale: fn src, c -> stale_derivation(src, c, which) end,
          render: fn c -> body(c, which, n) |> String.trim_trailing() end,
          # every derived body names the view: the response builds its document
          # from it, a collection's parameters are keyed by its type and fields
          requires:
            if(which in [:response, :collection_response, :query_params],
              do: view_gate,
              else: fn _c -> [] end
            ),
          place: Merge.body_end()
        }
      ]
  end

  # A derived schema is present only when it *derives*: a hand-written literal
  # that spells out the members reads as the same line to the merge, and would
  # then go unreported forever. A transcribed body counts as missing so it
  # reaches `stale`, which reports it and never appends a second call.
  defp derived_body_present?(%Source{text: text}, which) do
    text =~ "OpenApiSpex.schema(" and
      (which not in [:query_params, :response, :collection_response] or
         text =~ derived_call(which))
  end

  # A schema of this blueprint is *derived*: the view owns the resource shape,
  # the model owns the parameter names. A file that transcribes them instead
  # carries the line, so the merge appends nothing — and the report says so,
  # because a transcription is where a field list starts drifting away from the
  # API that validates it. The operator decides who is wrong: the builder, or
  # the model.
  defp stale_derivation(%Source{text: text}, _ctx, which) do
    derived = derived_call(which)

    cond do
      which not in [:query_params, :response, :collection_response] -> []
      not (text =~ "OpenApiSpex.schema(") -> []
      text =~ derived -> []
      true -> ["the schema transcribes what `#{derived}` derives — call the builder"]
    end
  end

  # the aliases a derived body names; a transcribed body names none, and an
  # unused alias is a compile warning this tool must not manufacture
  defp alias_units(ctx, which) when which in [:response, :collection_response, :query_params] do
    derived = derived_call(which)

    [
      alias_unit(Context.render(@view_module, ctx), derived),
      alias_unit(@open_api_schema, derived)
    ]
  end

  defp alias_units(_ctx, _which), do: []

  defp alias_unit(module, derived) do
    gate =
      if module == "Sportipedia.Support.JSONAPI.OpenApiSchema" do
        fn _c -> [] end
      else
        fn c -> [{View.module_file(c), "view not generated (spgen view)"}] end
      end

    %Unit{
      id: {:alias, module},
      check: fn src -> Source.has_alias?(src, module) or transcribed?(src, derived) end,
      render: fn _ctx -> "alias #{module}" end,
      requires: gate,
      place: Merge.alias_of(module)
    }
  end

  # a body that spells its schema out by hand: the line is there, the call the
  # aliases belong to is not — `stale_derivation/3` is what reports it
  defp transcribed?(%Source{text: text}, derived),
    do: text =~ "OpenApiSpex.schema(" and not (text =~ derived)

  defp derived_call(:query_params), do: "OpenApiSchema.query_params("
  defp derived_call(_which), do: "OpenApiSchema.from_view("
end
