defmodule Sportipedia.Codegen.Patch do
  @moduledoc """
  Applies anchor-based text insertions to a source file and canonicalizes the
  result with the project formatter.

  Insertions never replace or reformat existing lines: rendered blocks are
  spliced at line boundaries, then the whole file goes through
  `Sportipedia.Codegen.Formatter` — formatting is a pure function of content,
  which is what makes repeated generator runs byte-for-byte idempotent
  (present units are skipped upstream, and formatting an already formatted
  file changes nothing).
  """

  defmodule Insertion do
    @moduledoc "A rendered block to splice at an anchor."
    @enforce_keys [:anchor, :text]
    defstruct [:anchor, :text, gap: :blank, id: nil]

    @type anchor :: {:before_line, pos_integer()} | {:after_line, pos_integer()}
    @type t :: %__MODULE__{
            anchor: anchor(),
            text: String.t(),
            gap: :blank | :tight,
            id: term()
          }
  end

  alias Sportipedia.Codegen.Patch.Insertion

  @doc """
  Applies `insertions` to `text` and returns the formatted result.

  Options:

  * `:cwd` — where the `.formatter.exs` lives (defaults to `File.cwd!/0`)
  """
  @spec apply(String.t(), [Insertion.t()], keyword()) :: String.t()
  def apply(text, insertions, opts \\ []) do
    text
    |> String.split("\n")
    |> splice(insertions)
    |> Enum.join("\n")
    |> render_new(opts)
  end

  @doc "Canonicalize a brand-new file's content (same formatting path)."
  @spec render_new(String.t(), keyword()) :: String.t()
  def render_new(text, opts \\ []) do
    formatter_opts = Sportipedia.Codegen.Formatter.opts(Keyword.get(opts, :cwd, File.cwd!()))

    text
    |> then(&Sportipedia.Codegen.Formatter.format(&1, formatter_opts))
    |> then(&"#{String.trim_trailing(&1)}\n")
  end

  defp splice(lines, insertions) do
    insertions
    |> Enum.with_index()
    |> Enum.map(fn {%Insertion{} = ins, order} ->
      {index(ins.anchor), ins.gap, ins.text, order}
    end)
    |> Enum.sort_by(fn {idx, _gap, _text, order} -> {-idx, -order} end)
    |> Enum.reduce(lines, fn {idx, gap, text, _order}, acc ->
      insert_block(acc, idx, gap, text)
    end)
  end

  defp insert_block(lines, idx, gap, text) do
    {head, tail} = Enum.split(lines, idx)
    block = text |> String.trim_trailing("\n") |> String.split("\n")
    head ++ pad(gap, head, block, tail) ++ tail
  end

  defp pad(:tight, _head, block, _tail), do: block

  defp pad(:blank, head, block, tail) do
    before = if sep_needed_before?(head), do: [""], else: []
    after_ = if sep_needed_after?(tail), do: [""], else: []
    before ++ block ++ after_
  end

  defp sep_needed_before?([]), do: false
  defp sep_needed_before?(head), do: not blank?(List.last(head))

  defp sep_needed_after?([first | _]), do: not blank?(first)
  defp sep_needed_after?([]), do: false

  defp blank?(line), do: String.trim(line) == ""

  defp index({:before_line, line}), do: line - 1
  defp index({:after_line, line}), do: line
end
