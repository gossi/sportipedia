defmodule SportipediaWeb.Router do
  use SportipediaWeb, :router
  use Pow.Phoenix.Router
  use PowAssent.Phoenix.Router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {SportipediaWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(:accepts, ["json"])
    plug(Pow.Plug.Session, otp_app: :sportipedia)
  end

  pipeline :skip_csrf_protection do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:put_secure_browser_headers)
  end

  scope "/" do
    pipe_through(:skip_csrf_protection)

    pow_assent_authorization_post_callback_routes()
  end

  scope "/" do
    pipe_through(:browser)
    pow_routes()
    # pow_assent_routes()
    pow_assent_authorization_routes()
  end

  # scope "/", SportipediaWeb do
  #   # pipe_through(:browser)

  #   # get "/", PageController, :home
  #   pow_routes()
  #   pow_assent_authorization_routes()
  # end

  scope "/api", SportipediaWeb do
    pipe_through(:api)
  end

  # Enable Swoosh mailbox preview in development
  if Application.compile_env(:sportipedia, :dev_routes) do
    scope "/dev" do
      pipe_through(:browser)

      forward("/mailbox", Plug.Swoosh.MailboxPreview)
    end
  end
end
