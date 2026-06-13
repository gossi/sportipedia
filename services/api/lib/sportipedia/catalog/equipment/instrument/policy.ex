defmodule Sportipedia.Catalog.Equipment.Instrument.Policy do
  @moduledoc """
  Authorizes instrument operations based on user roles.
  """

  @behaviour Bodyguard.Policy

  import Sportipedia.Auth.Roles

  def authorize(:catalog_instrument, user, _params) when is_guest?(user), do: :error
  def authorize(:catalog_instrument, user, _params) when is_user?(user), do: :ok
end
