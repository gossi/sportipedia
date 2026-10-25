defmodule Sportipedia.Codegen.Blueprint.PolicyTest do
  @moduledoc """
  The policy's contribution to the operation test file: a
  `describe "Policy - <operation>"` block asserting the guest and user
  outcomes of the operation's action.
  """

  use Sportipedia.Codegen.Blueprint

  alias Sportipedia.Codegen.Templates
  alias Sportipedia.Codegen.Blueprint.OperationTest

  @test_path "services/api/test/sportipedia/<_subdomain>/<composite>/<domain_object>/operation/<_operation>_test.exs"
  @test_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Operation.<Operation>Test"

  def plans(%Context{} = ctx) do
    [
      OperationTest.plan(ctx,
        path: @test_path,
        module: @test_module,
        alias_templates: [],
        describes: [{"Policy - <_operation>", &describe_body/2, ["Policy"]}]
      )
    ]
  end

  @doc false
  def describe_body(ctx, subject) do
    policy = Context.render("<DomainObject>Policy", ctx)
    action = Context.op_snake(ctx)
    guest = if guest_allowed?(ctx), do: ":ok", else: ":error"

    tests = [
      """
      test "denies or allows guests for #{action}" do
        assert #{policy}.authorize(:#{action}, %{role: "guest"}, %{}) == #{guest}
      end
      """,
      """
      test "allows users for #{action}" do
        assert #{policy}.authorize(:#{action}, %{role: "user"}, %{}) == :ok
      end
      """
    ]

    """
    describe "#{subject}" do
    #{tests |> Enum.join("\n\n") |> Templates.indent(2)}
    end
    """
  end

  defp guest_allowed?(ctx) do
    # same rule as the Policy blueprint's clause shape
    "guest" in ctx.actors
  end
end
