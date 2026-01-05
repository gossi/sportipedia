defmodule Sportipedia.Accounts.Validators.UniqueEmail do
  use Vex.Validator

  alias Sportipedia.Accounts
  alias Sportipedia.Accounts.Projections.User

  def validate(value, context) do
    user_id = Map.get(context, :id)

    case email_registered?(value, user_id) do
      true -> {:error, "has already been taken"}
      false -> :ok
    end
  end

  defp email_registered?(email, user_id) do
    case Accounts.user_by_email(email) do
      %User{id: ^user_id} -> false
      nil -> false
      _ -> true
    end
  end
end
