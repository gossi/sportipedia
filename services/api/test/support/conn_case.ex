defmodule SportipediaWeb.ConnCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint SportipediaWeb.Endpoint
      use SportipediaWeb, :verified_routes
      import Plug.Conn
      import Phoenix.ConnTest
      import SportipediaWeb.ConnCase
      alias Sportipedia.Catalog.Repo
      import Ecto
      import Ecto.Changeset
      import Ecto.Query
    end
  end

  setup tags do
    pid =
      Ecto.Adapters.SQL.Sandbox.start_owner!(Sportipedia.Catalog.Repo,
        shared: not tags[:async]
      )

    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
