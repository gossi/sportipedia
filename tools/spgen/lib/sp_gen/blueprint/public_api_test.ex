defmodule SpGen.Blueprint.PublicAPITest do
  @moduledoc """
  The public API's contribution to the operation test file: a
  `describe "Public API - <operation>"` block exercising the port's happy
  path and failure contract.
  """

  use SpGen.Blueprint

  alias SpGen.Templates
  alias SpGen.Blueprint.OperationTest

  @test_path "services/api/test/sportipedia/<_subdomain>/<composite>/<domain_object>/operation/<_operation>_test.exs"
  @test_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Operation.<Operation>Test"

  def plans(%Context{} = ctx) do
    [
      OperationTest.plan(ctx,
        path: @test_path,
        module: @test_module,
        alias_templates: [],
        describes: [{"Public API - <_operation>", &describe_body/2}]
      )
    ]
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
