defmodule Sportipedia.Catalog.Equipment.Apparatus.Policy do
  @behaviour Bodyguard.Policy

  import Sportipedia.Auth.Roles

  def authorize(:catalog_apparatus, user, _params) when is_guest?(user), do: :error
  def authorize(:catalog_apparatus, user, _params) when is_user?(user), do: :ok

  def authorize(:edit_apparatus, user, _params) when is_guest?(user), do: :error
  def authorize(:edit_apparatus, user, _params) when is_user?(user), do: :ok

  def authorize(:archive_apparatus, user, _params) when is_guest?(user), do: :error
  def authorize(:archive_apparatus, user, _params) when is_user?(user), do: :ok
end
