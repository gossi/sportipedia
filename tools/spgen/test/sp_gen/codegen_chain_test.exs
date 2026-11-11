defmodule SpGen.ChainAcceptanceTest do
  @moduledoc """
  The fully generated widget citizen: fixed point, order independence, and the
  recorded snapshot.
  """
  use ExUnit.Case, async: true

  import SpGen.Acceptance

  alias SpGen.FixtureRepo

  # ------------------------------------------------------------ fixed point

  describe "the full chain" do
    setup do
      %{repo: generated_repo()}
    end

    test "every generated file parses, is formatted, and a second run changes nothing", %{
      repo: repo
    } do
      for path <- FixtureRepo.generated_paths(repo) do
        source = FixtureRepo.read(repo, path)
        assert String.ends_with?(source, "\n"), "missing trailing newline: #{path}"

        if String.ends_with?(path, [".ex", ".exs"]) do
          assert {:ok, _} = Code.string_to_quoted(source), "invalid syntax in #{path}"
        end
      end

      # the registration hosts picked everything up
      web_router = read(repo, "lib/sportipedia_web/router.ex")
      assert web_router =~ "scope \"/widgets\", Widget do"
      assert web_router =~ "post \"/create-widget\", WidgetController, :create_widget"
      assert web_router =~ "get \"/:id_or_slug\", WidgetController, :read_widget"
      assert web_router =~ "get \"/\", WidgetController, :list_widgets"

      # second pass of the whole chain: absolutely nothing changes
      for {generator, args} <- chain() do
        {:ok, results} = FixtureRepo.check(repo, generator, args)

        assert writes(results) == [],
               "#{generator} #{inspect(args)} wanted changes: #{inspect(results)}"
      end
    end

    test "order independence: the reversed chain converges to the same tree", %{
      repo: forward
    } do
      reversed = FixtureRepo.build()

      for {generator, args} <- Enum.reverse(chain()) do
        assert {:ok, _} = FixtureRepo.run(reversed, generator, args),
               "#{generator} #{inspect(args)}"
      end

      assert FixtureRepo.generated_paths(forward) == FixtureRepo.generated_paths(reversed)

      for rel <- FixtureRepo.generated_paths(forward) do
        if String.ends_with?(rel, [".ex", ".exs"]) do
          # sibling order (describe blocks, routes) is an insertion history
          # question, the code is the answer — compare canonically. Non-Elixir
          # artifacts (bruno YAML) carry sequence numbers derived from the tree
          # as it was built, so they are compared by presence, not content.
          assert canon_sort(FixtureRepo.read(forward, rel)) ==
                   canon_sort(FixtureRepo.read(reversed, rel)),
                 "AST mismatch in #{rel}"
        end
      end

      # the reversed tree is a fixed point: a forward sweep changes nothing
      for {generator, args} <- chain() do
        {:ok, results} = FixtureRepo.check(reversed, generator, args)

        assert writes(results) == [],
               "#{generator} reversed drift: #{inspect(results)}"
      end
    end

    test "the canonical citizen matches the recorded snapshot", %{repo: repo} do
      actual = snapshot_text(repo)
      recorded = snapshot_path()

      if System.get_env("SPGEN_UPDATE_SNAPSHOT") == "1" do
        File.mkdir_p!(Path.dirname(recorded))
        File.write!(recorded, actual)
      end

      assert File.exists?(recorded),
             "no snapshot recorded — run SPGEN_UPDATE_SNAPSHOT=1 mix test"

      assert actual == File.read!(recorded),
             "the generated tree moved off the recorded snapshot (SPGEN_UPDATE_SNAPSHOT=1 to re-record)"
    end

    test "the guarded exists shape never rewrites a tree the old default produced", %{
      repo: repo
    } do
      validator_path =
        "services/api/lib/sportipedia/catalog/equipment/widget/validators/widget_exists.ex"

      command_path =
        "services/api/lib/sportipedia/catalog/equipment/widget/operations/archive_widget/command.ex"

      test_path =
        "services/api/test/sportipedia/catalog/equipment/widget/operations/archive_widget_test.exs"

      # roll the three files back to what the pre-fix generator emitted: the
      # unguarded lookup, the line without a skip option, the test demanding
      # the raise — the shapes that answered a blank id with a 500
      FixtureRepo.write(repo, validator_path, """
      defmodule Sportipedia.Catalog.Equipment.Widget.Validators.WidgetExists do
        @moduledoc \"\"\"
        Validates that a widget exists.
        \"\"\"
        use Vex.Validator
        alias Sportipedia.Catalog.Equipment.Widget.WidgetInternal

        @doc \"\"\"
        Validates the given id value.
        \"\"\"
        @spec validate(String.t(), map()) :: :ok | {:error, term()}
        def validate(id, _context) do
          case WidgetInternal.widget_by_id(id) do
            nil -> {:error, :not_found}
            _ -> :ok
          end
        end
      end
      """)

      exists_comment =
        "# `allow_blank` keeps the existence check off an id the caller never sent:\n" <>
          "# an absent address is `presence`'s to reject, and a `:not_found` for it would\n" <>
          "# turn the 422 the client can act on into a 404 for a resource nobody named.\n"

      new_nil_assert =
        "      # Rejected, not raised: the existence check used to hand the nil to\n" <>
          "      # `Repo.get/2`, which raises, and the command never got to answer.\n" <>
          "      # `allow_blank` on the `validates` line keeps the lookup off an absent\n" <>
          "      # address, so `presence` is the only rule that speaks for the id.\n" <>
          "      assert [:presence] ==\n" <>
          "               cmd\n" <>
          "               |> Vex.errors()\n" <>
          "               |> Enum.flat_map(fn {_error, field, rule, _message} ->\n" <>
          "                 if field == :id, do: [rule], else: []\n" <>
          "               end)\n"

      old_nil_assert =
        "      assert_raise ArgumentError, fn ->\n" <>
          "        Vex.validate(cmd)\n" <> "      end\n"

      FixtureRepo.write(
        repo,
        command_path,
        read(repo, command_path)
        |> String.replace(exists_comment, "")
        |> String.replace(", allow_blank: true]", "]")
      )

      FixtureRepo.write(
        repo,
        test_path,
        read(repo, test_path) |> String.replace(new_nil_assert, old_nil_assert)
      )

      # the rollback is real: each file carries the old shape again
      assert read(repo, command_path) =~
               "validates :id, presence: true, by: [function: &WidgetExists.validate/2]"

      refute read(repo, command_path) =~ exists_comment
      assert read(repo, test_path) =~ old_nil_assert
      assert read(repo, validator_path) =~ "case WidgetInternal.widget_by_id(id) do"

      # units check at presence granularity — moduledoc, use, alias (internal),
      # def validate/2, the needle of the `validates` line, the `describe` block.
      # The old files satisfy every one, so the new shapes defer to the operator:
      # nothing is appended (no orphan `UuidValidator` alias breaking a
      # warnings-as-errors compile) and nothing is rewritten
      {:ok, results} =
        FixtureRepo.check(repo, :command, ["archive-widget", "--template", "delete"])

      assert writes(results) == [], inspect(results)
    end
  end
end
