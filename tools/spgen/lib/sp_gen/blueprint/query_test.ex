defmodule SpGen.Blueprint.QueryTest do
  @moduledoc """
  The query's contribution to the operation test file: a
  `describe "Query"` placeholder test marking the query body as the 1% the
  blueprint leaves to the feature spec.
  """

  use SpGen.Blueprint

  alias SpGen.Blueprint.TestCaseFile

  @test_path "services/api/test/sportipedia/<_subdomain>/<composite>/<domain_object>/operations/<_operation>_test.exs"
  @test_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Operation.<Operation>Test"

  def plans(%Context{} = ctx) do
    [
      TestCaseFile.plan(ctx,
        path: @test_path,
        module: @test_module,
        alias_templates: [],
        describes: [{"Query", &describe_body/2, ["<Query> query"]}]
      )
    ]
  end

  @doc false
  def describe_body(_ctx, subject) do
    """
    describe "#{subject}" do
      test "is a work in progress until the spec fills it" do
        # the query module body is the 1% the blueprint leaves to the spec
        assert true
      end
    end
    """
  end
end
