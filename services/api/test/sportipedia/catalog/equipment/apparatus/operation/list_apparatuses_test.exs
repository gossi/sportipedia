defmodule Sportipedia.Catalog.Equipment.Apparatus.Operation.ListApparatusesTest do
  use Sportipedia.CatalogTestCase

  alias Sportipedia.Catalog.Equipment.Apparatus
  alias Sportipedia.Catalog.Equipment.Apparatus.Policy
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel
  alias Sportipedia.Catalog.Repo

  describe "Policy" do
    test "authorizes guest to list apparatuses" do
      assert Policy.authorize(:list_apparatuses, %{guest: true}, nil) == :ok
    end

    test "authorizes user to list apparatuses" do
      assert Policy.authorize(:list_apparatuses, %{id: UUID.uuid4()}, nil) == :ok
    end
  end

  describe "Public API" do
    test "returns empty list when no apparatuses exist" do
      assert {:ok, []} = Apparatus.list_apparatuses(%{})
    end

    test "returns all apparatuses" do
      _apparatus_1 =
        Repo.insert!(%ApparatusReadModel{
          id: UUID.uuid4(),
          title: "Vaulting Table",
          slug: "vaulting-table",
          description: "A gymnastics vault"
        })

      _apparatus_2 =
        Repo.insert!(%ApparatusReadModel{
          id: UUID.uuid4(),
          title: "Balance Beam",
          slug: "balance-beam",
          description: nil
        })

      assert {:ok, apparatuses} = Apparatus.list_apparatuses(%{})
      assert length(apparatuses) == 2

      titles = Enum.map(apparatuses, & &1.title) |> Enum.sort()
      assert titles == ["Balance Beam", "Vaulting Table"]
    end
  end
end
