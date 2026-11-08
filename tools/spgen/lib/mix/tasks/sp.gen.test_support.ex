defmodule Mix.Tasks.Sp.Gen.TestSupport do
  @shortdoc "Generates a read model's test-support fixtures and factory functions"

  @moduledoc """
  Generates the test-support citizens of a read model (`SpGen.Blueprint.Fixtures`
  and `SpGen.Blueprint.Factory`):

      mix sp.gen.test_support read-model.apparatus

  Two outputs, two ownership models:

  * `services/api/test/support/<subdomain>/<composite>/fixtures/<plural>.ex` —
    a **projection** of the model's `schema.examples`: rendered whole, rewritten
    when it differs. Fixture functions return the read model struct, typed
    `@spec`; ids materialize as `UUID.uuid5(:dns, "<composite>:<read-model>:<mnemonic>")`.
  * `services/api/test/support/<subdomain>/<composite>/<composite>.ex` — the
    composite's **append-only ledger**: `new_<domain_object>/1` (fixture struct
    or attribute map) and `new_<domain_object>s/1` (fail-fast plural).

  A read model without examples gets the factory only. Examples that violate
  the fixture contract (`SpGen.Fixtures`, checked by `mix sp.check`) fail the
  run with every message and write nothing.

  Fixed shape — no `--template`. Run it after `mix sp.gen.read_model`.
  """

  use Mix.Task

  @impl Mix.Task
  def run(argv), do: Mix.Tasks.Sp.Gen.delegate(:test_support, argv)
end
