defmodule SpGen.PolicyClausesTest do
  @moduledoc """
  The policy clause shape the generator derives from the model's `actors`.

  `is_user?/1` is "authenticated" only in the sense of *not a guest*
  (`Sportipedia.Auth.Roles`): an operation whose actor list is `admin` alone
  cannot be generated as `is_user?(user) -> :ok`, or every authenticated user
  would pass an admin-only command. An admin-only list derives the
  `is_admin?` allowance and the explicit denial behind it (policy.md).
  """
  use ExUnit.Case, async: true

  alias SpGen.{Context, Esdm}
  alias SpGen.Blueprint.{Policy, PolicyTest}

  @model_root Path.expand("../../docs/domain-model")

  setup_all do
    {:ok, model} = Esdm.load(@model_root)
    %{model: model}
  end

  defp ctx(model, name) do
    element = Esdm.resolve!(model, name)
    {:ok, ctx} = Context.build(model, element)
    ctx
  end

  describe "an admin-only actor list" do
    test "derives guest denial, admin allowance and the explicit user denial", %{model: model} do
      clauses = Policy.clauses(ctx(model, "command.archive-position"))

      assert clauses ==
               String.trim_trailing("""
               def authorize(:archive_position, user, _params) when is_guest?(user), do: :error
               def authorize(:archive_position, user, _params) when is_admin?(user), do: :ok
               def authorize(:archive_position, user, _params) when is_user?(user), do: :error
               """)

      # the under-restricted shape must be gone: `is_user?` never allows alone
      refute clauses =~ "when is_user?(user), do: :ok"
    end

    test "the generated operation test pins all three answers", %{model: model} do
      body = PolicyTest.describe_body(ctx(model, "command.archive-position"), "Policy")

      assert body =~ ~s|assert Policy.authorize(:archive_position, nil, %{}) == :error|

      assert body =~
               ~s|assert Policy.authorize(:archive_position, %{id: UUID.uuid4(), role: "user"}, %{}) == :error|

      assert body =~
               ~s|assert Policy.authorize(:archive_position, %{id: UUID.uuid4(), role: "admin"}, %{}) == :ok|
    end
  end

  describe "a plain user actor list is untouched by the admin derivation" do
    test "catalog-apparatus keeps the deny/allow pair", %{model: model} do
      clauses = Policy.clauses(ctx(model, "command.catalog-apparatus"))

      assert clauses ==
               String.trim_trailing("""
               def authorize(:catalog_apparatus, user, _params) when is_guest?(user), do: :error
               def authorize(:catalog_apparatus, user, _params) when is_user?(user), do: :ok
               """)

      refute clauses =~ "is_admin?"
    end
  end
end
