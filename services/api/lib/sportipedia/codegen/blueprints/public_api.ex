defmodule Sportipedia.Codegen.Blueprints.PublicAPI do
  @moduledoc """
  Executable transfer of `docs/architecture/blueprints/backend/domain/public-api.md`.

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

  use Sportipedia.Codegen.Blueprint

  alias Sportipedia.Codegen.{Context, FilePlan, Source, Templates, Unit}
  alias Sportipedia.Codegen.Blueprints.OperationTestFile

  @path "services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/public_api.ex"
  @module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>"
  @read_model_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>ReadModel"
  @internal_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Internal"
  @command_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Command.<Command>"
  @app_module "Sportipedia.<Subdomain>"
  @test_path "services/api/test/sportipedia/<_subdomain>/<composite>/<domain_object>/operation/<_operation>_test.exs"
  @test_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Operation.<Operation>Test"

  def name, do: :public_api
  def source_kinds, do: [:command, :query]
  def operations, do: [:create, :update, :delete, :read, :collection]
  def optional_template?, do: true

  def plans(%Context{} = ctx) do
    [public_api_file(ctx), test_plan(ctx)]
  end

  defp public_api_file(ctx) do
    %FilePlan{
      path: Context.render(@path, ctx),
      role: :module,
      module: Context.render(@module, ctx),
      scaffold: &scaffold/1,
      units: units(ctx)
    }
  end

  defp scaffold(ctx) do
    """
    defmodule #{Context.render(@module, ctx)} do
      @moduledoc \"\"\"
      Public API for managing #{ctx.constituent}s in the #{Context.bounded_context(ctx)}.
      \"\"\"

      alias Sportipedia.Architecture
    #{aliases(ctx) |> Enum.map(&("  " <> &1)) |> Enum.join("\n")}

    #{body(ctx) |> String.trim_trailing() |> Templates.indent(2)}
    end
    """
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
        anchor: fn src, _ctx -> {:after_line, Source.module_start_line(src)} end
      },
      %Unit{
        id: {:def, String.to_atom(op), 1},
        check: fn src -> Source.has_def?(src, String.to_atom(op), 1) end,
        render: fn c -> c |> body() |> String.trim_trailing() |> Templates.indent(2) end,
        anchor: fn src, _ctx -> Source.module_end_anchor(src) end
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
          anchor: fn src, _ctx -> Source.alias_anchor(src, module) end,
          gap: :tight
        }
      end)
  end

  # -------------------------------------------------------------------- test

  defp test_plan(ctx) do
    OperationTestFile.plan(ctx,
      path: @test_path,
      module: @test_module,
      alias_templates: [],
      describes: [{"Public API - <_operation>", &describe_body/2}]
    )
  end

  @doc false
  def describe_body(ctx, subject) do
    api = Context.pascal(ctx.constituent)
    op = Context.op_snake(ctx)
    body = Templates.struct_body(ctx)

    tests =
      case ctx.element.kind do
        :command ->
          [
            """
            test "#{op} succeeds" do
              assert {:ok, read_model} = #{api}.#{op}(#{param_expr(ctx, body)})

              assert read_model.id != nil
            end
            """,
            """
            test "#{op} returns validation errors" do
              assert {:error, {:validation_failure, _errors}} = #{api}.#{op}(%{})
            end
            """
          ]

        :query ->
          if Context.collection?(ctx) do
            [
              """
              test "#{op} lists read models" do
                assert {:ok, data} = #{api}.#{op}(JSONAPI.Config.parse_params!(%{"filter" => %{}, "sort" => [], "page" => %{}}))

                assert is_list(data)
              end
              """
            ]
          else
            [
              """
              test "#{op} returns :not_found for unknown #{ctx.constituent}" do
                assert {:error, :not_found} = #{api}.#{op}(UUID.uuid4())
              end
              """
            ]
          end
      end

    """
    describe "#{subject}" do
    #{tests |> Enum.join("\n\n") |> Templates.indent(2)}
    end
    """
  end

  defp param_expr(ctx, body) do
    case ctx.operation do
      :delete -> "id"
      _ -> "%{#{body}}"
    end
  end
end
