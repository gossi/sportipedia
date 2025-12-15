defmodule SportipediaWeb.Router do
  use SportipediaWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :admin do
    # plug SportipediaWeb.AdminPipeline
    plug Guardian.Plug.Pipeline,
      otp_app: :sportipedia,
      module: Sportipedia.Auth.Guardian,
      error_handler: SportipediaWeb.ErrorHandler

    plug Guardian.Plug.VerifyHeader, claims: %{role: "admin"}
    plug Guardian.Plug.LoadResource
  end

  pipeline :catalog do
    # plug SportipediaWeb.CatalogPipeline
    plug Guardian.Plug.Pipeline,
      otp_app: :sportipedia,
      module: Sportipedia.Auth.Guardian,
      error_handler: SportipediaWeb.ErrorHandler

    # Accept token if present, or continue as guest
    plug Guardian.Plug.VerifyHeader, realm: "Bearer", claims: %{}, key: :default
    plug Guardian.Plug.LoadResource, allow_blank: true
  end

  scope "/auth", SportipediaWeb do
    pipe_through :api

    # post "/login"
    # post "/register"

    post "/:provider/login", AuthController, :login_with_provider
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
