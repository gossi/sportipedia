defmodule Mix.Tasks.Sp.Gen.Validator do
  @shortdoc "Generates the custom validators of an operation"

  @moduledoc """
  Generates one Vex validator per invariant/constraint of the domain model
  for an element (command or aggregate).

  Executes `docs/architecture/blueprints/backend/domain/validator.md` plus the
  `unique-slug` and `domain-object-exists` example blueprints
  (`SpGen.Blueprint.Validator`):

  * `unique-<field>` aggregate invariants → uniqueness via the internal API,
    tolerating the object that already owns the value (edit)
  * `<domain_object>-exists` command constraints → existence check by id

      mix sp.gen.validator catalog-apparatus
      mix sp.gen.validator aggregate.apparatus

  Fixed shape — no `--template`. Validators are exercised through command
  tests (`command.md`), not their own file.
  """

  use Mix.Task

  @impl Mix.Task
  def run(argv), do: Mix.Tasks.Sp.Gen.delegate(:validator, argv)
end
