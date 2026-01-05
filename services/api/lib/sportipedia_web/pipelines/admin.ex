defmodule SportipediaWeb.AdminPipeline do
  use Guardian.Plug.Pipeline,
    otp_app: :sportipedia,
    module: Sportipedia.Auth.Guardian,
    error_handler: SportipediaWeb.ErrorHandler

  # plug Guardian.Plug.VerifyHeader, claims: %{role: "admin"}
  plug Guardian.Plug.LoadResource
end
