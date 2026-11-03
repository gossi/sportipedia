defmodule Sportipedia.Catalog.Athlete.Position.Policy do
  @moduledoc """
  Authorizes position operations based on user roles.
  """
  import Sportipedia.Auth.Roles
  @behaviour Bodyguard.Policy
  def authorize(:catalog_position, user, _params) when is_guest?(user), do: :error
  def authorize(:catalog_position, user, _params) when is_user?(user), do: :ok
  def authorize(:archive_position, user, _params) when is_guest?(user), do: :error
  def authorize(:archive_position, user, _params) when is_user?(user), do: :ok
  def authorize(:edit_position, user, _params) when is_guest?(user), do: :error
  def authorize(:edit_position, user, _params) when is_user?(user), do: :ok
  def authorize(:list_positions, _user, _params), do: :ok
  def authorize(:read_position, _user, _params), do: :ok
end
