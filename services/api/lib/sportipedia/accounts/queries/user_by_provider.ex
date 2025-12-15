defmodule Sportipedia.Accounts.Queries.UserByProvider do
  import Ecto.Query

  alias Sportipedia.Accounts.Projections.User

  def new(provider, provider_user_id) do
    from(u in User,
      join: ui in assoc(u, :identities),
      where: ui.provider == ^provider and ui.provider_user_id == ^provider_user_id
    )
  end
end
