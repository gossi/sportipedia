defmodule Sportipedia.Catalog.Equipment.Apparatus.Operation.ReadApparatusTest do
  use Sportipedia.CatalogTestCase

  alias Sportipedia.Catalog.Equipment.Apparatus
  alias Sportipedia.Catalog.Equipment.Apparatus.Policy
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusProjector
  alias Sportipedia.Catalog.Equipment.Apparatus.Event.ApparatusCataloged

  describe "Policy" do
    @tag :unit
    test "allows guest to read apparatus" do
      assert :ok = Policy.authorize(:read_apparatus, nil, %{})
    end

    @tag :unit
    test "allows user to read apparatus" do
      assert :ok = Policy.authorize(:read_apparatus, %{role: "user"}, %{})
    end
  end

  describe "Public API" do
    test "returns apparatus when found by id" do
      apparatus_id = UUID.uuid4()

      event = %ApparatusCataloged{
        id: apparatus_id,
        title: "Vaulting Table",
        slug: "vaulting-table",
        description: "A gymnastics vault"
      }

      metadata = %{
        handler_name: "equipment.apparatus_projection",
        event_number: 1,
        event_id: UUID.uuid4(),
        stream_id: "equipment/apparatus-#{apparatus_id}",
        stream_version: 1,
        correlation_id: nil,
        causation_id: nil,
        created_at: DateTime.utc_now(),
        application: Sportipedia.Catalog,
        state: nil
      }

      assert :ok = ApparatusProjector.handle(event, metadata)

      assert {:ok, apparatus} = Apparatus.read_apparatus(apparatus_id)
      assert apparatus.id == apparatus_id
      assert apparatus.title == "Vaulting Table"
      assert apparatus.slug == "vaulting-table"
    end

    test "returns apparatus when found by slug" do
      apparatus_id = UUID.uuid4()

      event = %ApparatusCataloged{
        id: apparatus_id,
        title: "Balance Beam",
        slug: "balance-beam",
        description: nil
      }

      metadata = %{
        handler_name: "equipment.apparatus_projection",
        event_number: 1,
        event_id: UUID.uuid4(),
        stream_id: "equipment/apparatus-#{apparatus_id}",
        stream_version: 1,
        correlation_id: nil,
        causation_id: nil,
        created_at: DateTime.utc_now(),
        application: Sportipedia.Catalog,
        state: nil
      }

      assert :ok = ApparatusProjector.handle(event, metadata)

      assert {:ok, apparatus} = Apparatus.read_apparatus("balance-beam")
      assert apparatus.title == "Balance Beam"
      assert apparatus.slug == "balance-beam"
    end

    test "returns {:error, :not_found} when apparatus does not exist" do
      assert {:error, :not_found} = Apparatus.read_apparatus(UUID.uuid4())
    end
  end
end
