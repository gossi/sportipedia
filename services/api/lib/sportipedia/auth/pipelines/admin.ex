defmodule Sportipedia.Auth.Pipeline.Admin do
  use Guardian.Plug.Pipeline,
    otp_app: :sportipedia,
    module: Sportipedia.Auth.Guardian,
    error_handler: SportipediaWeb.ErrorHandler

  plug Guardian.Plug.VerifyHeader, claims: %{role: "admin"}, key: "user"
  plug Guardian.Plug.LoadResource, key: "user"
  plug Sportipedia.Auth.Plug.AssignCurrentUser
end
