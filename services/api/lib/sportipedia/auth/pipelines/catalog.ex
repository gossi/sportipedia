defmodule Sportipedia.Auth.Pipeline.Catalog do
  use Guardian.Plug.Pipeline,
    otp_app: :sportipedia,
    module: Sportipedia.Auth.Guardian,
    error_handler: SportipediaWeb.System.AuthenticationErrorHandler

  # Accept token if present, or continue as guest
  plug Guardian.Plug.VerifyHeader, key: "user"
  plug Guardian.Plug.LoadResource, allow_blank: true, key: "user"
  plug Sportipedia.Auth.Plug.Identity
end
