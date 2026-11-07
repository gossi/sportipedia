defmodule Sportipedia.Catalog.Athlete.Position.Operation.ListPositionsTest do
  use Sportipedia.CatalogTestCase
  alias Sportipedia.Catalog.Athlete.Position
  alias Sportipedia.Catalog.Athlete.Position.PositionReadModel
  alias Sportipedia.Catalog.Athlete.Position.Policy
  alias Sportipedia.Catalog.Athlete.Position.Queries.ListPositions
  @moduletag :integration
  describe "Query" do
    test "lists the positions in the catalog" do
      new_position(%{title: "Ready Stance", slug: "ready-stance"})
      new_position(%{title: "Handstand", slug: "handstand"})

      titles = ListPositions.new(%{}) |> Repo.all() |> Enum.map(& &1.title) |> Enum.sort()

      assert titles == ["Handstand", "Ready Stance"]
    end

    test "lists only the positions whose title contains the filter, ignoring case" do
      new_position(%{title: "Ready Stance", slug: "ready-stance"})
      new_position(%{title: "FRONT STANCE", slug: "front-stance"})
      new_position(%{title: "Handstand", slug: "handstand"})

      titles =
        ListPositions.new(%{"filter" => %{"title" => "stance"}})
        |> Repo.all()
        |> Enum.map(& &1.title)
        |> Enum.sort()

      assert titles == ["FRONT STANCE", "Ready Stance"]
    end

    test "lists the positions in ascending title order" do
      new_position(%{title: "Squat", slug: "squat"})
      new_position(%{title: "Burpee", slug: "burpee"})
      new_position(%{title: "Lunge", slug: "lunge"})

      titles = ListPositions.new(%{"sort" => "title"}) |> Repo.all() |> Enum.map(& &1.title)

      assert titles == ["Burpee", "Lunge", "Squat"]
    end

    test "lists the positions in descending title order" do
      new_position(%{title: "Squat", slug: "squat"})
      new_position(%{title: "Burpee", slug: "burpee"})
      new_position(%{title: "Lunge", slug: "lunge"})

      titles = ListPositions.new(%{"sort" => "-title"}) |> Repo.all() |> Enum.map(& &1.title)

      assert titles == ["Squat", "Lunge", "Burpee"]
    end

    test "lists the positions of the requested page" do
      new_positions(25)

      titles =
        ListPositions.new(%{"sort" => "title", "page" => %{"number" => "2", "size" => "10"}})
        |> Repo.all()
        |> Enum.map(& &1.title)

      assert titles == Enum.map(11..20, &position_title/1)
    end

    test "lists no positions for a page beyond the catalog" do
      new_positions(25)

      titles =
        ListPositions.new(%{"sort" => "title", "page" => %{"number" => 4, "size" => 10}})
        |> Repo.all()
        |> Enum.map(& &1.title)

      assert titles == []
    end

    test "lists the positions no matter how the caller spells its parameters" do
      new_position(%{title: "Ready Stance", slug: "ready-stance"})
      new_position(%{title: "Handstand", slug: "handstand"})

      params = %{filter: %{title: "stance"}, sort: "-title", page: %{number: 1, size: 10}}

      titles = ListPositions.new(params) |> Repo.all() |> Enum.map(& &1.title)

      assert titles == ["Ready Stance"]
    end

    test "lists no position that has left the catalog" do
      in_catalog = new_position(%{title: "Ready Stance", slug: "ready-stance"})
      archived = new_position(%{title: "Lunge Position", slug: "lunge-position"})

      # archiving a position deletes its row: the read model keeps no trace of it
      Repo.delete!(archived)

      titles = ListPositions.new(%{}) |> Repo.all() |> Enum.map(& &1.title)

      assert titles == [in_catalog.title]

      # the title that is gone would match the filter, yet there is no row to answer
      assert Repo.all(ListPositions.new(%{"filter" => %{"title" => "lunge"}})) == []
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

  defp new_position(attrs) do
    defaults = %{
      id: UUID.uuid4(),
      title: "Position #{UUID.uuid4()}",
      slug: "position-#{UUID.uuid4()}"
    }

    %PositionReadModel{}
    |> PositionReadModel.insert_changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  defp new_positions(count) do
    for index <- 1..count,
        do: new_position(%{title: position_title(index), slug: "position-#{index}"})
  end

  defp position_title(index) do
    "Position " <> String.pad_leading(Integer.to_string(index), 2, "0")
  end
end
