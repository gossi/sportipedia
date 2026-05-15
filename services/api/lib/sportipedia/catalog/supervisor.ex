defmodule Sportipedia.Catalog.Supervisor do
  use Supervisor

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(_arg) do
    children = [
      Sportipedia.Catalog,
      Sportipedia.Catalog.Equipment.Instruments.InstrumentProjector
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
