defmodule Sportipedia.Catalog.Athlete.Position.Operation.ListPositionsTest do
  use Sportipedia.CatalogTestCase
  alias Sportipedia.Catalog.Athlete.Position
  alias Sportipedia.Catalog.Athlete.Position.Policy

  @moduletag :integration

  describe "Policy" do
    test "denies or allows guests for list_positions" do
      assert Policy.authorize(:list_positions, nil, %{}) == :ok
    end

    test "allows users for list_positions" do
      assert Policy.authorize(:list_positions, %{id: UUID.uuid4(), role: "user"}, %{}) == :ok
    end

    test "allows admins for list_positions" do
      assert Policy.authorize(:list_positions, %{id: UUID.uuid4(), role: "admin"}, %{}) == :ok
    end
  end

  describe "Query" do
    test "lists every position" do
      seed_positions([{"Ready Stance", "ready"}, {"Handstand", "handstand"}])

      assert {:ok, positions} = Position.list_positions(%JSONAPI.Config{})

      assert Enum.map(positions, & &1.slug) |> Enum.sort() == ["handstand", "ready"]
    end

    test "filters by title as a case-insensitive partial match" do
      seed_positions([
        {"Ready Stance", "rs-1"},
        {"Standing Stance", "rs-2"},
        {"Handstand", "rs-3"}
      ])

      assert {:ok, positions} =
               Position.list_positions(%JSONAPI.Config{filter: [title: "STANCE"]})

      assert Enum.map(positions, & &1.slug) |> Enum.sort() == ["rs-1", "rs-2"]
    end

    test "keeps a wildcard in the filter term literal" do
      # The caller is searching for text, not for a LIKE pattern: `%` and `_` are
      # the wildcards, so they have to match themselves.
      seed_positions([
        {"Balance 50% Beam", "pct"},
        {"Balance 50 Beam", "no-perc"},
        {"Balance Beam", "plain"},
        {"Hand_Stand", "under"}
      ])

      # Only the title that literally holds "50%": as an unescaped wildcard the
      # term would also have matched "Balance 50 Beam".
      assert {:ok, percent} = Position.list_positions(%JSONAPI.Config{filter: [title: "50%"]})
      assert Enum.map(percent, & &1.slug) == ["pct"]

      assert {:ok, underscore} = Position.list_positions(%JSONAPI.Config{filter: [title: "d_st"]})
      assert Enum.map(underscore, & &1.slug) == ["under"]

      # The same term taken as a pattern would have matched much more widely:
      # `50%` as a wildcard means "anything starting with 50", and `d_st` would
      # match "d st" too. Neither is what the caller asked for.
      assert {:ok, no_match} = Position.list_positions(%JSONAPI.Config{filter: [title: "d st"]})
      assert no_match == []
    end

    test "sorts by a field, ascending and descending" do
      seed_positions([{"Handstand", "hs"}, {"L-Sit", "ls"}, {"Mount", "mt"}])

      assert {:ok, ascending} = Position.list_positions(%JSONAPI.Config{sort: [asc: :title]})
      assert Enum.map(ascending, & &1.title) == ["Handstand", "L-Sit", "Mount"]

      assert {:ok, descending} = Position.list_positions(%JSONAPI.Config{sort: [desc: :title]})
      assert Enum.map(descending, & &1.title) == ["Mount", "L-Sit", "Handstand"]
    end

    test "sorts by several fields in the order the caller listed them" do
      seed_positions([
        {"Same Title", "a-second"},
        {"Same Title", "b-first"}
      ])

      assert {:ok, positions} =
               Position.list_positions(%JSONAPI.Config{sort: [asc: :title, desc: :slug]})

      assert Enum.map(positions, & &1.slug) == ["b-first", "a-second"]
    end

    test "paginates with page number and page size" do
      twenty_five =
        for index <- 1..25 do
          {"Position #{index}", "paged-#{String.pad_leading("#{index}", 2, "0")}"}
        end

      seed_positions(twenty_five)

      # The scenario's "positions 11-20" are the eleventh through twentieth of the
      # read's own order, which is only well-defined because the read has a
      # deterministic default order. Derive it from a single full page.
      {:ok, all} =
        Position.list_positions(%JSONAPI.Config{page: %{"number" => "1", "size" => "25"}})

      all_slugs = Enum.map(all, & &1.slug)

      {:ok, first_page} =
        Position.list_positions(%JSONAPI.Config{page: %{"number" => "1", "size" => "10"}})

      {:ok, second_page} =
        Position.list_positions(%JSONAPI.Config{page: %{"number" => "2", "size" => "10"}})

      {:ok, third_page} =
        Position.list_positions(%JSONAPI.Config{page: %{"number" => "3", "size" => "10"}})

      assert length(all) == 25
      assert Enum.map(first_page, & &1.slug) == Enum.slice(all_slugs, 0, 10)
      assert Enum.map(second_page, & &1.slug) == Enum.slice(all_slugs, 10, 10)
      assert Enum.map(third_page, & &1.slug) == Enum.slice(all_slugs, 20, 10)

      # Pages cannot drift: no position shows on two pages.
      first_ids = Enum.map(first_page, & &1.id)
      second_ids = Enum.map(second_page, & &1.id)
      refute Enum.any?(second_ids, &(&1 in first_ids))
    end

    test "orders by id when the caller gives no sort, so pages cannot drift" do
      ids = seed_positions([{"C", "c"}, {"A", "a"}, {"B", "b"}])

      assert {:ok, positions} = Position.list_positions(%JSONAPI.Config{})

      assert Enum.map(positions, & &1.id) == Enum.sort(ids)
    end

    test "the read it sends the database always orders by the primary key" do
      # A paginated read without an ORDER BY has no defined pages: the database
      # may answer in any order, and two pages of it can repeat or skip a row.
      seed_positions([{"Handstand", "hs"}])

      assert order_by_columns(read_statement(%JSONAPI.Config{page: %{"size" => "10"}})) ==
               ["id"]
    end

    test "the primary key breaks ties after the caller's sort" do
      # `sort=title` alone is not stable: positions sharing a title have no
      # defined order between them, so they can straddle a page boundary twice.
      # The tiebreaker must come after the caller's own keys, never before.
      seed_positions([{"Same Title", "a"}, {"Same Title", "b"}])

      assert order_by_columns(
               read_statement(%JSONAPI.Config{sort: [asc: :title], page: %{"size" => "10"}})
             ) == ["title", "id"]

      assert order_by_columns(
               read_statement(%JSONAPI.Config{sort: [desc: :slug], page: %{"size" => "10"}})
             ) == ["slug", "id"]

      assert order_by_columns(
               read_statement(%JSONAPI.Config{
                 sort: [asc: :title, desc: :slug],
                 page: %{"size" => "10"}
               })
             ) == ["title", "slug", "id"]
    end
  end

  describe "Public API" do
    test "list_positions lists read models" do
      assert {:ok, data} = Position.list_positions(%JSONAPI.Config{})

      assert is_list(data)
    end
  end

  # Positions are seeded through the constituent's own port, never by inserting
  # read-model rows. Every test runs in its own sandbox, so the slugs below only
  # have to be unique inside the test.
  defp seed_positions(titles_and_slugs) do
    Enum.map(titles_and_slugs, fn {title, slug} ->
      {:ok, position} = Position.catalog_position(%{title: title, slug: slug})
      position.id
    end)
  end

  # The statement the read puts in front of the database. Page stability is a
  # property of that statement, so these tests look at what the database is
  # asked to do rather than at the query struct built to ask it.
  defp read_statement(%JSONAPI.Config{} = config) do
    test_pid = self()
    ref = make_ref()
    handler = "position-list-#{inspect(ref)}"

    :ok =
      :telemetry.attach(
        handler,
        Repo.config()[:telemetry_prefix] ++ [:query],
        fn _event, _measurements, metadata, _config ->
          send(test_pid, {ref, metadata[:query]})
        end,
        nil
      )

    {:ok, _positions} = Position.list_positions(config)
    :telemetry.detach(handler)

    statements = drain(ref, [])

    Enum.find(statements, &String.contains?(&1, "SELECT")) ||
      flunk("the read issued no query: #{inspect(statements)}")
  end

  defp drain(ref, acc) do
    receive do
      {^ref, statement} -> drain(ref, [statement | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end

  # The ordering keys of a statement, in the order the database sees them.
  defp order_by_columns(statement) do
    case String.split(statement, "ORDER BY ", parts: 2) do
      [_before, clause] ->
        clause =
          clause
          |> String.split(~r/ (LIMIT|OFFSET)\b/)
          |> hd()

        Regex.scan(~r/"([a-z_]+)"/, clause)
        |> Enum.map(&Enum.at(&1, 1))

      [_without_ordering] ->
        flunk("the read carries no ORDER BY: #{statement}")
    end
  end
end
