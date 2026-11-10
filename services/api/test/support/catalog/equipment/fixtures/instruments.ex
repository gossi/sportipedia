defmodule Sportipedia.TestSupport.Catalog.Equipment.InstrumentFixtures do
  def unicycle do
    %{
      id: UUID.uuid5(:dns, "equipment:instrument:unicycle"),
      title: "Unicycle",
      slug: "unicycle",
      description: "Best vehicle in the world"
    }
  end

  def skateboard do
    %{
      id: UUID.uuid5(:dns, "equipment:instrument:skateboard"),
      title: "Skateboard",
      slug: "skateboard",
      description: "For the streets"
    }
  end

  def instruments, do: [unicycle(), skateboard()]
end
