defmodule SportipediaWeb.Router do
  use SportipediaWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :admin do
    plug SportipediaWeb.Pipelines.Admin
  end

  pipeline :catalog do
    plug :introspect
    plug SportipediaWeb.Pipelines.Catalog
  end

  pipeline :verify_auth do
    plug SportipediaWeb.Plugs.VerifyAuth
  end

  defp introspect(conn, _opts) do
    IO.puts("""
    ---
    Verb: #{inspect(conn.method)}
    Path: #{inspect(conn.request_path)}
    Headers: #{inspect(conn.req_headers)}
    ---
    """)

    conn
  end

  # scope "/auth", SportipediaWeb do
  #   pipe_through :api

  #   post "/:provider/login", AuthController, :login_with_provider
  # endq

  scope "/accounts/mailer", SportipediaWeb.Accounts do
    pipe_through [:api, :verify_auth]

    post "/confirm-email", EmailController, :confirm_email
    post "/password-reset", EmailController, :password_reset
  end

  scope "/catalog", SportipediaWeb.Catalog do
    pipe_through [:api, :catalog]

    post "/ping", HeartbeatController, :ping
  end

  scope "/admin", SportipediaWeb do
    pipe_through [:api, :admin]
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:sportipedia, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: SportipediaWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  # scope "/", SportipediaWeb do
  #   pipe_through [:browser, :redirect_if_user_is_authenticated]

  #   # get "/users/register", UserRegistrationController, :new
  #   # post "/users/register", UserRegistrationController, :create
  # end

  # scope "/", SportipediaWeb do
  #   pipe_through [:browser, :require_authenticated_user]

  #   # get "/users/settings", UserSettingsController, :edit
  #   # put "/users/settings", UserSettingsController, :update
  #   # get "/users/settings/confirm-email/:token", UserSettingsController, :confirm_email
  # end
end
