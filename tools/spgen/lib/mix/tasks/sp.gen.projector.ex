defmodule Mix.Tasks.Sp.Gen.Projector do
  @shortdoc "Generates a projector clause for an event and registers the projector"

  @moduledoc """
  Generates the projector citizen from an ESDM event element.

  Executes `docs/architecture/blueprints/backend/domain/projector.md`
  (`SpGen.Blueprint.Projector`): the constituent projector's
  `project` clause for the event (insert / update / delete per the operation
  the read model *declares* for it — `metadata.annotations."spgen.operation.<event>"`)
  plus registration in the nearest supervisor — created here when the
  subdomain has none — and the `<Projector> - <Event>` `describe` block in the
  publishing command's operation test. A declared `none` generates no clause;
  an event nobody declared is skipped and reported.

      mix sp.gen.projector apparatus-cataloged --template create

  `--template` (create | update | delete) overrides the read model's
  declaration.
  """

  use Mix.Task

  @impl Mix.Task
  def run(argv), do: Mix.Tasks.Sp.Gen.delegate(:projector, argv)
end
