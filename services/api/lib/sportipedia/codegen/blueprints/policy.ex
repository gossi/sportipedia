defmodule Sportipedia.Codegen.Blueprints.Policy do
  @moduledoc """
  Executable transfer of `docs/architecture/blueprints/backend/domain/policy.md`.

  Adds the operation's `authorize/3` clause(s) to the constituent's policy
  (created when missing). Clause shape follows the domain model's `actors`:

  * guests among the actors → one open clause (`_user`, `:ok`)
  * guests not allowed → the deny/allow guard pair (`is_guest?` → `:error`,
    `is_user?` → `:ok`), using the shared guards from `Sportipedia.Auth`
  """

  use Sportipedia.Codegen.Blueprint

  alias Sportipedia.Codegen.{Context, FilePlan, Source, Templates, Unit}
  alias Sportipedia.Codegen.Blueprints.OperationTestFile

  @path "services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/policy.ex"
  @module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Policy"
  @test_path "services/api/test/sportipedia/<_subdomain>/<composite>/<domain_object>/operation/<_operation>_test.exs"
  @test_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Operation.<Operation>Test"

  def name, do: :policy
  def source_kinds, do: [:command, :query]

  def plans(%Context{} = ctx) do
    [policy_file(ctx), test_plan(ctx)]
  end

  defp policy_file(ctx) do
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
      Authorizes #{ctx.constituent} operations based on user roles.
      \"\"\"

      @behaviour Bodyguard.Policy

      import Sportipedia.Auth.Roles

    #{clauses(ctx) |> Templates.indent(2)}
    end
    """
  end

  @doc false
  def clauses(ctx) do
    action = ":#{Context.op_snake(ctx)}"

    if guest_allowed?(ctx) do
      "def authorize(#{action}, _user, _params), do: :ok"
    else
      """
      def authorize(#{action}, user, _params) when is_guest?(user), do: :error
      def authorize(#{action}, user, _params) when is_user?(user), do: :ok
      """
      |> String.trim_trailing()
    end
  end

  defp guest_allowed?(%Context{element: %{kind: :query}} = ctx), do: "guest" in ctx.actors
  defp guest_allowed?(ctx), do: "guest" in ctx.actors

  # ------------------------------------------------------------------- units

  defp units(ctx) do
    action = ":#{Context.op_snake(ctx)}"

    [
      %Unit{
        id: :moduledoc,
        check: &Source.has_moduledoc?/1,
        render: fn c ->
          "@moduledoc \"\"\"\nAuthorizes #{c.constituent} operations based on user roles.\n\"\"\""
        end,
        anchor: fn src, _ctx -> {:after_line, Source.module_start_line(src)} end
      },
      %Unit{
        id: {:behaviour, "Bodyguard.Policy"},
        check: fn src -> Source.has_behaviour?(src, "Bodyguard.Policy") end,
        render: fn _ctx -> "@behaviour Bodyguard.Policy" end,
        anchor: fn src, _ctx -> {:after_line, Source.module_start_line(src)} end
      },
      %Unit{
        id: {:import, "Sportipedia.Auth.Roles"},
        check: fn src -> Source.has_import?(src, "Sportipedia.Auth.Roles") end,
        render: fn _ctx -> "import Sportipedia.Auth.Roles" end,
        anchor: fn src, _ctx ->
          Source.after_entry(
            src,
            :use,
            fn _ -> true end,
            {:after_line, Source.module_start_line(src)}
          )
        end
      },
      %Unit{
        id: {:authorize, action},
        check: fn src -> Source.def_head_has?(src, :authorize, 3, action) end,
        render: fn c -> c |> clauses() |> Templates.indent(2) end,
        anchor: fn src, _ctx -> Source.def_anchor(src, :authorize, 3) end
      }
    ]
  end

  # -------------------------------------------------------------------- test

  defp test_plan(ctx) do
    OperationTestFile.plan(ctx,
      path: @test_path,
      module: @test_module,
      alias_templates: [],
      describes: [{"Policy - <_operation>", &describe_body/2, ["Policy"]}]
    )
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
end
