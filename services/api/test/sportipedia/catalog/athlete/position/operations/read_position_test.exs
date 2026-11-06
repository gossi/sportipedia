defmodule Sportipedia.Catalog.Athlete.Position.Operation.ReadPositionTest do
  use Sportipedia.CatalogTestCase
  alias Sportipedia.Catalog.Athlete.Position
  alias Sportipedia.Catalog.Athlete.Position.Policy
  alias Sportipedia.Catalog.Equipment.Apparatus

  # This read is served by the constituent's internal API through the public
  # API's own lookup chain (`position_by_id/1` for an id, `position_by_slug/1`
  # for a slug), so it has no Query module of its own — see
  # docs/architecture/blueprints/backend/domain/internal-api.md.
  @moduletag :integration

  describe "Policy" do
    test "denies or allows guests for read_position" do
      assert Policy.authorize(:read_position, nil, %{}) == :ok
    end

    test "allows users for read_position" do
      assert Policy.authorize(:read_position, %{id: UUID.uuid4(), role: "user"}, %{}) == :ok
    end

    test "allows admins for read_position" do
      assert Policy.authorize(:read_position, %{id: UUID.uuid4(), role: "admin"}, %{}) == :ok
    end
  end

  describe "Public API" do
    test "read_position returns :not_found for unknown position" do
      assert {:error, :not_found} = Position.read_position(UUID.uuid4())
    end

    test "reads a position by its id" do
      {:ok, created} =
        Position.catalog_position(%{
          title: "Handstand",
          slug: "handstand-#{UUID.uuid4()}",
          description: "Inverted balance on the hands"
        })

      assert {:ok, position} = Position.read_position(created.id)
      assert position.id == created.id
      assert position.title == "Handstand"
      assert position.description == "Inverted balance on the hands"
    end

    test "reads a position by its slug, with all its details" do
      {:ok, apparatus} = Apparatus.catalog_apparatus(%{title: "Beam", slug: "beam"})
      slug = "l-sit-#{UUID.uuid4()}"

      {:ok, created} =
        Position.catalog_position(%{
          title: "L-Sit",
          slug: slug,
          description: "Support hold with legs at ninety degrees",
          apparatusId: apparatus.id
        })

      assert {:ok, position} = Position.read_position(slug)
      assert position.id == created.id
      assert position.title == "L-Sit"
      assert position.slug == slug
      assert position.description == "Support hold with legs at ninety degrees"
      assert position.apparatusId == apparatus.id
      assert position.instrumentId == nil
    end

    test "reads a position by slug regardless of the case the caller uses" do
      slug = "astronaut-position-#{UUID.uuid4()}"

      {:ok, created} = Position.catalog_position(%{title: "Astronaut", slug: slug})

      assert {:ok, position} = Position.read_position(String.upcase(slug))
      assert position.id == created.id
    end

    test "read_position returns :not_found for an unknown slug" do
      assert {:error, :not_found} = Position.read_position("nobody-holds-this-#{UUID.uuid4()}")
    end
  end
end
