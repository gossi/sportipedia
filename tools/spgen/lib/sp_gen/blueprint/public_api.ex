defmodule SpGen.Blueprint.PublicAPI do
  @moduledoc """
  Executable transfer of `docs/architecture/blueprints/backend/domain/public-api.md`
  — the public API (port) file itself.

  The constituent's port: exactly one function per operation. The function
  body follows what the operation does:

  * `create` — generate the UUID, dispatch, return the projected read model
  * `update` — dispatch with the given id, return the read model
  * `delete` — dispatch, return `:ok` (no read model follows)
  * `read` — internal API lookup (`oneOf` parameters → id-or-slug chain)
  * `collection` — `Repo.all` with the JSON:API `QueryBuilder`

  Commands return validation failures classified via `ErrorClassifier`
  (Vex runs as commanded middleware — no rescue, no param matching).
  """

  use SpGen.Blueprint

  alias SpGen.Blueprint.{Command, InternalAPI, ReadModel}

  @path "services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/public_api.ex"
  @module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>"
  @read_model_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>ReadModel"
  @internal_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Internal"
  @command_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Command.<Command>"
  @app_module "Sportipedia.<Subdomain>"

  def name, do: :public_api
  def source_kinds, do: [:command, :query]

  @doc "The public API's file path (used as a `requires` gate)."
  @spec module_file(Context.t()) :: String.t()
  def module_file(%Context{} = ctx), do: Context.render(@path, ctx)
  def operations, do: [:create, :update, :delete, :read, :collection]
  def optional_template?, do: true

  def plans(%Context{} = ctx) do
    [
      %FilePlan{
        path: Context.render(@path, ctx),
        module: Context.render(@module, ctx),
        units: units(ctx),
        unit_created: true
      }
    ]
  end

  @doc false
  def aliases(ctx) do
    base = [
      "alias Sportipedia.Architecture",
      "alias #{Context.render(@app_module, ctx)}"
    ]

    cond do
      ctx.element.kind == :command and ctx.operation == :delete ->
        base ++
          [
            "alias #{Context.render(@command_module, ctx)}",
            "alias Sportipedia.Support.ErrorClassifier"
          ]

      ctx.element.kind == :command ->
        base ++
          [
            "alias #{Context.render(@command_module, ctx)}",
            "alias #{Context.render(@internal_module, ctx)}",
            "alias Sportipedia.Support.ErrorClassifier",
            "alias #{Context.render(@read_model_module, ctx)}"
          ]

      Context.collection?(ctx) ->
        base ++
          [
            "alias #{Context.render(@read_model_module, ctx)}",
            "alias #{Context.render("Sportipedia.<Subdomain>.Repo", ctx)}",
            "alias Sportipedia.Support.JSONAPI.QueryBuilder"
          ]

      true ->
        base ++
          [
            "alias #{Context.render(@internal_module, ctx)}",
            "alias #{Context.render(@read_model_module, ctx)}"
          ]
    end
    |> Enum.uniq()
  end

  @doc "The operation's function (doc + spec + body)."
  @spec body(Context.t()) :: String.t()
  def body(ctx) do
    op = Context.op_snake(ctx)
    doc = "TODO: describe #{ctx.element.name}"
    doc = ctx.element.doc["description"] || doc

    case {ctx.element.kind, ctx.operation} do
      {:command, :create} ->
        create(ctx, op, doc)

      {:command, :update} ->
        update(ctx, op, doc)

      {:command, :delete} ->
        delete(ctx, op, doc)

      {:query, _} ->
        if Context.collection?(ctx), do: collection(ctx, op, doc), else: read(ctx, op, doc)
    end
  end

  defp app(ctx), do: Context.pascal(ctx.subdomain)
  defp internal(ctx), do: Context.pascal(ctx.constituent) <> "Internal"
  defp read_model(ctx), do: Context.pascal(ctx.constituent) <> "ReadModel"
  defp command(ctx), do: Context.pascal(ctx.element.name)

  defp create(ctx, op, doc) do
    """
    @doc \"\"\"
    #{doc}
    \"\"\"
    @spec #{op}(#{spec_map(ctx, false)}) :: Architecture.public_api(#{read_model(ctx)}.t())
    def #{op}(params) do
      id = UUID.uuid4()
      cmd = #{command(ctx)}.new(Map.put(params, "id", id))

      case #{app(ctx)}.dispatch(cmd, consistency: :strong) do
        :ok ->
          {:ok, #{internal(ctx)}.#{ctx.constituent}_by_id(id)}

        {:error, errors} ->
          ErrorClassifier.classify_error(errors)
      end
    end
    """
  end

  defp update(ctx, op, doc) do
    """
    @doc \"\"\"
    #{doc}
    \"\"\"
    @spec #{op}(#{spec_map(ctx, true)}) :: Architecture.public_api(#{read_model(ctx)}.t())
    def #{op}(params) do
      case #{app(ctx)}.dispatch(#{command(ctx)}.new(params), consistency: :strong) do
        :ok ->
          {:ok, #{internal(ctx)}.#{ctx.constituent}_by_id(params[:id] || params["id"])}

        {:error, errors} ->
          ErrorClassifier.classify_error(errors)
      end
    end
    """
  end

  defp delete(ctx, op, doc) do
    """
    @doc \"\"\"
    #{doc}
    \"\"\"
    @spec #{op}(String.t()) :: Architecture.public_api()
    def #{op}(id) do
      case #{app(ctx)}.dispatch(#{command(ctx)}.new(id: id), consistency: :strong) do
        :ok -> :ok
        {:error, errors} -> ErrorClassifier.classify_error(errors)
      end
    end
    """
  end

  defp read(ctx, op, doc) do
    param = Context.read_param(ctx)
    do_ = ctx.constituent

    lookup =
      if param =~ "_or_" do
        [id_part, slug_part] = String.split(param, "_or_")

        """
        case #{internal(ctx)}.#{do_}_by_#{id_part}(#{param}) do
          nil -> #{internal(ctx)}.#{do_}_by_#{slug_part}(#{param})
          read_model -> read_model
        end
        """
      else
        "#{internal(ctx)}.#{do_}_by_id(#{param})"
      end

    """
    @doc \"\"\"
    #{doc}
    \"\"\"
    @spec #{op}(String.t()) :: Architecture.public_api(#{read_model(ctx)}.t())
    def #{op}(#{param}) do
      case #{String.trim(lookup)} do
        nil -> {:error, :not_found}
        read_model -> {:ok, read_model}
      end
    end
    """
  end

  defp collection(ctx, op, doc) do
    """
    @doc \"\"\"
    #{doc}
    \"\"\"
    @spec #{op}(JSONAPI.Config.t()) :: Architecture.public_api([#{read_model(ctx)}.t()])
    def #{op}(query) do
      {:ok, Repo.all(QueryBuilder.build(query, #{read_model(ctx)}))}
    end
    """
  end

  # `%{required(:title) => String.t(), optional(:description) => String.t() | nil}`
  defp spec_map(ctx, include_id?) do
    parts =
      ctx.fields
      |> Enum.filter(fn f -> include_id? or not f.internal end)
      |> Enum.map(fn f ->
        if f.required do
          "required(:#{f.name}) => String.t()"
        else
          "optional(:#{f.name}) => String.t() | nil"
        end
      end)

    "%{" <> Enum.join(parts, ", ") <> "}"
  end

  # which citizen files the operation's body references
  defp body_gate(%Context{element: %{kind: :command}} = c) do
    gates = [{Command.module_file(c), "command not generated (spgen command)"}]

    if c.operation == :delete,
      do: gates,
      else:
        gates ++ [{InternalAPI.module_file(c), "internal API not generated (spgen internal_api)"}]
  end

  defp body_gate(%Context{} = c) do
    [
      {InternalAPI.module_file(c), "internal API not generated (spgen internal_api)"},
      {ReadModel.module_file(c), "read model not generated (spgen read_model)"}
    ]
  end

  # ------------------------------------------------------------------- units

  defp units(ctx) do
    op = Context.op_snake(ctx)

    [
      %Unit{
        id: :moduledoc,
        check: &Source.has_moduledoc?/1,
        render: fn c ->
          "@moduledoc \"\"\"\nPublic API for managing #{c.constituent}s in the #{Context.bounded_context(c)}.\n\"\"\""
        end,
        place: Merge.head(:moduledoc)
      },
      %Unit{
        id: {:def, String.to_atom(op), 1},
        check: fn src -> Source.has_def?(src, String.to_atom(op), 1) end,
        requires: &body_gate/1,
        render: fn c -> c |> body() |> String.trim_trailing() end,
        place: Merge.body_end()
      }
    ] ++
      Enum.map(aliases(ctx), fn alias_line ->
        module = String.replace_prefix(alias_line, "alias ", "")

        %Unit{
          id: {:alias, module},
          check: fn src ->
            Source.has_alias?(src, module) || Source.has_def?(src, String.to_atom(op), 1)
          end,
          render: fn _ctx -> alias_line end,
          place: Merge.alias_of(module)
        }
      end)
  end
end
