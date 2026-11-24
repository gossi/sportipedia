defmodule Mix.Tasks.Sp.Gen.Query do
  @shortdoc "Generates a query module for a query element"

  @moduledoc """
  Generates the query citizen from an ESDM **query** element: the module, its
  `@spec` and the `new/n` constructor.

  A collection read — declared by
  `metadata.annotations."spgen.operation": collection`, or by `result.type:
  array` where the model says nothing — generates its body in full: the
  delegation to the shared `Sportipedia.Support.JSONAPI.QueryBuilder`. Every
  other query leaves its body to the feature specification, the blueprint's last
  1%, marked by a `TODO:` that raises.

      mix sp.gen.query read-apparatus
      mix sp.gen.query list-apparatuses

  Fixed shape — no `--template`: what a query *is* (`read` or `collection`) is
  the model's to state, and `public api` blueprint and
  `schema` blueprint are the templates that render per operation.
  """

  use Mix.Task

  @impl Mix.Task
  def run(argv), do: Mix.Tasks.Sp.Gen.delegate(:query, argv)
end
