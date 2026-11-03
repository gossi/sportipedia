defmodule SpGen.Blueprint.OperationTest do
  @moduledoc """
  Shared machinery for the operation test file
  (`docs/architecture/blueprints/backend/domain/operation-test.md`): the test
  file is owned by the *operation*, while each blueprint's `*Test` module
  contributes its own `describe` block plus the aliases it needs.

  A test blueprint therefore contributes:

  * the test file path and module name (rendered templates)
  * the alias modules its `describe` block references
  * its `describe` subject and body

  Merging into an existing test file appends only the missing units; the
  scaffold creates the file with everything for this blueprint at once.
  """

  alias SpGen.{Context, FilePlan, Merge, Source, Unit}

  @test_use "Sportipedia.<Subdomain>TestCase"

  @doc "Dotted module of the subdomain's `ExUnit.CaseTemplate`, rendered."
  def test_case_module(ctx), do: Context.render(@test_use, ctx)

  @doc """
  Builds the `FilePlan` for the operation test file.

  * `path` / `module` — placeholder templates
  * `extra_vars` — overrides when the plan is driven from a related element
    (e.g. an event writing into its publishing command's test file)
  * `describes` — `[{subject_template, (ctx -> body_text)}]` this blueprint
    contributes (subject rendered with the same vars)
  * `alias_templates` — module templates the describes reference
  * `alias_modules` — same, already rendered (when the modules come from
    related elements, e.g. every event of an aggregate)
  * `requires` — `(ctx -> [{path, reason}])` gating the describes
  * `alias_requires` — same shape, gating the alias units (default: `requires`)
  """
  @spec plan(Context.t(), keyword()) :: FilePlan.t()
  def plan(ctx, opts) do
    path_tpl = Keyword.fetch!(opts, :path)
    module_tpl = Keyword.fetch!(opts, :module)
    extra_vars = Keyword.get(opts, :extra_vars, %{})
    alias_tpls = Keyword.get(opts, :alias_templates, [])
    extra_modules = Keyword.get(opts, :alias_modules, [])
    describes = Keyword.get(opts, :describes, [])
    requires = Keyword.get(opts, :requires, fn _ctx -> [] end)
    alias_requires = Keyword.get(opts, :alias_requires, requires)

    path = Context.render(path_tpl, ctx, extra_vars)
    module = Context.render(module_tpl, ctx, extra_vars)
    test_case = test_case_module(ctx)

    alias_modules =
      Enum.map(alias_tpls, fn tpl -> Context.render(tpl, ctx, extra_vars) end) ++ extra_modules

    describe_units =
      Enum.map(describes, fn describe ->
        {subject_tpl, body_fn, alternates} =
          case describe do
            {subject_tpl, body_fn} -> {subject_tpl, body_fn, []}
            {subject_tpl, body_fn, alternates} -> {subject_tpl, body_fn, alternates}
          end

        subject = Context.render(subject_tpl, ctx, extra_vars)
        accepted = [subject | Enum.map(alternates, &Context.render(&1, ctx, extra_vars))]

        %Unit{
          id: {:describe, subject},
          check: fn src -> Enum.any?(accepted, &Source.has_describe?(src, &1)) end,
          render: fn c -> body_fn.(c, subject) end,
          requires: requires,
          place: Merge.describe()
        }
      end)

    %FilePlan{
      path: path,
      module: module,
      units:
        List.wrap(use_unit(test_case)) ++
          List.wrap(tag_unit()) ++
          Enum.map(alias_modules, &alias_unit(&1, alias_requires)) ++ describe_units,
      unit_created: true
    }
  end

  # the test-case module name depends only on the subdomain, so it is rendered
  # once up front
  defp use_unit(test_case) do
    %Unit{
      id: {:use, test_case},
      check: fn src -> Source.has_use?(src, test_case) end,
      render: fn _ctx -> "use #{test_case}" end,
      place: Merge.head(:use)
    }
  end

  defp tag_unit do
    %Unit{
      id: :moduletag,
      check: fn src -> Source.has_attribute?(src, :moduletag) end,
      render: fn _ctx -> "@moduletag :integration" end,
      place: Merge.head(:attribute)
    }
  end

  defp alias_unit(module, requires) do
    %Unit{
      id: {:test_alias, module},
      check: fn src -> Source.has_alias?(src, module) end,
      render: fn _ctx -> "alias #{module}" end,
      requires: requires,
      place: Merge.alias_of(module)
    }
  end
end
