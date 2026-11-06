defmodule SportipediaWeb.Catalog.Athlete.Position.PositionApiDocumentationTest do
  @moduledoc """
  The OpenAPI document the position endpoints publish, audited against the
  statuses the endpoints actually answer.

  A client generates its error handling from this document, so a status an
  endpoint can answer and the document omits is a defect of the same class as a
  query parameter the document advertises and the endpoint refuses: the promise
  and the behaviour have to be one thing. The status matrix is the one the
  endpoint blueprint states — `docs/architecture/blueprints/backend/web/endpoint-test.md`.
  """
  use ExUnit.Case

  alias SportipediaWeb.System.ApiSpec

  @moduletag :unit

  describe "documented responses" do
    test "each position endpoint documents every status it can answer" do
      paths = ApiSpec.spec().paths

      for {path, verb, documented_statuses} <- statuses_the_endpoints_answer() do
        operation = paths |> Map.fetch!(path) |> Map.fetch!(verb)

        assert operation.responses |> Map.keys() |> Enum.sort() == documented_statuses,
               "#{verb |> to_string() |> String.upcase()} #{path} documents the wrong statuses"
      end
    end
  end

  # What each endpoint can answer, taken from its own endpoint test. A read is
  # never denied, so the queries carry no 401/403; a command's Bodyguard denial
  # answers 403 and a token the auth pipeline refuses answers 401; an id that
  # addresses no position answers 404; a rejected command answers 422.
  defp statuses_the_endpoints_answer do
    [
      {"/catalog/athlete/positions", :get, [200]},
      {"/catalog/athlete/positions/{id_or_slug}", :get, [200, 404]},
      {"/catalog/athlete/positions/catalog-position", :post, [200, 401, 403, 422]},
      {"/catalog/athlete/positions/edit-position", :post, [200, 401, 403, 404, 422]},
      {"/catalog/athlete/positions/archive-position", :post, [204, 401, 403, 404, 422]}
    ]
  end
end
