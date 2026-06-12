defmodule Sportipedia.Catalog.Equipment.Apparatus.Policy do
  @moduledoc """
  Authorizes apparatus operations based on user roles.
  """

  @behaviour Bodyguard.Policy

  import Sportipedia.Auth.Roles

  @doc """
  Authorizes whether the given user can perform the catalog_apparatus operation.
  """
  @spec authorize(:catalog_apparatus, map() | nil, map()) :: :ok | :error
  def authorize(:catalog_apparatus, user, _params) when is_guest?(user), do: :error
  def authorize(:catalog_apparatus, user, _params) when is_user?(user), do: :ok
end
