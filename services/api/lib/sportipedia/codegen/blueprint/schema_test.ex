defmodule Sportipedia.Codegen.Blueprint.SchemaTest do
  @moduledoc """
  The paired ExUnit test files for the generated OpenAPI schema modules
  (structure assertions only — no DB): title and object type of `schema/0`.
  """

  use Sportipedia.Codegen.Blueprint

  alias Sportipedia.Codegen.Templates
  alias Sportipedia.Codegen.Blueprint.Schema

  @test_dir "services/api/test/sportipedia_web/<_subdomain>/<composite>/<domain_object>/schemas"

  def plans(%Context{} = ctx) do
    Enum.map(Schema.whiches(ctx), fn which -> test_plan(ctx, which) end)
  end

  defp test_plan(ctx, which) do
    n = Schema.names(ctx, which)

    %FilePlan{
      path: Context.render("#{@test_dir}/" <> n[:stem] <> "_test.exs", ctx),
      module: n[:full] <> "Test",
      scaffold: fn _c -> test_scaffold(n) end,
      units: [
        %Unit{
          id: {:use, "ExUnit.Case"},
          check: fn src -> Source.has_use?(src, "ExUnit.Case") end,
          render: fn _ctx -> "use ExUnit.Case" end,
          place: Merge.head(:use)
        },
        %Unit{
          id: {:alias, n[:full]},
          check: fn src -> Source.has_alias?(src, n[:full]) end,
          render: fn _ctx -> "alias #{n[:full]}" end,
          place: Merge.alias_of(n[:full])
        },
        %Unit{
          id: {:describe, n[:short]},
          check: fn src -> Source.has_describe?(src, n[:short]) end,
          render: fn _c -> test_describe(n) end,
          place: Merge.describe()
        }
      ]
    }
  end

  defp test_scaffold(n) do
    """
    defmodule #{n[:full]}Test do
      use ExUnit.Case

      alias #{n[:full]}

    #{test_describe(n) |> String.trim_trailing() |> Templates.indent(2)}
    end
    """
  end

  defp test_describe(n) do
    """
    describe "#{n[:short]}" do
      test "schema/0 has the correct title" do
        assert %{title: "#{n[:title]}"} = #{n[:short]}.schema()
      end

      test "schema is an object" do
        assert %{type: :object} = #{n[:short]}.schema()
      end
    end
    """
  end
end
