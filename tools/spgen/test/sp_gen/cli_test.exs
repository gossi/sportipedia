defmodule SpGen.CLITest do
  @moduledoc """
  The `mix sp.gen` listing: families grouped by the blueprint layer they
  transfer (`docs/architecture/blueprints/backend/domain` vs `…/web`).
  """
  use ExUnit.Case, async: true

  alias SpGen.CLI

  @web [:bruno, :controller, :schema, :view]

  describe "SpGen.layer/1" do
    test "the web half of the blueprint tree declares it" do
      for family <- @web, do: assert(SpGen.layer(family) == :web)
    end

    test "everything else is domain" do
      for family <- Map.keys(SpGen.families()) -- @web do
        assert SpGen.layer(family) == :domain, "#{inspect(family)} should be a domain generator"
      end
    end
  end

  describe "families_by_layer/0" do
    test "covers every family exactly once, Domain first, names sorted" do
      layers = SpGen.families_by_layer()

      assert Enum.map(layers, &elem(&1, 0)) == [:domain, :web]

      grouped = layers |> Enum.flat_map(&elem(&1, 1)) |> Enum.sort()
      assert grouped == Map.keys(SpGen.families()) |> Enum.sort()

      for {_layer, families} <- layers do
        assert families == Enum.sort(families), "not sorted: #{inspect(families)}"
      end
    end
  end

  describe "families_listing/0" do
    setup do
      %{lines: CLI.families_listing()}
    end

    test "a heading per layer, in order, with the families under it", %{lines: lines} do
      positions =
        for heading <- ["Domain", "Web"] do
          {heading, Enum.find_index(lines, &(&1 == heading))}
        end

      assert [{"Domain", domain_at}, {"Web", web_at}] = positions
      assert domain_at < web_at

      # each entry sits under its own layer's heading
      for family <- @web do
        entry = "  spgen #{family} <element>"
        assert Enum.find_index(lines, &(&1 == entry)) > web_at
      end

      for family <- Map.keys(SpGen.families()) -- @web do
        entry = "  spgen #{family} <element>"
        index = Enum.find_index(lines, &(&1 == entry))
        assert index > domain_at and index < web_at
      end
    end

    test "every family is listed once with its kinds, templates and blueprints",
         %{lines: lines} do
      for family <- Map.keys(SpGen.families()) do
        entries = Enum.filter(lines, &(&1 == "  spgen #{family} <element>"))
        assert length(entries) == 1, "#{family} listed #{length(entries)} times"

        index = Enum.find_index(lines, &(&1 == "  spgen #{family} <element>"))
        [kinds, templates, blueprints] = Enum.slice(lines, (index + 1)..(index + 3))

        primary = SpGen.primary(family)

        assert kinds ==
                 "    from: " <>
                   (primary.source_kinds() |> Enum.map(&to_string/1) |> Enum.join(", "))

        expected =
          case primary.operations() do
            :fixed -> "    fixed (no --template)"
            ops -> "    --template " <> Enum.join(ops, " | ")
          end

        assert templates == expected
        assert blueprints =~ "    blueprints: Blueprint."
      end
    end

    test "no family is missing and none is invented", %{lines: lines} do
      listed =
        for line <- lines,
            match?("  spgen " <> _, line),
            do: line |> String.replace_leading("  spgen ", "") |> String.split(" ") |> hd()

      assert Enum.sort(listed) ==
               Map.keys(SpGen.families()) |> Enum.map(&Atom.to_string/1) |> Enum.sort()
    end
  end
end
