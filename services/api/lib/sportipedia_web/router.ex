defmodule SportipediaWeb.Router do
  use SportipediaWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    # plug :fetch_live_flash
    # plug :put_root_layout, html: {MyAppWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug OpenApiSpex.Plug.PutApiSpec, module: SportipediaWeb.System.ApiSpec
    plug JSONAPI.EnsureSpec
    plug JSONAPI.Deserializer
    plug JSONAPI.UnderscoreParameters
  end

  pipeline :admin do
    plug Sportipedia.Auth.Pipeline.Admin
  end

  pipeline :catalog do
    plug :introspect
    plug Sportipedia.Auth.Pipeline.Catalog
  end

  pipeline :system_auth do
    plug Sportipedia.Auth.Plug.SystemAuth
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

  scope "/accounts/mailer", SportipediaWeb.Accounts do
    pipe_through [:api, :system_auth]

    post "/confirm-email", EmailController, :confirm_email
    post "/password-reset", EmailController, :password_reset
  end

  scope "/catalog", SportipediaWeb.Catalog do
    pipe_through [:api, :catalog]

    scope "/equipment", Equipment do
      scope "/instruments" do
        # commands
        post "/catalog-instrument", InstrumentController, :catalog_instrument
        post "/edit-instrument", InstrumentController, :edit_instrument
        post "/archive-instrument", InstrumentController, :archive_instrument

        # queries
        get "/", InstrumentController, :list_instruments
        get "/:id", InstrumentController, :read_instrument
      end

      scope "/apparatuses" do
        # commands
        post "/catalog-apparatus", ApparatusController, :catalog_apparatus
        post "/edit-apparatus", ApparatusController, :edit_apparatus
        post "/archive-apparatus", ApparatusController, :archive_apparatus

        # queries
        get "/:id", ApparatusController, :read_apparatus
      end
    end
  end

  scope "/admin", SportipediaWeb do
    pipe_through [:api, :admin]
  end

  scope "/system" do
    pipe_through [:api]

    post "/ping", SportipediaWeb.System.HeartbeatController, :ping
    get "/openapi", OpenApiSpex.Plug.RenderSpec, []
  end

  scope "/swaggerui" do
    pipe_through :browser

    get "/", OpenApiSpex.Plug.SwaggerUI, path: "/system/openapi"
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
end
