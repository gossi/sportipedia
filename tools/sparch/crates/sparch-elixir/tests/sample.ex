defmodule M do
  @moduledoc """
  Hi.
  """
  use TypedEctoSchema
  @behaviour Sportipedia.Command

  def go(x), do: x

  typed_schema "widgets" do
    field :title, :string

    timestamps()
  end
end
