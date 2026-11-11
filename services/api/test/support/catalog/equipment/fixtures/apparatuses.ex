defmodule Sportipedia.TestSupport.Catalog.Equipment.ApparatusFixtures do
  def parallel_bars do
    %{
      id: UUID.uuid5(:dns, "equipment:apparatus:parallel-bars"),
      title: "Parallel Bars",
      slug: "parallel-bars",
      description:
        "The apparatus consists of two parallel bars that are held parallel to, and elevated above, the floor by a metal supporting framework."
    }
  end

  def balance_beam do
    %{
      id: UUID.uuid5(:dns, "equipment:apparatus:balance-beam"),
      title: "Balance Beam",
      slug: "balance-beam",
      description:
        "The beam is a small, thin beam that is typically raised from the floor on a leg or stand at both ends. It is usually covered with leather-like material and is only four inches wide."
    }
  end

  def still_rings do
    %{
      id: UUID.uuid5(:dns, "equipment:apparatus:still-rings"),
      title: "Still Rings",
      slug: "still-rings",
      description:
        "The apparatus consists of two rings that hang freely from a rigid metal frame. Each ring is supported by a strap, which connects to a steel cable suspended from the metal frame."
    }
  end

  def apparatuses(), do: [parallel_bars(), balance_beam(), still_rings()]
end
