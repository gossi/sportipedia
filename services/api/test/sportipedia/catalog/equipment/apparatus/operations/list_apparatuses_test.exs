defmodule Sportipedia.Catalog.Equipment.Apparatus.Operation.ListApparatusesTest do
  use Sportipedia.CatalogTestCase

  alias Sportipedia.Catalog.Equipment.Apparatus
  alias Sportipedia.Catalog.Equipment.Apparatus.Policy

  @moduletag :integration

  describe "Policy" do
    test "allows guest users" do
      assert :ok = Policy.authorize(:list_apparatuses, nil, %{})
    end

    test "allows authenticated users" do
      user = %{id: UUID.uuid4(), role: "user"}
      assert :ok = Policy.authorize(:list_apparatuses, user, %{})
    end

    test "allows admin users" do
      admin = %{id: UUID.uuid4(), role: "admin"}
      assert :ok = Policy.authorize(:list_apparatuses, admin, %{})
    end
  end

  describe "Public API - list_apparatuses" do
    test "lists all apparatuses" do
      {:ok, _a1} =
        Apparatus.catalog_apparatus(%{title: "Vaulting Table", slug: "vaulting-table"})

      {:ok, _a2} =
        Apparatus.catalog_apparatus(%{title: "Pommel Horse", slug: "pommel-horse"})

      config = %JSONAPI.Config{}

      assert {:ok, results} = Apparatus.list_apparatuses(config)
      assert length(results) == 2

      titles = Enum.map(results, & &1.title)
      assert "Vaulting Table" in titles
      assert "Pommel Horse" in titles
    end

    test "filters apparatuses by title (case-insensitive partial match)" do
      {:ok, _a1} =
        Apparatus.catalog_apparatus(%{title: "Vaulting Table", slug: "vaulting-table"})

      {:ok, _a2} =
        Apparatus.catalog_apparatus(%{title: "Pommel Horse", slug: "pommel-horse"})

      {:ok, _a3} =
        Apparatus.catalog_apparatus(%{title: "Still Rings", slug: "still-rings"})

      config = %JSONAPI.Config{filter: [{"title", "vault"}]}

      assert {:ok, results} = Apparatus.list_apparatuses(config)
      assert length(results) == 1
      assert hd(results).title == "Vaulting Table"
    end

    test "filters apparatuses by title with case-insensitive match" do
      {:ok, _a1} =
        Apparatus.catalog_apparatus(%{title: "Vaulting Table", slug: "vaulting-table"})

      {:ok, _a2} =
        Apparatus.catalog_apparatus(%{title: "Pommel Horse", slug: "pommel-horse"})

      config = %JSONAPI.Config{filter: [{"title", "HORSE"}]}

      assert {:ok, results} = Apparatus.list_apparatuses(config)
      assert length(results) == 1
      assert hd(results).title == "Pommel Horse"
    end
  end
end
