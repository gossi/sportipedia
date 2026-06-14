defmodule Sportipedia.Catalog.Equipment.Instrument.Operation.ListInstrumentsTest do
  use Sportipedia.CatalogTestCase

  alias Sportipedia.Catalog.Equipment.Instrument
  alias Sportipedia.Catalog.Equipment.Instrument.Policy

  describe "Policy" do
    @describetag :unit

    test "allows guest to list instruments" do
      assert Policy.authorize(:list_instruments, nil, %{}) == :ok
    end

    test "allows authenticated user to list instruments" do
      assert Policy.authorize(:list_instruments, %{id: "user-123"}, %{}) == :ok
    end

    test "allows admin to list instruments" do
      assert Policy.authorize(:list_instruments, %{id: "admin-123", role: "admin"}, %{}) == :ok
    end
  end

  describe "Public API" do
    @describetag :integration

    test "lists all instruments" do
      {:ok, _} =
        Instrument.catalog_instrument(%{title: "Unicycle", slug: "unicycle"})

      {:ok, _} =
        Instrument.catalog_instrument(%{title: "Skateboard", slug: "skateboard"})

      query = %JSONAPI.Config{filter: nil, sort: nil, page: nil, fields: nil, view: nil}

      assert {:ok, instruments} = Instrument.list_instruments(query)
      assert length(instruments) == 2
    end

    test "returns empty list when no instruments exist" do
      query = %JSONAPI.Config{filter: nil, sort: nil, page: nil, fields: nil, view: nil}

      assert {:ok, []} = Instrument.list_instruments(query)
    end

    test "filters instruments by title (case-insensitive partial match)" do
      {:ok, _} =
        Instrument.catalog_instrument(%{title: "Unicycle", slug: "unicycle"})

      {:ok, _} =
        Instrument.catalog_instrument(%{title: "Skateboard", slug: "skateboard"})

      {:ok, _} =
        Instrument.catalog_instrument(%{title: "Uni Wheel", slug: "uni-wheel"})

      query = %JSONAPI.Config{
        filter: [{"title", "uni"}],
        sort: nil,
        page: nil,
        fields: nil,
        view: nil
      }

      assert {:ok, instruments} = Instrument.list_instruments(query)
      assert length(instruments) == 2
      titles = Enum.map(instruments, & &1.title)
      assert "Unicycle" in titles
      assert "Uni Wheel" in titles
      refute "Skateboard" in titles
    end

    test "sorts instruments by title ascending" do
      {:ok, _} =
        Instrument.catalog_instrument(%{title: "Skateboard", slug: "skateboard"})

      {:ok, _} =
        Instrument.catalog_instrument(%{title: "Unicycle", slug: "unicycle"})

      {:ok, _} =
        Instrument.catalog_instrument(%{title: "Balance Ball", slug: "balance-ball"})

      query = %JSONAPI.Config{
        filter: nil,
        sort: ["title"],
        page: nil,
        fields: nil,
        view: nil
      }

      assert {:ok, instruments} = Instrument.list_instruments(query)
      titles = Enum.map(instruments, & &1.title)
      assert titles == ["Balance Ball", "Skateboard", "Unicycle"]
    end

    test "sorts instruments by title descending" do
      {:ok, _} =
        Instrument.catalog_instrument(%{title: "Skateboard", slug: "skateboard"})

      {:ok, _} =
        Instrument.catalog_instrument(%{title: "Unicycle", slug: "unicycle"})

      {:ok, _} =
        Instrument.catalog_instrument(%{title: "Balance Ball", slug: "balance-ball"})

      query = %JSONAPI.Config{
        filter: nil,
        sort: ["-title"],
        page: nil,
        fields: nil,
        view: nil
      }

      assert {:ok, instruments} = Instrument.list_instruments(query)
      titles = Enum.map(instruments, & &1.title)
      assert titles == ["Unicycle", "Skateboard", "Balance Ball"]
    end

    test "paginates instruments by page number and size" do
      {:ok, _} =
        Instrument.catalog_instrument(%{title: "Alpha", slug: "alpha"})

      {:ok, _} =
        Instrument.catalog_instrument(%{title: "Bravo", slug: "bravo"})

      {:ok, _} =
        Instrument.catalog_instrument(%{title: "Charlie", slug: "charlie"})

      {:ok, _} =
        Instrument.catalog_instrument(%{title: "Delta", slug: "delta"})

      query = %JSONAPI.Config{
        filter: nil,
        sort: ["title"],
        page: %{"number" => "1", "size" => "2"},
        fields: nil,
        view: nil
      }

      assert {:ok, page1} = Instrument.list_instruments(query)
      assert length(page1) == 2
      assert Enum.map(page1, & &1.title) == ["Alpha", "Bravo"]

      query_page2 = %JSONAPI.Config{
        filter: nil,
        sort: ["title"],
        page: %{"number" => "2", "size" => "2"},
        fields: nil,
        view: nil
      }

      assert {:ok, page2} = Instrument.list_instruments(query_page2)
      assert length(page2) == 2
      assert Enum.map(page2, & &1.title) == ["Charlie", "Delta"]
    end
  end
end
