defmodule SpGen.Blueprint.PublicAPITest do
  @moduledoc """
  The public API's contribution to the operation test file: a
  `describe "Public API"` block exercising the port's happy path and failure
  contract.
  """

  use SpGen.Blueprint

  alias SpGen.{Esdm, Templates}
  alias SpGen.Blueprint.{TestCaseFile, PublicAPI}

  @test_path "services/api/test/sportipedia/<_subdomain>/<composite>/<domain_object>/operations/<_operation>_test.exs"
  @test_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Operation.<Operation>Test"

  def plans(%Context{} = ctx) do
    [
      TestCaseFile.plan(ctx,
        path: @test_path,
        module: @test_module,
        alias_templates: [PublicAPI.module_template()],
        requires: fn c ->
          [{PublicAPI.module_file(c), "public API not generated (spgen public_api)"}]
        end,
        describes: [{"Public API", &describe_body/2, ["Public API - <_operation>"]}]
      )
    ]
  end

  @doc false
  def describe_body(ctx, subject) do
    api = Context.pascal(ctx.constituent)
    op = Context.op_snake(ctx)
    body = public_params(ctx, ctx.element)

    tests =
      case ctx.element.kind do
        :command ->
          case ctx.operation do
            :delete -> delete_tests(api, op, ctx)
            :none -> none_tests(api, op, ctx, body)
            _ -> command_tests(api, op, ctx, body)
          end

        :query ->
          if Context.collection?(ctx) do
            [
              """
              test "#{op} lists read models" do
                assert {:ok, data} = #{api}.#{op}(%JSONAPI.Config{})

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

  # update and delete address an existing aggregate; the create operation of
  # the same citizen seeds it through the public API
  defp command_tests(api, op, ctx, body) do
    success =
      """
      test "#{op} succeeds" do
        assert {:ok, read_model} = #{api}.#{op}(#{param_expr(ctx, body)})

        assert read_model.id != nil
      end
      """

    validation =
      """
      test "#{op} returns validation errors" do
        assert {:error, {:validation_failure, _errors}} = #{api}.#{op}(%{})
      end
      """

    case ctx.operation do
      :create ->
        [success, validation]

      :update ->
        case create_operation(ctx) do
          nil ->
            [success, validation]

          {create_op, create_body} ->
            [
              """
              test "#{op} succeeds" do
                assert {:ok, created} = #{api}.#{create_op}(#{create_body})

                assert {:ok, read_model} = #{api}.#{op}(%{id: created.id})

                assert read_model.id == created.id
              end
              """
            ]
        end
    end
  end

  defp delete_tests(api, op, ctx) do
    unknown =
      """
      test "#{op} fails for an unknown #{ctx.constituent}" do
        assert {:error, _} = #{api}.#{op}(UUID.uuid4())
      end
      """

    case create_operation(ctx) do
      nil ->
        [unknown]

      {create_op, create_body} ->
        [
          """
          test "#{op} succeeds" do
            assert {:ok, created} = #{api}.#{create_op}(#{create_body})

            assert :ok = #{api}.#{op}(created.id)
          end
          """,
          unknown
        ]
    end
  end

  # a `none` operation dispatches facts that materialize nothing — the answer
  # is the dispatch result itself; no row to seed, none to read back
  defp none_tests(api, op, ctx, body) do
    [
      """
      test "#{op} succeeds" do
        assert :ok = #{api}.#{op}(#{param_expr(ctx, body)})
      end
      """,
      """
      test "#{op} returns validation errors" do
        assert {:error, {:validation_failure, _errors}} = #{api}.#{op}(%{})
      end
      """
    ]
  end

  # the citizen's create operation: `{snake_name, params_literal}`
  defp create_operation(%Context{} = ctx) do
    create =
      Enum.find(ctx.model.elements, fn el ->
        el.kind == :command and
          Esdm.Element.aggregate_name(el) == ctx.constituent and
          Context.derive_operation(ctx.model, el) == :create
      end)

    case create do
      nil -> nil
      el -> {el.name |> String.replace("-", "_"), "%{#{public_params(ctx, el)}}"}
    end
  end

  # public params of a command: the required fields the caller provides;
  # fields a unique rule guards get a fresh value (tests run in one sandbox)
  defp public_params(%Context{} = ctx, element) do
    unique = Context.unique_fields(ctx)

    element
    |> Esdm.fields()
    |> Enum.filter(&(&1.required and &1.name != "id"))
    |> Enum.map(fn f ->
      value =
        if f.name in unique do
          "\"sample-#{f.name}-\#{UUID.uuid4()}\""
        else
          Templates.sample_value(ctx, f)
        end

      "#{f.name}: #{value}"
    end)
    |> Enum.join(", ")
  end
end
