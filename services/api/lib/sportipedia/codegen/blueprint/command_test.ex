defmodule Sportipedia.Codegen.Blueprint.CommandTest do
  @moduledoc """
  The command's contribution to the operation test file
  (`operation-test.md`): a `describe "<Command> command"` block validating
  the struct's enforced fields (id always; required data fields per the
  command template).
  """

  use Sportipedia.Codegen.Blueprint

  alias Sportipedia.Codegen.Templates
  alias Sportipedia.Codegen.Blueprint.{Command, OperationTest}

  @test_path "services/api/test/sportipedia/<_subdomain>/<composite>/<domain_object>/operation/<_operation>_test.exs"
  @test_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Operation.<Command>Test"

  def plans(%Context{} = ctx) do
    [
      OperationTest.plan(ctx,
        path: @test_path,
        module: @test_module,
        alias_templates: [Command.module_template()],
        describes: [{"<Command> command", &describe_body/2}]
      )
    ]
  end

  @doc false
  def describe_body(ctx, subject) do
    cmd = Context.render("<Command>", ctx)

    tests =
      [requires_id_test(cmd)] ++
        id_nil_test(cmd) ++
        presence_tests(ctx, cmd)

    """
    describe "#{subject}" do
    #{tests |> Enum.join("\n\n") |> Templates.indent(2)}
    end
    """
  end

  defp requires_id_test(cmd) do
    """
    test "requires id" do
      assert_raise ArgumentError, fn ->
        struct!(#{cmd}, %{})
      end
    end
    """
  end

  defp id_nil_test(cmd) do
    [
      """
      test "id cannot be nil" do
        cmd = %#{cmd}{id: nil}

        assert_raise ArgumentError, fn ->
          Vex.validate(cmd)
        end
      end
      """
    ]
  end

  defp presence_tests(ctx, cmd) do
    ctx.fields
    |> Enum.filter(&(&1.required and &1.name != "id"))
    |> Enum.map(fn f ->
      body =
        ctx.fields
        |> Enum.reject(&(&1.name == f.name))
        |> Enum.map(fn x -> "#{x.name}: #{Templates.sample_value(ctx, x)}" end)
        |> Enum.join(", ")

      """
      test "validates presence of #{f.name}" do
        cmd = %#{cmd}{#{body}, #{f.name}: nil}

        assert {:error, _errors} = Vex.validate(cmd)
      end
      """
    end)
  end
end
