defmodule SpGen.PolicyClausesTest do
  @moduledoc """
  The policy clause shape the generator derives from the model's `actors`.

  `is_user?/1` is "authenticated" only in the sense of *not a guest*
  (`Sportipedia.Auth.Roles`): an operation whose actor list is `admin` alone
  cannot be generated as `is_user?(user) -> :ok`, or every authenticated user
  would pass an admin-only command. An admin-only list derives the
  `is_admin?` allowance and the explicit denial behind it (policy.md).

  Over the **fixture** model, with the actor list stated by the test rather than
  borrowed from the live tree: the derivation is a function of `actors`, so the
  test owns that one input and everything else stays the fixture's. See
  `tools/spgen/contributions.md`.
  """
  use ExUnit.Case, async: true

  alias SpGen.{Context, Esdm, FixtureRepo}
  alias SpGen.Blueprint.{Policy, PolicyTest}
  alias SpGen.Esdm.Element

  setup_all do
    %{model: FixtureRepo.model()}
  end

  defp ctx(model, %Element{} = element) do
    {:ok, ctx} = Context.build(model, element)
    ctx
  end

  defp ctx(model, name), do: ctx(model, Esdm.resolve!(model, name))

  defp actors(name, list) do
    element = Esdm.resolve!(FixtureRepo.model(), name)
    %{element | doc: Map.put(element.doc, "actors", list)}
  end

  describe "an admin-only actor list" do
    setup do
      %{admin_only: actors("command.archive-widget", ["admin"])}
    end

    test "derives guest denial, admin allowance and the explicit user denial", %{
      model: model,
      admin_only: admin_only
    } do
      clauses = Policy.clauses(ctx(model, admin_only))

      assert clauses ==
               String.trim_trailing("""
               def authorize(:archive_widget, user, _params) when is_guest?(user), do: :error
               def authorize(:archive_widget, user, _params) when is_admin?(user), do: :ok
               def authorize(:archive_widget, user, _params) when is_user?(user), do: :error
               """)

      # the under-restricted shape must be gone: `is_user?` never allows alone
      refute clauses =~ "when is_user?(user), do: :ok"
    end

    test "the generated operation test pins all three answers", %{
      model: model,
      admin_only: admin_only
    } do
      body = PolicyTest.describe_body(ctx(model, admin_only), "Policy")

      assert body =~ ~s|assert Policy.authorize(:archive_widget, nil, %{}) == :error|

      assert body =~
               ~s|assert Policy.authorize(:archive_widget, %{id: UUID.uuid4(), role: "user"}, %{}) == :error|

      assert body =~
               ~s|assert Policy.authorize(:archive_widget, %{id: UUID.uuid4(), role: "admin"}, %{}) == :ok|
    end

    test "`admin` listed beside `user` is not admin-only — the list says both may", %{
      model: model
    } do
      clauses = Policy.clauses(ctx(model, actors("command.archive-widget", ["user", "admin"])))

      refute clauses =~ "is_admin?"

      assert clauses =~
               "def authorize(:archive_widget, user, _params) when is_user?(user), do: :ok"
    end
  end

  describe "a plain user actor list is untouched by the admin derivation" do
    test "create-widget keeps the deny/allow pair", %{model: model} do
      clauses = Policy.clauses(ctx(model, "command.create-widget"))

      assert clauses ==
               String.trim_trailing("""
               def authorize(:create_widget, user, _params) when is_guest?(user), do: :error
               def authorize(:create_widget, user, _params) when is_user?(user), do: :ok
               """)

      refute clauses =~ "is_admin?"
    end
  end

  describe "a guest-facing list" do
    test "a collection a guest may read needs no gate at all", %{model: model} do
      # every actor is allowed, so no `when` is worth writing: one open clause
      clauses = Policy.clauses(ctx(model, actors("query.list-widgets", ["guest", "user"])))

      assert clauses ==
               String.trim_trailing("""
               def authorize(:list_widgets, _user, _params), do: :ok
               """)
    end
  end
end
