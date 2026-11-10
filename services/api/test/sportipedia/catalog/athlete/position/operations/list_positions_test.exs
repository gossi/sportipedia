defmodule Sportipedia.Catalog.Athlete.Position.Operation.ListPositionsTest do
  use Sportipedia.CatalogTestCase
  alias Sportipedia.Catalog.Athlete.Position
  alias Sportipedia.Catalog.Athlete.Position.Policy
  alias Sportipedia.TestSupport.Catalog.Athlete
  alias Sportipedia.TestSupport.Catalog.Athlete.PositionFixtures
  @moduletag :integration
  describe "Query" do
    test "lists every position in the catalog" do
      seeded = Athlete.new_positions(PositionFixtures.positions())

      assert {:ok, listed} = Position.list_positions(%JSONAPI.Config{})

      assert Enum.map(listed, & &1.id) |> Enum.sort() == Enum.map(seeded, & &1.id) |> Enum.sort()
    end

    test "filters positions by title with a case-insensitive partial match" do
      seeded = Athlete.new_positions(PositionFixtures.positions())

      Athlete.new_position(
        struct!(PositionFixtures.unicycle_riding(),
          id: UUID.uuid4(),
          title: "Athletic Stance",
          slug: "athletic-stance",
          lookup_slug: "athletic-stance"
        )
      )

      assert {:ok, listed} = Position.list_positions(%JSONAPI.Config{filter: [title: "STANCE"]})

      matching =
        seeded |> Enum.filter(&(&1.title |> String.downcase() |> String.contains?("stance")))

      assert listed |> Enum.map(& &1.title) |> Enum.sort() ==
               Enum.sort(["Athletic Stance" | Enum.map(matching, & &1.title)])
    end

    test "sorts positions by title, following the JSON:API sort syntax" do
      seeded = Athlete.new_positions(PositionFixtures.positions())

      assert {:ok, ascending} = Position.list_positions(%JSONAPI.Config{sort: [asc: :title]})
      assert {:ok, descending} = Position.list_positions(%JSONAPI.Config{sort: [desc: :title]})

      titles = Enum.map(ascending, & &1.title)

      assert titles == seeded |> Enum.sort_by(& &1.title) |> Enum.map(& &1.title)
      assert titles == descending |> Enum.map(& &1.title) |> Enum.reverse()
    end

    test "sorts positions by their public slug, which is the canonical lookup path" do
      seeded = Athlete.new_positions(PositionFixtures.positions())

      assert {:ok, listed} = Position.list_positions(%JSONAPI.Config{sort: [asc: :slug]})

      by_canonical_path = seeded |> Enum.sort_by(& &1.lookup_slug) |> Enum.map(& &1.id)
      by_raw_slug = seeded |> Enum.sort_by(& &1.slug) |> Enum.map(& &1.id)

      # The fixture set orders differently by raw slug than by canonical path,
      # so the assertion below can only hold for the path the client sees.
      assert by_canonical_path != by_raw_slug
      assert Enum.map(listed, & &1.id) == by_canonical_path
    end

    test "answers the requested page: positions 11 to 20 of 25 catalogued positions" do
      Athlete.new_positions(paged_positions(25))

      assert {:ok, page} =
               Position.list_positions(%JSONAPI.Config{
                 sort: [asc: :title],
                 page: %{"number" => "2", "size" => "10"}
               })

      assert Enum.map(page, & &1.title) == Enum.map(11..20, &paging_title/1)
    end
  end

  describe "Policy" do
    test "denies or allows guests for list_positions" do
      assert Policy.authorize(:list_positions, nil, %{}) == :ok
    end

    test "allows users for list_positions" do
      assert Policy.authorize(:list_positions, %{id: UUID.uuid4(), role: "user"}, %{}) == :ok
    end
  end

  describe "Public API" do
    test "list_positions lists read models" do
      assert {:ok, data} = Position.list_positions(%JSONAPI.Config{})

      assert is_list(data)
    end
  end

  # Seeding over the model's fixtures: the fixture is the source of the row's data,
  # each repetition only names the position it needs for the page walk.
  defp paged_positions(count) do
    fixtures = PositionFixtures.positions()

    Enum.map(1..count, fn index ->
      struct!(Enum.at(fixtures, rem(index - 1, length(fixtures))),
        id: UUID.uuid4(),
        title: paging_title(index),
        slug: "paging-position-#{index}",
        lookup_slug: "paging/paging-position-#{index}"
      )
    end)
  end

  defp paging_title(index) do
    "Paging Position #{String.pad_leading(Integer.to_string(index), 2, "0")}"
  end
end
