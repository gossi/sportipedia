defmodule Sportipedia.Catalog.Equipment.Instrument.Feature.EditInstrumentTest do
  use Sportipedia.CatalogTestCase

  alias Sportipedia.Catalog.Equipment.Instrument
  alias Sportipedia.Catalog.Equipment.Instrument.Policy
  alias Sportipedia.Catalog.Equipment.Instrument.Command.EditInstrument
  alias Sportipedia.Catalog.Equipment.Instrument.Command.EditInstrumentHandler
  alias Sportipedia.Catalog.Equipment.Instrument.Event.InstrumentEdited
  alias Sportipedia.Catalog.Equipment.Instrument.InstrumentAggregate
  alias Sportipedia.Catalog.Equipment.Instrument.InstrumentReadModel
  alias Sportipedia.Catalog.Equipment.Instrument.InstrumentProjector
  alias Sportipedia.Catalog.Repo

  describe "Policy" do
    @describetag :unit

    test "allows authenticated user to edit an instrument" do
      assert Policy.authorize(:edit_instrument, %{id: "user-123"}, %{}) == :ok
    end

    test "rejects unauthenticated user" do
      assert Policy.authorize(:edit_instrument, nil, %{}) == :error
    end
  end

  describe "Command" do
    @describetag :unit

    test "creates command with required id field" do
      cmd = %EditInstrument{
        id: UUID.uuid4()
      }

      assert cmd.id != nil
      assert cmd.title == nil
      assert cmd.slug == nil
      assert cmd.description == nil
    end

    test "creates command with optional fields" do
      cmd = %EditInstrument{
        id: UUID.uuid4(),
        title: "Updated Title",
        slug: "updated-slug",
        description: "Updated description"
      }

      assert cmd.title == "Updated Title"
      assert cmd.slug == "updated-slug"
      assert cmd.description == "Updated description"
    end

    test "requires id" do
      assert_raise ArgumentError, fn ->
        struct!(EditInstrument, %{})
      end
    end

    test "id cannot be nil" do
      cmd = %EditInstrument{id: nil}

      assert_raise ArgumentError, fn ->
        Vex.validate(cmd)
      end
    end

    test "error when id does not exist" do
      id = UUID.uuid4()
      cmd = %EditInstrument{id: id}

      assert {:error, [{:error, :id, :by, :not_found}]} = Vex.validate(cmd)
    end

    test "validates id must exist" do
      id = UUID.uuid4()

      new_instrument(%{
        id: id,
        title: "Unicycle",
        slug: "unicycle"
      })

      cmd = %EditInstrument{id: id}

      assert {:ok, _} = Vex.validate(cmd)
    end

    test "change title, but keep slug" do
      id = UUID.uuid4()

      new_instrument(%{
        id: id,
        title: "Tennis Racket",
        slug: "tennis-racket"
      })

      cmd = %EditInstrument{
        id: id,
        title: "Tennis Raquet",
        slug: "tennis-racket"
      }

      assert {:ok, _} = Vex.validate(cmd)
    end

    test "check slug for uniqueness" do
      id = UUID.uuid4()

      new_instrument(%{
        id: id,
        title: "Unicycle",
        slug: "unicycle"
      })

      cmd = %EditInstrument{
        id: id,
        slug: "any-slug"
      }

      assert {:ok, _} = Vex.validate(cmd)
    end

    test "rejects when slug is not unique" do
      id = UUID.uuid4()

      new_instruments([
        %{
          id: UUID.uuid4(),
          title: "Unicycle",
          slug: "unicycle"
        },
        %{
          id: id,
          title: "Skateboard",
          slug: "skateboard"
        }
      ])

      cmd = %EditInstrument{
        id: id,
        slug: "unicycle"
      }

      assert {:error, [{:error, :slug, :by, :slug_exists}]} =
               Vex.validate(cmd)
    end

    test "does not validate slug when slug is nil" do
      id = UUID.uuid4()

      new_instrument(%{
        id: id,
        title: "Unicycle",
        slug: "unicycle"
      })

      cmd = %EditInstrument{
        id: id,
        slug: nil
      }

      assert {:ok, _} = Vex.validate(cmd)
    end
  end

  describe "Command Handler" do
    @describetag :unit

    test "creates InstrumentEdited event from EditInstrument command" do
      cmd =
        EditInstrument.new(
          id: "cmd-1",
          title: "Unicycle",
          slug: "unicycle",
          description: "Best vehicle in the world"
        )

      assert %InstrumentEdited{
               id: "cmd-1",
               title: "Unicycle",
               slug: "unicycle",
               description: "Best vehicle in the world"
             } = EditInstrumentHandler.handle(%InstrumentAggregate{}, cmd)
    end

    test "copies all fields from command to event" do
      cmd =
        EditInstrument.new(
          id: "cmd-2",
          title: "Skateboard",
          slug: "skateboard",
          description: "desc"
        )

      event = EditInstrumentHandler.handle(%InstrumentAggregate{}, cmd)

      assert event.id == cmd.id
      assert event.title == cmd.title
      assert event.slug == cmd.slug
      assert event.description == cmd.description
    end

    test "sets omitted fields to nil in the event" do
      cmd = EditInstrument.new(id: "cmd-3", title: "Skateboard")

      event = EditInstrumentHandler.handle(%InstrumentAggregate{}, cmd)

      assert event.id == "cmd-3"
      assert event.title == "Skateboard"
      assert event.slug == nil
      assert event.description == nil
    end
  end

  describe "Event" do
    @describetag :unit

    test "struct has enforced id field" do
      assert_raise ArgumentError, ~r"keys must also be given", fn ->
        struct!(InstrumentEdited, %{})
      end
    end

    test "can be encoded to JSON" do
      event = %InstrumentEdited{
        id: "e-1",
        title: "Unicycle",
        slug: "unicycle",
        description: "Best vehicle in the world"
      }

      encoded = Jason.encode!(event)

      assert encoded =~ ~s("title":"Unicycle")
      assert encoded =~ ~s("slug":"unicycle")
      assert encoded =~ ~s("description":"Best vehicle in the world")
    end

    test "changes only include modified fields" do
      event = %InstrumentEdited{id: "e-1", title: "Unicycle"}
      changes = InstrumentEdited.get_changes(event)

      assert Map.has_key?(changes, :title)
      refute Map.has_key?(changes, :slug)
      refute Map.has_key?(changes, :description)

      assert changes.title == "Unicycle"
    end

    test "encodes only non-nil fields" do
      event = %InstrumentEdited{id: "e-1", title: "Unicycle"}

      encoded = Jason.encode!(event)

      assert encoded =~ ~s("title":"Unicycle")
      refute encoded =~ ~s("slug")
      refute encoded =~ ~s("description")
    end
  end

  describe "Aggregate" do
    @describetag :unit

    test "applies InstrumentEdited event to aggregate state" do
      aggregate = %InstrumentAggregate{
        id: "agg-1",
        title: "Old Title",
        slug: "old-slug",
        description: "Old description"
      }

      event = %InstrumentEdited{id: "agg-1", title: "New Title"}

      result = InstrumentAggregate.apply(aggregate, event)

      assert result.title == "New Title"
      assert result.slug == "old-slug"
      assert result.description == "Old description"
    end

    test "partially updates only the changed fields" do
      aggregate = %InstrumentAggregate{
        id: "agg-1",
        title: "Old Title",
        slug: "old-slug",
        description: "Old description"
      }

      event = %InstrumentEdited{id: "agg-1", slug: "new-slug", description: "New description"}

      result = InstrumentAggregate.apply(aggregate, event)

      assert result.title == "Old Title"
      assert result.slug == "new-slug"
      assert result.description == "New description"
    end

    test "preserves id from existing aggregate" do
      aggregate = %InstrumentAggregate{
        id: "agg-1",
        title: "Old Title",
        slug: "old-slug",
        description: nil
      }

      event = %InstrumentEdited{id: "agg-1", title: "New Title"}

      result = InstrumentAggregate.apply(aggregate, event)

      assert result.id == "agg-1"
    end
  end

  describe "Projector" do
    @describetag :integration

    test "updates the instrument read model on InstrumentEdited event" do
      id = UUID.uuid4()

      Repo.insert!(%InstrumentReadModel{
        id: id,
        title: "Original",
        slug: "original",
        description: "desc"
      })

      event = %InstrumentEdited{
        id: id,
        title: "Updated",
        slug: "updated",
        description: "new desc"
      }

      metadata = %{
        handler_name: "equipment.instrument_projection",
        event_number: 1,
        event_id: UUID.uuid4(),
        stream_id: "instrument-#{event.id}",
        stream_version: 1,
        correlation_id: nil,
        causation_id: nil,
        created_at: DateTime.utc_now(),
        application: Sportipedia.Catalog,
        state: nil
      }

      assert :ok = InstrumentProjector.handle(event, metadata)

      instrument = Repo.get!(InstrumentReadModel, id)
      assert instrument.title == "Updated"
      assert instrument.slug == "updated"
      assert instrument.description == "new desc"
    end

    test "partially updates leaving other fields intact" do
      id = UUID.uuid4()

      Repo.insert!(%InstrumentReadModel{
        id: id,
        title: "Original",
        slug: "original",
        description: "desc"
      })

      event = %InstrumentEdited{id: id, description: "new desc"}

      metadata = %{
        handler_name: "equipment.instrument_projection",
        event_number: 1,
        event_id: UUID.uuid4(),
        stream_id: "instrument-#{event.id}",
        stream_version: 1,
        correlation_id: nil,
        causation_id: nil,
        created_at: DateTime.utc_now(),
        application: Sportipedia.Catalog,
        state: nil
      }

      assert :ok = InstrumentProjector.handle(event, metadata)

      instrument = Repo.get!(InstrumentReadModel, id)
      assert instrument.title == "Original"
      assert instrument.slug == "original"
      assert instrument.description == "new desc"
    end

    test "does nothing when instrument does not exist" do
      event = %InstrumentEdited{id: UUID.uuid4(), title: "Updated"}

      metadata = %{
        handler_name: "equipment.instrument_projection",
        event_number: 1,
        event_id: UUID.uuid4(),
        stream_id: "instrument-#{event.id}",
        stream_version: 1,
        correlation_id: nil,
        causation_id: nil,
        created_at: DateTime.utc_now(),
        application: Sportipedia.Catalog,
        state: nil
      }

      assert :ok = InstrumentProjector.handle(event, metadata)
    end

    test "is idempotent for the same event" do
      id = UUID.uuid4()

      Repo.insert!(%InstrumentReadModel{id: id, title: "Original", slug: "original"})

      event = %InstrumentEdited{id: id, title: "Updated"}

      metadata = %{
        handler_name: "equipment.instrument_projection",
        event_number: 1,
        event_id: UUID.uuid4(),
        stream_id: "instrument-#{event.id}",
        stream_version: 1,
        correlation_id: nil,
        causation_id: nil,
        created_at: DateTime.utc_now(),
        application: Sportipedia.Catalog,
        state: nil
      }

      assert :ok = InstrumentProjector.handle(event, metadata)
      assert :ok = InstrumentProjector.handle(event, metadata)

      assert [instrument] = Repo.all(InstrumentReadModel)
      assert instrument.id == id
      assert instrument.title == "Updated"
    end

    test "rejects duplicate slug" do
      Repo.insert!(%InstrumentReadModel{id: UUID.uuid4(), title: "Existing", slug: "existing"})

      id = UUID.uuid4()
      Repo.insert!(%InstrumentReadModel{id: id, title: "Original", slug: "original"})

      event = %InstrumentEdited{id: id, slug: "existing"}

      metadata = %{
        handler_name: "equipment.instrument_projection",
        event_number: 1,
        event_id: UUID.uuid4(),
        stream_id: "instrument-#{event.id}",
        stream_version: 1,
        correlation_id: nil,
        causation_id: nil,
        created_at: DateTime.utc_now(),
        application: Sportipedia.Catalog,
        state: nil
      }

      assert {:error, _} = InstrumentProjector.handle(event, metadata)
    end
  end

  describe "Public API" do
    @describetag :integration

    test "dispatches EditInstrument through the router" do
      id = UUID.uuid4()

      Repo.insert!(%InstrumentReadModel{id: id, title: "Original", slug: "original"})

      cmd = EditInstrument.new(id: id, title: "Updated", slug: "updated")

      assert :ok = Sportipedia.Catalog.dispatch(cmd, consistency: :strong)

      assert %InstrumentReadModel{title: "Updated", slug: "updated"} =
               Repo.get(InstrumentReadModel, id)
    end

    test "validation failure is rejected before reaching the aggregate" do
      Repo.insert!(%InstrumentReadModel{id: UUID.uuid4(), title: "Existing", slug: "taken"})

      cmd = EditInstrument.new(id: UUID.uuid4(), slug: "taken")

      assert {:error, {:validation_failure, %{slug: [:slug_exists]}}} =
               Sportipedia.Catalog.dispatch(cmd)
    end

    test "updates an instrument through the public API" do
      params = %{title: "Unicycle", slug: "unicycle", description: "Best vehicle in the world"}

      assert {:ok, %{id: id}} = Instrument.catalog_instrument(params)

      assert {:ok, updated} = Instrument.edit_instrument(%{"id" => id, "title" => "Updated"})
      assert updated.title == "Updated"
      assert updated.slug == "unicycle"
      assert updated.description == "Best vehicle in the world"
    end

    test "partial update through the public API" do
      params = %{title: "Unicycle", slug: "unicycle", description: "Best vehicle in the world"}

      assert {:ok, %{id: id}} = Instrument.catalog_instrument(params)

      assert {:ok, updated} =
               Instrument.edit_instrument(%{"id" => id, "description" => "New description"})

      assert updated.title == "Unicycle"
      assert updated.slug == "unicycle"
      assert updated.description == "New description"
    end
  end

  @spec new_instrument(InstrumentReadModel.t()) ::
          {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
  defp new_instrument(attributes) do
    InstrumentReadModel.insert_changeset(%InstrumentReadModel{}, attributes)
    |> Repo.insert()
  end

  defp new_instruments(attribute_collection) do
    Enum.each(attribute_collection, fn elem -> new_instrument(elem) end)
  end
end
