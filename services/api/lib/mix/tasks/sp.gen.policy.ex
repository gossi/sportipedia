defmodule Mix.Tasks.Sp.Gen.Policy do
  @shortdoc "Generates the authorization policy for an operation"

  @moduledoc """
  Generates the policy citizen from an ESDM operation (command or query).

  Executes `docs/architecture/blueprints/backend/domain/policy.md`
  (`Sportipedia.Codegen.Blueprint.Policy`): the constituent `authorize/3`
  clauses for the operation, with the guard pair when guests are not allowed
  and a single open clause when they are (the shared `Sportipedia.Auth.Roles`
  guards keep role checks centralized).

      mix sp.gen.policy catalog-apparatus
      mix sp.gen.policy read-apparatus

  Fixed shape (the `actors` from the domain model drive it) — no `--template`.
  """

  use Mix.Task

  alias Sportipedia.Codegen.CLI

  @impl Mix.Task
  def run(argv) do
    case CLI.run(:policy, argv) do
      :ok -> :ok
      {:error, message} -> Mix.raise(message)
    end
  end
end
