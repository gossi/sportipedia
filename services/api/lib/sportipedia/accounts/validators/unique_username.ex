defmodule Sportipedia.Accounts.Validators.UniqueUsername do
  use Vex.Validator

  alias Sportipedia.Accounts
  alias Sportipedia.Accounts.Projections.User

  def validate(username, context) do
    user_id = Map.get(context, :id)

    case username_registered?(username, user_id) do
      true -> {:error, "has already been taken"}
      false -> :ok
    end
  end

  defp username_registered?(username, user_id) do
    case Accounts.user_by_username(username) do
      %User{id: ^user_id} -> false
      nil -> false
      _ -> true
    end
  end
end
