defmodule Sportipedia.Catalog.Equipment.Apparatus.Operation.ReadApparatusTest do
  use Sportipedia.CatalogTestCase

  alias Sportipedia.Catalog.Equipment.Apparatus
  alias Sportipedia.Catalog.Equipment.Apparatus.Policy

  @moduletag :integration

  describe "Policy" do
    test "allows guest users" do
      assert :ok = Policy.authorize(:read_apparatus, nil, %{})
    end

    test "allows authenticated users" do
      user = %{id: UUID.uuid4(), role: "user"}
      assert :ok = Policy.authorize(:read_apparatus, user, %{})
    end

    test "allows admin users" do
      admin = %{id: UUID.uuid4(), role: "admin"}
      assert :ok = Policy.authorize(:read_apparatus, admin, %{})
    end
  end

  describe "Public API - read_apparatus" do
    test "reads an apparatus by id" do
      params = %{
        title: "Vaulting Table",
        slug: "vaulting-table",
        description: "A gymnastics vault"
      }

      {:ok, created} = Apparatus.catalog_apparatus(params)

      assert {:ok, read_model} = Apparatus.read_apparatus(created.id)
      assert read_model.id == created.id
      assert read_model.title == "Vaulting Table"
      assert read_model.slug == "vaulting-table"
      assert read_model.description == "A gymnastics vault"
    end

    test "reads an apparatus by slug" do
      params = %{
        title: "Pommel Horse",
        slug: "pommel-horse",
        description: "A gymnastics apparatus"
      }

      {:ok, _created} = Apparatus.catalog_apparatus(params)

      assert {:ok, read_model} = Apparatus.read_apparatus("pommel-horse")
      assert read_model.title == "Pommel Horse"
      assert read_model.slug == "pommel-horse"
      assert read_model.description == "A gymnastics apparatus"
    end

    test "returns not_found for non-existent id" do
      assert {:error, :not_found} = Apparatus.read_apparatus(UUID.uuid4())
    end

    test "returns not_found for non-existent slug" do
      assert {:error, :not_found} = Apparatus.read_apparatus("does-not-exist")
    end
  end
end
