defmodule Mix.Tasks.Sp.Gen.Feature do
  @shortdoc "Runs every generator of one constituent, both actors, in build order"

  @moduledoc """
  The **feature suite**: every operation of one aggregate, domain actor
  and web actor included — the whole build of one spec, mechanically.

  Tiers: blueprints render units; generators run blueprints; suites run
  generators. This suite resolves the constituent's neighborhood from the
  model and runs, in build order:

  * `sp.gen.read_model` and `sp.gen.test_support` — the shared scaffold and
    the model-owned fixture projection
  * one operation suite per command and per query (events, aggregate,
    commands, handlers, projectors, policies, public API — the internal
    API arrives through the commands' blueprint dependencies)
  * one endpoint suite per operation (view, schemas, controllers, bruno)

      mix sp.gen.feature position
      mix sp.gen.feature widget --dry-run

  The constituent is the aggregate name (`kind.name` and `esdm:` addresses
  work as always). Order comes from the tool, not the caller: following
  the build order leaves no reference deferred. Operations are the model's
  list, never a guess; there is no `--template` here.

  What the suite does NOT do: implement residual bodies, run tests, or
  touch git — that belongs to the `implement` step of a recipe
  (`.opencode/recipes/domain-feature.recipe.md`). The suite is the
  `generate` step made one command.

  The suite refuses until every member generator is ported to
  `spgen-elixir`, naming the missing ones. While it refuses, run the same
  sequence with the Elixir tool, in the order above.
  """

  use Mix.Task

  @impl Mix.Task
  def run(argv), do: Mix.Tasks.Sp.Gen.delegate(:feature, argv)
end
