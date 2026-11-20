defmodule Mix.Tasks.Sp.Validate do
  @shortdoc "Validates the domain model carries everything the generators need"

  @moduledoc """
  Reports whether the ESDM model holds all information the blueprint
  generators require — generating nothing, writing nothing.

      mix sp.validate                                  # the entire domain model
      mix sp.validate docs/domain-model/catalog        # a directory
      mix sp.validate read-model.apparatus command.catalog-apparatus

  Checks (the generators' own contracts, same code): the fixture grammar and
  example-to-schema consistency of every read model with `schema.examples`
  (`SpGen.Fixtures` in the Elixir tool), reference resolution across the whole fixture graph
  (whole-model mode only), a non-empty `description` on every command,
  event and query (missing prose materializes as `TODO:` markers in generated
  docs and operation summaries), and the **declared operations**: every
  command carries `metadata.annotations."spgen.operation"` (completeness — without it
  generation must refuse to guess), and every read model's `spgen.operation.<event>`
  keys stand in bijection with its projections, `none` included (integrity —
  "decided: this fact materializes nothing" is a verdict, silence is not).

  Runs the model-completeness engine, ported to `sparch validate` (the sparch-rs workspace).
  Prints one line per finding, `<file>: <element>: <message>`, and exits 1 when
  there is any. Exit 0 means: every listed element can be generated cleanly.

  Options: `--model` model root (default `docs/domain-model`, relative to
  `--root`), `--root` repo root (default inferred from the current directory).

  Run it from the domain-model preflight of a `/build-*` slice: a finding there
  is a model defect to fix in the YAML before anything is generated.
  """

  use Mix.Task

  @impl Mix.Task
  def run(argv), do: Mix.Tasks.Sp.Gen.validate(argv)
end
