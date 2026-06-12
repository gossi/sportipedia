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

  @doc """
  Authorizes whether the given user can perform the edit_apparatus operation.
  """
  @spec authorize(:edit_apparatus, map() | nil, map()) :: :ok | :error
  def authorize(:edit_apparatus, user, _params) when is_guest?(user), do: :error
  def authorize(:edit_apparatus, user, _params) when is_user?(user), do: :ok

  @doc """
  Authorizes whether the given user can perform the archive_apparatus operation.
  """
  @spec authorize(:archive_apparatus, map() | nil, map()) :: :ok | :error
  def authorize(:archive_apparatus, user, _params) when is_guest?(user), do: :error
  def authorize(:archive_apparatus, user, _params) when is_user?(user), do: :ok

  @doc """
  Authorizes whether the given user can perform the read_apparatus operation.
  """
  @spec authorize(:read_apparatus, map() | nil, map()) :: :ok | :error
  def authorize(:read_apparatus, user, _params) when is_guest?(user), do: :ok
  def authorize(:read_apparatus, user, _params) when is_user?(user), do: :ok

  @doc """
  Authorizes whether the given user can perform the list_apparatuses operation.
  """
  @spec authorize(:list_apparatuses, map() | nil, map()) :: :ok | :error
  def authorize(:list_apparatuses, user, _params) when is_guest?(user), do: :ok
  def authorize(:list_apparatuses, user, _params) when is_user?(user), do: :ok
end
