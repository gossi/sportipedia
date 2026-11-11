defmodule SpGen.FixtureRepoTest do
  @moduledoc """
  The test harness itself.

  What a test can do with a repository is exercised by the acceptance suites;
  what a *repository must never do to a test* is exercised here — because the
  failure this file pins was a CI-only failure, invisible on a warm machine with
  spare cores.
  """
  use ExUnit.Case, async: false

  alias SpGen.FixtureRepo

  # `async: false`, deliberately: these tests are about how the shared memo
  # behaves while other cases run, so they must not be racing the suite.

  describe "shared/2" do
    test "a stored key is the only answer, and the builder never runs twice" do
      key = make_ref()
      parent = self()

      assert FixtureRepo.shared(key, fn ->
               send(parent, :built)
               :first
             end) == :first

      assert_received :built

      assert FixtureRepo.shared(key, fn -> :second end) == :first
      refute_received :built
    end

    test "a build in flight never holds the memo open for another caller" do
      # The regression. Building used to happen INSIDE `Agent.get_and_update`, so
      # the memo process was busy for as long as the build took — and a full
      # chain is seconds. Parallel modules therefore queued behind it and died on
      # GenServer's 5s default: CI failed the tests that merely asked for the
      # tree, on a loaded runner, while passing locally.
      #
      # No sleep-based guesses: the builder parks inside its own fun until THIS
      # test releases it. The old design deadlocks here — the probe call queues
      # behind the parked build and times out — so this test cannot pass by
      # accident or flake by load.
      key = make_ref()
      test_pid = self()

      builder =
        Task.async(fn ->
          FixtureRepo.shared(key, fn ->
            send(test_pid, :building)

            receive do
              :release -> :parked_value
            end
          end)
        end)

      assert_receive :building, 2_000

      # an unrelated key answers while that builder is parked: every message the
      # memo handles is a map operation, never somebody's work
      assert :answered == FixtureRepo.shared(make_ref(), fn -> :answered end)

      # a caller of the SAME key builds for itself instead of waiting; the value
      # it stores is not the one that wins, because first-writer-wins
      assert :own_build == FixtureRepo.shared(key, fn -> :own_build end)

      send(builder.pid, :release)
      assert :parked_value == Task.await(builder, 10_000)

      # whoever STORES first owns the key — here the second caller, which
      # finished while the first was still parked. The first caller keeps the
      # value it built for itself; both got a correct answer, which is all a
      # read-only shared tree promises. (For the chain it is the same tree
      # either way: generating one citizen twice is order-independent, and the
      # acceptance suite asserts exactly that.)
      assert :own_build == FixtureRepo.shared(key, fn -> raise "must not build" end)
    end

    test "an unknown key builds and answers — the memo is never load-bearing" do
      # so the helper also works outside the suite's `test_helper.exs`
      assert :built == FixtureRepo.shared(make_ref(), fn -> :built end)
    end
  end

  describe "contents/1 + restore/1" do
    test "a restored repository is a private copy of the tree" do
      repo = FixtureRepo.build()
      contents = FixtureRepo.contents(repo)
      clone = FixtureRepo.restore(contents)

      assert FixtureRepo.paths(clone) == FixtureRepo.paths(repo)

      router = "services/api/lib/sportipedia_web/router.ex"
      FixtureRepo.write(clone, router, "changed")

      assert FixtureRepo.read(clone, router) == "changed"
      refute FixtureRepo.read(repo, router) == "changed"
      refute contents[router] == "changed"
    end
  end

  describe "model/0" do
    test "reads the fixture model, never the live domain model" do
      model = FixtureRepo.model()

      assert model.root =~ "fixtures/domain-model"
      refute String.ends_with?(model.root, "docs/domain-model")

      names = model.elements |> Enum.map(& &1.name) |> Enum.sort()
      assert "widget" in names
      refute "apparatus" in names
    end

    test "the fixture model states its own domain head" do
      kinds = FixtureRepo.model().elements |> Enum.map(& &1.kind) |> Enum.uniq()

      # reference-building tests (`esdm:domain=…/subdomain=…`) only run against a
      # complete model — which is why the fixtures carry their own
      for kind <- [:domain, :"bounded-context", :subdomain] do
        assert kind in kinds, "the fixture model needs a #{inspect(kind)} element"
      end
    end
  end
end
