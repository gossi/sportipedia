defmodule SpGen.Blueprint.PolicyTest do
  @moduledoc """
  The policy's contribution to the operation test file: a
  `describe "Policy"` block asserting the guest and user outcomes of the
  operation's action.
  """

  use SpGen.Blueprint

  alias SpGen.Templates
  alias SpGen.Blueprint.{TestCaseFile, Policy}

  @test_path "services/api/test/sportipedia/<_subdomain>/<composite>/<domain_object>/operations/<_operation>_test.exs"
  @test_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Operation.<Operation>Test"

  def plans(%Context{} = ctx) do
    [
      TestCaseFile.plan(ctx,
        path: @test_path,
        module: @test_module,
        alias_templates: [Policy.module_template()],
        requires: fn c -> [{Policy.module_file(c), "policy not generated (spgen policy)"}] end,
        describes: [{"Policy", &describe_body/2, ["Policy - <_operation>"]}]
      )
    ]
  end

  @doc false
  def describe_body(ctx, subject) do
    # the alias brings `Policy` into scope (golden shape)
    policy = "Policy"
    action = Context.op_snake(ctx)
    guest = if guest_allowed?(ctx), do: ":ok", else: ":error"

    tests =
      if Policy.admin_only?(ctx) do
        [
          """
          test "denies or allows guests for #{action}" do
            assert #{policy}.authorize(:#{action}, nil, %{}) == #{guest}
          end
          """,
          """
          test "denies an authenticated user who is not an admin for #{action}" do
            assert #{policy}.authorize(:#{action}, %{id: UUID.uuid4(), role: "user"}, %{}) == :error
          end
          """,
          """
          test "allows admins for #{action}" do
            assert #{policy}.authorize(:#{action}, %{id: UUID.uuid4(), role: "admin"}, %{}) == :ok
          end
          """
        ]
      else
        [
          """
          test "denies or allows guests for #{action}" do
            assert #{policy}.authorize(:#{action}, nil, %{}) == #{guest}
          end
          """,
          """
          test "allows users for #{action}" do
            assert #{policy}.authorize(:#{action}, %{id: UUID.uuid4(), role: "user"}, %{}) == :ok
          end
          """
        ]
      end

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
