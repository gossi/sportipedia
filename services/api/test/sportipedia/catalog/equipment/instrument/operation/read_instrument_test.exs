defmodule Sportipedia.Catalog.Equipment.Instrument.Operation.ReadInstrumentTest do
  use Sportipedia.CatalogTestCase

  alias Sportipedia.Catalog.Equipment.Instrument
  alias Sportipedia.Catalog.Equipment.Instrument.Policy

  describe "Policy" do
    @describetag :unit

    test "allows guest to read an instrument" do
      assert Policy.authorize(:read_instrument, nil, %{}) == :ok
    end

    test "allows authenticated user to read an instrument" do
      assert Policy.authorize(:read_instrument, %{id: "user-123"}, %{}) == :ok
    end

    test "allows admin to read an instrument" do
      assert Policy.authorize(:read_instrument, %{id: "admin-123", role: "admin"}, %{}) == :ok
    end
  end

  describe "Public API" do
    @describetag :integration

    test "reads an instrument by id" do
      {:ok, created} =
        Instrument.catalog_instrument(%{title: "Unicycle", slug: "unicycle"})

      assert {:ok, instrument} = Instrument.read_instrument(created.id)
      assert instrument.id == created.id
      assert instrument.title == "Unicycle"
      assert instrument.slug == "unicycle"
    end

    test "reads an instrument by slug" do
      {:ok, _} =
        Instrument.catalog_instrument(%{title: "Skateboard", slug: "skateboard"})

      assert {:ok, instrument} = Instrument.read_instrument("skateboard")
      assert instrument.title == "Skateboard"
      assert instrument.slug == "skateboard"
    end

    test "returns not_found when instrument does not exist by id" do
      assert {:error, :not_found} =
               Instrument.read_instrument(UUID.uuid4())
    end

    test "returns not_found when instrument does not exist by slug" do
      assert {:error, :not_found} =
               Instrument.read_instrument("non-existent-slug")
    end
  end
end
