defmodule Sportipedia.Catalog.Supervisor do
  use Supervisor

  # alias Sportipedia.Catalog

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(_arg) do
    Supervisor.init(
      [
        # Catalog.Projectors.User
      ],
      strategy: :one_for_one
    )
  end
end
