defmodule Mix.Tasks.Sp.Check do
  @shortdoc "Checks the domain model carries everything the generators need"

  @moduledoc """
  Reports whether the ESDM model holds all information the blueprint
  generators require — generating nothing, writing nothing.

      mix sp.check                                  # the entire domain model
      mix sp.check docs/domain-model/catalog        # a directory
      mix sp.check read-model.apparatus command.catalog-apparatus

  Checks (the generators' own contracts, same code): the fixture grammar and
  example-to-schema consistency of every read model with `schema.examples`
  (`SpGen.Fixtures`), reference resolution across the whole fixture graph
  (whole-model mode only), a non-empty `description` on every command,
  event and query (missing prose materializes as `TODO:` markers in generated
  docs and operation summaries), and the **declared operations**: every
  command carries `metadata.annotations."spgen.operation"` (completeness — without it
  generation must refuse to guess), and every read model's `spgen.operation.<event>`
  keys stand in bijection with its projections, `none` included (integrity —
  "decided: this fact materializes nothing" is a verdict, silence is not).

  Prints one line per finding, `<file>:<element>: <message>`, and exits 1 when
  there is any. Exit 0 means: every listed element can be generated cleanly.

  Options: `--model` model root (default `docs/domain-model`, relative to
  `--root`), `--root` repo root (default inferred from the current directory).

  Run it from the domain-model preflight of a `/build-*` slice: a finding there
  is a model defect to fix in the YAML before anything is generated.
  """

  use Mix.Task

  @impl Mix.Task
  def run(argv) do
    case SpGen.Check.run(argv) do
      {:ok, []} ->
        IO.puts("sp.check: model complete — nothing to fix")
        :ok

      {:ok, findings} ->
        Enum.each(findings, fn %{file: file, element: element, message: message} ->
          IO.puts("#{file}: #{element}: #{message}")
        end)

        IO.puts("\nsp.check: #{length(findings)} finding(s) — fix the model, then generate")
        System.halt(1)

      {:error, message} ->
        IO.puts(:stderr, "error: " <> message)
        System.halt(1)
    end
  end
end
