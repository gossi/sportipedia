defmodule SportipediaWeb.Pipelines.Catalog do
  use Guardian.Plug.Pipeline,
    otp_app: :sportipedia,
    module: Sportipedia.Auth.Guardian,
    error_handler: SportipediaWeb.ErrorHandler

  # plug Guardian.Plug.VerifyHeader, realm: "Bearer", key: :default

  # Accept token if present, or continue as guest
  plug Guardian.Plug.VerifyHeader, scheme: "Bearer", claims: %{}, key: :default
  plug Guardian.Plug.LoadResource, allow_blank: true
end
