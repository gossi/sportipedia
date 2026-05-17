defmodule Sportipedia.Catalog.Repo do
  use Ecto.Repo,
    otp_app: :sportipedia,
    adapter: Ecto.Adapters.Postgres
end
