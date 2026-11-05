defmodule SpGen.Blueprint.CommandTest do
  @moduledoc """
  The command's contribution to the operation test file
  (`operation-test.md`): a `describe "Command"` block validating the struct's
  enforced fields (id always; required data fields per the command template).
  """

  use SpGen.Blueprint

  alias SpGen.Templates
  alias SpGen.Blueprint.{Command, TestCaseFile}

  @test_path "services/api/test/sportipedia/<_subdomain>/<composite>/<domain_object>/operations/<_operation>_test.exs"
  @test_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Operation.<Command>Test"

  def plans(%Context{} = ctx) do
    [
      TestCaseFile.plan(ctx,
        path: @test_path,
        module: @test_module,
        alias_templates: [Command.module_template()],
        requires: fn c -> [{Command.module_file(c), "command not generated (spgen command)"}] end,
        describes: [{"Command", &describe_body/2, ["<Command> command"]}]
      )
    ]
  end

  @doc false
  def describe_body(ctx, subject) do
    cmd = Context.render("<Command>", ctx)

    # the nil-id test is meaningful only when a validator looks the id up:
    # `Repo.get(_, nil)` raises; a plain presence check would not
    nil_id = if exists_by_id?(ctx), do: id_nil_test(ctx, cmd), else: []

    tests =
      [requires_id_test(cmd)] ++
        nil_id ++
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

  # every enforced field must be present; only the id is nil
  defp id_nil_test(ctx, cmd) do
    body =
      ctx.fields
      |> Enum.reject(&(&1.name == "id"))
      |> Enum.map(fn f -> "#{f.name}: #{Templates.sample_value(ctx, f)}" end)
      |> Enum.join(", ")

    literal = if body == "", do: "id: nil", else: "#{body}, id: nil"

    [
      """
      test "id cannot be nil" do
        cmd = %#{cmd}{#{literal}}

        assert_raise ArgumentError, fn ->
          Vex.validate(cmd)
        end
      end
      """
    ]
  end

  defp exists_by_id?(%Context{} = ctx) do
    Enum.any?(ctx.validators, fn v -> v.kind == :exists and v.field == "id" end)
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
