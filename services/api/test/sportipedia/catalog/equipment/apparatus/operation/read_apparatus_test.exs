defmodule Sportipedia.Catalog.Equipment.Apparatus.Operation.ReadApparatusTest do
  use Sportipedia.CatalogTestCase

  alias Sportipedia.Catalog.Equipment.Apparatus
  alias Sportipedia.Catalog.Equipment.Apparatus.Policy

  @moduletag :integration

  describe "Policy.authorize(:read_apparatus, _, _)" do
    test "guest is authorized" do
      assert Policy.authorize(:read_apparatus, nil, %{}) == :ok
    end

    test "user is authorized" do
      user = %Sportipedia.Auth.User{id: "user-1", role: "user"}
      assert Policy.authorize(:read_apparatus, user, %{}) == :ok
    end

    test "admin is authorized" do
      admin = %Sportipedia.Auth.User{id: "admin-1", role: "admin"}
      assert Policy.authorize(:read_apparatus, admin, %{}) == :ok
    end
  end

  describe "Apparatus.read_apparatus/1" do
    setup do
      attrs = %{
        id: Ecto.UUID.generate(),
        title: "Vault",
        slug: "vault",
        description: "A gymnastics vault"
      }

      %Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel{}
      |> Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel.insert_changeset(attrs)
      |> Repo.insert!()

      %{attrs: attrs}
    end

    test "returns apparatus by id", %{attrs: attrs} do
      assert {:ok, apparatus} = Apparatus.read_apparatus(attrs.id)
      assert apparatus.id == attrs.id
      assert apparatus.title == "Vault"
      assert apparatus.slug == "vault"
      assert apparatus.description == "A gymnastics vault"
    end

    test "returns apparatus by slug", %{attrs: attrs} do
      assert {:ok, apparatus} = Apparatus.read_apparatus(attrs.slug)
      assert apparatus.id == attrs.id
      assert apparatus.title == "Vault"
    end

    test "returns error when apparatus not found by id" do
      assert {:error, :not_found} = Apparatus.read_apparatus(Ecto.UUID.generate())
    end

    test "returns error when apparatus not found by slug" do
      assert {:error, :not_found} = Apparatus.read_apparatus("non-existent-slug")
    end
  end
end
