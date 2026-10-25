defmodule Mix.Tasks.Sp.Gen.Aggregate do
  @shortdoc "Generates the aggregate module with apply/2 clauses per event"

  @moduledoc """
  Generates the aggregate citizen from the domain model.

  Executes `docs/architecture/blueprints/backend/domain/aggregate.md`
  (`Sportipedia.Codegen.Blueprints.Aggregate`): state fields plus one
  `apply/2` clause per event of the aggregate (set / merge / terminate by
  what the event's projection does), and the `<Aggregate>` `describe` block
  in the operation test files.

      mix sp.gen.aggregate aggregate.apparatus

  Fixed shape (the events drive everything) — no `--template`.
  """

  use Mix.Task

  alias Sportipedia.Codegen.{CLI, Blueprints}

  @impl Mix.Task
  def run(argv) do
    case CLI.run(Blueprints.Aggregate, argv) do
      :ok -> :ok
      {:error, message} -> Mix.raise(message)
    end
  end
end
