defmodule Mix.Tasks.Sp.Gen.Operation do
  @shortdoc "Runs the generators of one operation's domain actor, in build order"

  @moduledoc """
  The **operation suite**: the domain actor of exactly one command or query.

  Tiers: blueprints render units; generators run blueprints; suites run
  generators. This suite resolves the operation's neighborhood from the
  model and runs, in build order:

  * `sp.gen.read_model` — the constituent's read model
  * `sp.gen.event` / `sp.gen.aggregate` / `sp.gen.projector` — per event the
    command publishes (query inputs skip the write-side members)
  * `sp.gen.query` — for a query input
  * `sp.gen.command`, `sp.gen.command_handler`, `sp.gen.policy`,
    `sp.gen.public_api`

  The internal API, validators and lookup queries are not steps of their
  own — they arrive through the command's blueprint dependencies, exactly
  as the blueprint README's per-operation sequence states.

      mix sp.gen.operation catalog-apparatus
      mix sp.gen.operation read-position --dry-run

  The operation always comes from the model — there is no `--template` here.
  Test-support fixtures are read-model owned and belong to
  `mix sp.gen.feature`, not to a single operation.

  The suite refuses until every member generator is ported to
  `sparch-elixir`, naming the missing ones — half a suite silently
  under-generating is worse than an error. While it refuses, run the same
  sequence with the Elixir tool (`mix sp.gen.<name> <element>` per
  generator, in the order above).
  """

  use Mix.Task

  @impl Mix.Task
  def run(argv), do: Mix.Tasks.Sp.Gen.delegate(:operation, argv)
end
