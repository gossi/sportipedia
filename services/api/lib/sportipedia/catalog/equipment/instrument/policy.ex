defmodule Sportipedia.Catalog.Equipment.Instrument.Policy do
  @moduledoc """
  Authorizes instrument operations based on user roles.
  """

  @behaviour Bodyguard.Policy

  import Sportipedia.Auth.Roles

  def authorize(:catalog_instrument, user, _params) when is_guest?(user), do: :error
  def authorize(:catalog_instrument, user, _params) when is_user?(user), do: :ok

  def authorize(:edit_instrument, user, _params) when is_guest?(user), do: :error
  def authorize(:edit_instrument, user, _params) when is_user?(user), do: :ok

  def authorize(:archive_instrument, user, _params) when is_guest?(user), do: :error
  def authorize(:archive_instrument, user, _params) when is_user?(user), do: :ok

  def authorize(:list_instruments, _user, _params), do: :ok
  def authorize(:read_instrument, _user, _params), do: :ok
end
