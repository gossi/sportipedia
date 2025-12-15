defmodule Sportipedia.Accounts.Queries.UserByUsername do
  import Ecto.Query

  alias Sportipedia.Accounts.Projections.User

  def new(username) do
    from(u in User,
      where: u.username == ^username
    )
  end
end
