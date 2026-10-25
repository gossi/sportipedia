defmodule Sportipedia.Codegen.Blueprints.OperationTestFile do
  @moduledoc """
  Shared machinery for the operation test file
  (`docs/architecture/blueprints/backend/domain/operation-test.md`): the test
  file is owned by the *operation*, while each blueprint contributes its own
  `describe` block plus the aliases it needs.

  A blueprint therefore contributes:

  * the test file path and module name (rendered templates)
  * the alias modules its `describe` block references
  * its `describe` subject and body

  Merging into an existing test file adds only the missing units; the
  scaffold creates the file with everything for this blueprint at once.
  """

  alias Sportipedia.Codegen.{Context, FilePlan, Source, Templates, Unit}

  @test_use "Sportipedia.<Subdomain>TestCase"

  @doc "Dotted module of the subdomain's `ExUnit.CaseTemplate`, rendered."
  def test_case_module(ctx), do: Context.render(@test_use, ctx)

  @doc """
  Builds the `FilePlan` for the operation test file.

  * `path_template` / `module_template` — placeholder templates
  * `extra_vars` — overrides when the plan is driven from a related element
    (e.g. an event writing into its publishing command's test file)
  * `describes` — `[{subject_template, (ctx -> body_text)}]` this blueprint
    contributes (subject rendered with the same vars)
  * `alias_templates` — module templates the describes reference
  """
  @spec plan(Context.t(), keyword()) :: FilePlan.t()
  def plan(ctx, opts) do
    path_tpl = Keyword.fetch!(opts, :path)
    module_tpl = Keyword.fetch!(opts, :module)
    extra_vars = Keyword.get(opts, :extra_vars, %{})
    alias_tpls = Keyword.get(opts, :alias_templates, [])
    describes = Keyword.get(opts, :describes, [])

    path = Context.render(path_tpl, ctx, extra_vars)
    module = Context.render(module_tpl, ctx, extra_vars)
    test_case = test_case_module(ctx)

    alias_modules = Enum.map(alias_tpls, fn tpl -> Context.render(tpl, ctx, extra_vars) end)

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
          anchor: fn src, _ctx -> Source.describe_anchor(src) end
        }
      end)

    %FilePlan{
      path: path,
      role: :test,
      module: module,
      scaffold: fn c ->
        scaffold(c, module_tpl, test_case, alias_modules, describes, extra_vars)
      end,
      units:
        List.wrap(use_unit(test_case)) ++
          List.wrap(tag_unit()) ++
          Enum.map(alias_modules, &alias_unit(&1)) ++ describe_units
    }
  end

  # describes accept 2- or 3-tuples: {subject_tpl, body_fn} or
  # {subject_tpl, body_fn, alternate_subject_tpls}
  defp scaffold(ctx, module_tpl, test_case, alias_modules, describes, extra_vars) do
    bodies =
      describes
      |> Enum.map(fn describe ->
        {subject_tpl, body_fn} =
          case describe do
            {a, b} -> {a, b}
            {a, b, _alts} -> {a, b}
          end

        subject = Context.render(subject_tpl, ctx, extra_vars)
        body_fn.(ctx, subject)
      end)
      |> Enum.join("\n\n")

    aliases =
      alias_modules
      |> Enum.map(&"  alias #{&1}")
      |> Enum.join("\n")

    """
    defmodule #{Context.render(module_tpl, ctx, extra_vars)} do
      use #{test_case}

    #{aliases}

      @moduletag :integration

    #{Templates.indent(bodies, 2)}
    end
    """
  end

  # the test-case module name depends only on the subdomain, so it is rendered
  # once up front
  defp use_unit(test_case) do
    %Unit{
      id: {:use, test_case},
      check: fn src -> Source.has_use?(src, test_case) end,
      render: fn _ctx -> "use #{test_case}" end,
      anchor: fn src, _ctx -> {:after_line, Source.module_start_line(src)} end
    }
  end

  defp tag_unit do
    %Unit{
      id: :moduletag,
      check: fn src -> Source.has_attribute?(src, :moduletag) end,
      render: fn _ctx -> "@moduletag :integration" end,
      anchor: fn src, _ctx ->
        Source.after_entry(
          src,
          :alias,
          fn _ -> true end,
          {:after_line, Source.module_start_line(src)}
        )
      end
    }
  end

  defp alias_unit(module) do
    %Unit{
      id: {:test_alias, module},
      check: fn src -> Source.has_alias?(src, module) end,
      render: fn _ctx -> "alias #{module}" end,
      anchor: fn src, _ctx -> Source.alias_anchor(src, module) end,
      gap: :tight
    }
  end
end
