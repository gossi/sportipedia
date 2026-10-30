defmodule SpGen.Blueprint.Policy do
  @moduledoc """
  Executable transfer of `docs/architecture/blueprints/backend/domain/policy.md`
  — the policy file itself.

  Adds the operation's `authorize/3` clause(s) to the constituent's policy
  (created when missing). Clause shape follows the domain model's `actors`:

  * guests among the actors → one open clause (`_user`, `:ok`)
  * guests not allowed → the deny/allow guard pair (`is_guest?` → `:error`,
    `is_user?` → `:ok`), using the shared guards from `Sportipedia.Auth`
  """

  use SpGen.Blueprint

  alias SpGen.Templates

  @path "services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/policy.ex"
  @module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Policy"

  def name, do: :policy
  def source_kinds, do: [:command, :query]

  @doc "The policy's file path (used as a `requires` gate)."
  @spec module_file(Context.t()) :: String.t()
  def module_file(%Context{} = ctx), do: Context.render(@path, ctx)

  def plans(%Context{} = ctx) do
    [
      %FilePlan{
        path: Context.render(@path, ctx),
        module: Context.render(@module, ctx),
        scaffold: &scaffold/1,
        units: units(ctx)
      }
    ]
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
        place: Merge.head(:moduledoc)
      },
      %Unit{
        id: {:behaviour, "Bodyguard.Policy"},
        check: fn src -> Source.has_behaviour?(src, "Bodyguard.Policy") end,
        render: fn _ctx -> "@behaviour Bodyguard.Policy" end,
        place: Merge.head(:attribute)
      },
      %Unit{
        id: {:import, "Sportipedia.Auth.Roles"},
        check: fn src -> Source.has_import?(src, "Sportipedia.Auth.Roles") end,
        render: fn _ctx -> "import Sportipedia.Auth.Roles" end,
        place: Merge.head(:import)
      },
      %Unit{
        id: {:authorize, action},
        check: fn src -> Source.def_head_has?(src, :authorize, 3, action) end,
        render: fn c -> clauses(c) end,
        place: Merge.after_def(:authorize, 3)
      }
    ]
  end
end
