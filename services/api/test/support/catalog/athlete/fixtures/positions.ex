defmodule Sportipedia.TestSupport.Catalog.Athlete.PositionFixtures do
  @moduledoc """
  Test fixtures for the position read model — generated from
  `docs/domain-model/catalog/athlete/read-model.position.esdm.yaml` by `mix sp.gen.test_support read-model.position`.

  The model's `schema.examples` are the source of truth: this file is a
  projection and is rewritten whole on every run. Declare fixtures in the
  domain model, not here.

  Ids materialize as `UUID.uuid5(:dns, "<composite>:<read-model>:<mnemonic>")`,
  so one mnemonic names one thing in every environment forever.
  """

  alias Sportipedia.Catalog.Athlete.Position.PositionReadModel

  @doc "The `athlete:position:unicycle-riding` fixture."
  @spec unicycle_riding() :: PositionReadModel.t()
  def unicycle_riding do
    %PositionReadModel{
      id: UUID.uuid5(:dns, "athlete:position:unicycle-riding"),
      title: "Riding",
      raw_slug: "riding",
      slug: "unicycle/riding",
      description: "Riding on a unicycle",
      instrumentId: UUID.uuid5(:dns, "equipment:instrument:unicycle")
    }
  end

  @doc "The `athlete:position:unicycle-on-tire` fixture."
  @spec unicycle_on_tire() :: PositionReadModel.t()
  def unicycle_on_tire do
    %PositionReadModel{
      id: UUID.uuid5(:dns, "athlete:position:unicycle-on-tire"),
      title: "On Tire",
      raw_slug: "on-tire",
      slug: "unicycle/on-tire",
      description: "Feet are on the tire",
      instrumentId: UUID.uuid5(:dns, "equipment:instrument:unicycle")
    }
  end

  @doc "The `athlete:position:unicycle-seat-in-front` fixture."
  @spec unicycle_seat_in_front() :: PositionReadModel.t()
  def unicycle_seat_in_front do
    %PositionReadModel{
      id: UUID.uuid5(:dns, "athlete:position:unicycle-seat-in-front"),
      title: "Seat in-front",
      raw_slug: "seat-in-front",
      slug: "unicycle/seat-in-front",
      description: "Seat is hold in front of the body",
      instrumentId: UUID.uuid5(:dns, "equipment:instrument:unicycle")
    }
  end

  @doc "The `athlete:position:gymnastics-straight-arm-support` fixture."
  @spec gymnastics_straight_arm_support() :: PositionReadModel.t()
  def gymnastics_straight_arm_support do
    %PositionReadModel{
      id: UUID.uuid5(:dns, "athlete:position:gymnastics-straight-arm-support"),
      title: "Straight-arm support",
      raw_slug: "straight-arm-support",
      slug: "horizontal-bar/straight-arm-support",
      apparatusId: UUID.uuid5(:dns, "equipment:apparatus:horizontal-bar"),
      description: "Athlete has their arms straight while supporting themselves onto the bar"
    }
  end

  @doc "The `athlete:position:gymnastics-long-hang` fixture."
  @spec gymnastics_long_hang() :: PositionReadModel.t()
  def gymnastics_long_hang do
    %PositionReadModel{
      id: UUID.uuid5(:dns, "athlete:position:gymnastics-long-hang"),
      title: "Long Hang",
      raw_slug: "long-hang",
      slug: "horizontal-bar/long-hang",
      apparatusId: UUID.uuid5(:dns, "equipment:apparatus:horizontal-bar"),
      description: "Athlete has their arms straight while hanging on the bar"
    }
  end

  @doc "The `athlete:position:ready-stance` fixture."
  @spec ready_stance() :: PositionReadModel.t()
  def ready_stance do
    %PositionReadModel{
      id: UUID.uuid5(:dns, "athlete:position:ready-stance"),
      title: "Ready Stance",
      raw_slug: "ready-stance",
      slug: "ready-stance",
      description: "Athletic stance with knees slightly bent"
    }
  end

  @doc "All position fixtures, in model order."
  @spec positions() :: [PositionReadModel.t()]
  def positions,
    do: [
      unicycle_riding(),
      unicycle_on_tire(),
      unicycle_seat_in_front(),
      gymnastics_straight_arm_support(),
      gymnastics_long_hang(),
      ready_stance()
    ]
end
