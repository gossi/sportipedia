defmodule Sportipedia.Catalog.Equipment.Apparatus.Operation.ListApparatusesTest do
  use Sportipedia.CatalogTestCase

  alias Sportipedia.Catalog.Equipment.Apparatus
  alias Sportipedia.Catalog.Equipment.Apparatus.Policy

  @moduletag :integration

  describe "Policy.authorize(:list_apparatuses, _, _)" do
    test "guest is authorized" do
      assert Policy.authorize(:list_apparatuses, nil, %{}) == :ok
    end

    test "user is authorized" do
      user = %Sportipedia.Auth.User{id: "user-1", role: "user"}
      assert Policy.authorize(:list_apparatuses, user, %{}) == :ok
    end

    test "admin is authorized" do
      admin = %Sportipedia.Auth.User{id: "admin-1", role: "admin"}
      assert Policy.authorize(:list_apparatuses, admin, %{}) == :ok
    end
  end

  describe "Apparatus.list_apparatuses/1" do
    setup do
      attrs_list = [
        %{
          id: Ecto.UUID.generate(),
          title: "Vault",
          slug: "vault",
          description: "A gymnastics vault"
        },
        %{
          id: Ecto.UUID.generate(),
          title: "Balance Beam",
          slug: "balance-beam",
          description: "A gymnastics beam"
        },
        %{
          id: Ecto.UUID.generate(),
          title: "Parallel Bars",
          slug: "parallel-bars",
          description: nil
        }
      ]

      for attrs <- attrs_list do
        %Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel{}
        |> Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel.insert_changeset(attrs)
        |> Repo.insert!()
      end

      %{apparatuses: attrs_list}
    end

    test "returns all apparatuses", %{apparatuses: apparatuses} do
      assert {:ok, result} = Apparatus.list_apparatuses(%{})
      assert length(result) == 3
      result_ids = Enum.map(result, & &1.id)
      expected_ids = Enum.map(apparatuses, & &1.id)
      assert Enum.sort(result_ids) == Enum.sort(expected_ids)
    end

    test "filters by title (case-insensitive partial match)", %{apparatuses: _} do
      assert {:ok, result} = Apparatus.list_apparatuses(%{filter: %{"title" => "vault"}})
      assert length(result) == 1
      assert hd(result).title == "Vault"

      assert {:ok, result} = Apparatus.list_apparatuses(%{filter: %{"title" => "BALANCE"}})
      assert length(result) == 1
      assert hd(result).title == "Balance Beam"

      assert {:ok, result} = Apparatus.list_apparatuses(%{filter: %{"title" => "bar"}})
      assert length(result) == 1
      assert hd(result).title == "Parallel Bars"
    end

    test "returns empty list when no match", %{apparatuses: _} do
      assert {:ok, result} = Apparatus.list_apparatuses(%{filter: %{"title" => "nonexistent"}})
      assert result == []
    end

    test "sorts by title ascending", %{apparatuses: _} do
      assert {:ok, result} = Apparatus.list_apparatuses(%{sort: ["title"]})
      titles = Enum.map(result, & &1.title)
      assert titles == ["Balance Beam", "Parallel Bars", "Vault"]
    end

    test "sorts by title descending", %{apparatuses: _} do
      assert {:ok, result} = Apparatus.list_apparatuses(%{sort: ["-title"]})
      titles = Enum.map(result, & &1.title)
      assert titles == ["Vault", "Parallel Bars", "Balance Beam"]
    end

    test "paginates with page number and size", %{apparatuses: _} do
      # Page 1, size 2
      assert {:ok, result} =
               Apparatus.list_apparatuses(%{
                 page: %{"number" => "1", "size" => "2"},
                 sort: ["title"]
               })

      assert length(result) == 2
      titles = Enum.map(result, & &1.title)
      assert titles == ["Balance Beam", "Parallel Bars"]

      # Page 2, size 2
      assert {:ok, result} =
               Apparatus.list_apparatuses(%{
                 page: %{"number" => "2", "size" => "2"},
                 sort: ["title"]
               })

      assert length(result) == 1
      assert hd(result).title == "Vault"
    end

    test "pagination with only size", %{apparatuses: _} do
      assert {:ok, result} =
               Apparatus.list_apparatuses(%{page: %{"size" => "2"}, sort: ["title"]})

      assert length(result) == 2
    end
  end
end
