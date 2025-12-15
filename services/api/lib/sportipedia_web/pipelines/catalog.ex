defmodule SportipediaWeb.Pipelines.Catalog do
  use Guardian.Plug.Pipeline,
    otp_app: :sportipedia,
    module: Sportipedia.Auth.Guardian,
    error_handler: SportipediaWeb.ErrorHandler

  # Accept token if present, or continue as guest
  # plug Guardian.Plug.VerifyHeader, realm: "Bearer", key: :default

  # plug Guardian.Plug.VerifyHeader, realm: "Bearer", claims: %{}, key: :default
  plug Guardian.Plug.LoadResource, allow_blank: true
end
