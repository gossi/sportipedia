defmodule SpGen.CLITest do
  @moduledoc """
  The `mix sp.gen` listing: generators grouped by the hexagonal actor they
  serve, each group in the order the generators are meant to run in.
  """
  use ExUnit.Case, async: true

  alias SpGen.CLI

  @web [:bruno, :controller, :schema, :view]

  # what a citizen is built in: read side first, then facts and state, the
  # commands that produce them, and finally the HTTP surface. A generator
  # writes the blueprints its code calls, too (a command its validators), so
  # only generators appear here
  @usage_order [
    {:domain,
     [
       :read_model,
       :event,
       :aggregate,
       :query,
       :internal_api,
       :command,
       :command_handler,
       :projector,
       :policy,
       :public_api
     ]},
    {:web, [:view, :schema, :controller, :bruno]}
  ]

  describe "SpGen.actor/1" do
    test "the web driving adapter declares itself" do
      for generator <- @web, do: assert(SpGen.actor(generator) == :web)
    end

    test "everything inside the hexagon is domain" do
      for generator <- Map.keys(SpGen.generators()) -- @web do
        assert SpGen.actor(generator) == :domain,
               "#{inspect(generator)} should serve the domain actor"
      end
    end
  end

  describe "generators_by_actor/0" do
    test "actors in order, each group in usage order, covering every generator once" do
      assert SpGen.generators_by_actor() == @usage_order

      flat = for({_actor, generators} <- @usage_order, generator <- generators, do: generator)
      assert Enum.sort(flat) == Map.keys(SpGen.generators()) |> Enum.sort()
    end

    test "the order is a dependency order, not an alphabetical one" do
      {_actor, domain} = List.keyfind(@usage_order, :domain, 0)
      assert domain == Enum.uniq(domain)
      refute domain == Enum.sort(domain)
      # each generator comes after the ones its units are gated on
      assert Enum.find_index(domain, &(&1 == :read_model)) <
               Enum.find_index(domain, &(&1 == :internal_api))

      assert Enum.find_index(domain, &(&1 == :internal_api)) <
               Enum.find_index(domain, &(&1 == :command))

      assert Enum.find_index(domain, &(&1 == :command)) <
               Enum.find_index(domain, &(&1 == :public_api))
    end
  end

  describe "blueprints that are not generators" do
    # a validator is an implementation detail of the command that validates
    # with it, and a lookup query is one of the internal API: reached through
    # `dependencies/1`, never as a task the operator types
    test "the invariant blueprints are not addressed by name" do
      for generator <- [:validator, :lookup_query] do
        refute Enum.member?(Map.keys(SpGen.generators()), generator)
      end
    end
  end

  describe "generators_listing/0" do
    setup do
      %{lines: CLI.generators_listing()}
    end

    test "a heading per actor, in order, with its generators under it", %{lines: lines} do
      [{"Domain", domain_at}, {"Web", web_at}] =
        for heading <- ["Domain", "Web"] do
          {heading, Enum.find_index(lines, &(&1 == heading))}
        end

      assert domain_at < web_at

      {_actor, web_generators} = List.keyfind(@usage_order, :web, 0)

      for generator <- web_generators do
        assert Enum.find_index(lines, &(&1 == entry(generator))) > web_at
      end

      {_actor, domain_generators} = List.keyfind(@usage_order, :domain, 0)

      for generator <- domain_generators do
        index = Enum.find_index(lines, &(&1 == entry(generator)))
        assert index > domain_at and index < web_at
      end
    end

    test "each actor's generators are listed in run order", %{lines: lines} do
      for {_actor, generators} <- @usage_order do
        positions = Enum.map(generators, &Enum.find_index(lines, fn l -> l == entry(&1) end))
        assert positions == Enum.sort(positions), "out of run order: #{inspect(generators)}"
      end
    end

    test "every generator is listed once with its kinds, templates and blueprints",
         %{lines: lines} do
      for generator <- Map.keys(SpGen.generators()) do
        entries = Enum.filter(lines, &(&1 == entry(generator)))
        assert length(entries) == 1, "#{generator} listed #{length(entries)} times"

        index = Enum.find_index(lines, &(&1 == entry(generator)))
        [kinds, templates, blueprints] = Enum.slice(lines, (index + 1)..(index + 3))

        primary = SpGen.primary_blueprint(generator)

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

    test "no generator is missing and none is invented", %{lines: lines} do
      listed =
        for line <- lines,
            match?("  spgen " <> _, line),
            do: line |> String.replace_leading("  spgen ", "") |> String.split(" ") |> hd()

      assert Enum.map(listed, &String.to_atom/1) ==
               for({_actor, generators} <- @usage_order, generator <- generators, do: generator)
    end
  end

  defp entry(generator), do: "  spgen #{generator} <element>"
end
