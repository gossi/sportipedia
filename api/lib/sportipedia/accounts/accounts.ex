defmodule Sportipedia.Accounts do
  @moduledoc """
  The boundary for the Accounts system.
  """

  alias Sportipedia.Accounts.Commands.{
    RegisterUser,
    RegisterWithProvider
    # UpdateUser
  }

  alias Sportipedia.Accounts.Projections.User
  alias Sportipedia.Accounts.Queries.{UserByUsername, UserByEmail}
  alias Sportipedia.Accounts.Application
  alias Sportipedia.Repo

  @doc """
  Register a new user.
  """
  def register_user(attrs \\ %{}) do
    user_id = UUID.uuid4()

    register_user =
      attrs
      |> RegisterUser.new()
      |> RegisterUser.assign_id(user_id)
      |> RegisterUser.downcase_email()
      |> RegisterUser.hash_password()

    with :ok <- Application.dispatch(register_user, consistency: :strong) do
      get(User, user_id)
    end
  end

  def register_with_provider(attrs \\ %{}) do
    user_id = UUID.uuid4()

    register_with_provider =
      attrs
      |> RegisterWithProvider.new()
      |> RegisterWithProvider.assign_user_id(user_id)
      |> RegisterWithProvider.downcase_email()

    with :ok <- Application.dispatch(register_with_provider, consistency: :strong) do
      get(User, user_id)
    else
      {:error, {:user_exists, user}} ->
        {:ok, user}
    end
  end

  # @doc """
  # Update the email, username, and/or password of a user.
  # """
  # def update_user(%User{id: user_id} = user, attrs \\ %{}) do
  #   update_user =
  #     attrs
  #     |> UpdateUser.new()
  #     |> UpdateUser.assign_user(user)
  #     |> UpdateUser.downcase_username()
  #     |> UpdateUser.downcase_email()
  #     |> UpdateUser.hash_password()

  #   with :ok <- Application.dispatch(update_user, consistency: :strong) do
  #     get(User, user_id)
  #   end
  # end

  @doc """
  Get an existing user by their username, or return `nil` if not registered
  """
  def user_by_username(username) when is_binary(username) do
    username
    |> UserByUsername.new()
    |> Repo.one()
  end

  @doc """
  Get an existing user by their email address, or return `nil` if not registered
  """
  def user_by_email(email) when is_binary(email) do
    email
    |> String.downcase()
    |> UserByEmail.new()
    |> Repo.one()
  end

  @doc """
  Get a single user by their ID
  """
  def user_by_id(id) when is_binary(id) do
    Repo.get(User, id)
  end

  @spec user_by_id!(binary()) :: any()
  def user_by_id!(id) when is_binary(id) do
    Repo.get!(User, id)
  end

  defp get(schema, id) do
    case Repo.get(schema, id) do
      nil -> {:error, :not_found}
      projection -> {:ok, projection}
    end
  end
end
