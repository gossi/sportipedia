defmodule Sportipedia.Catalog do
  # commanded app + router
  use Commanded.Application, otp_app: :sportipedia

  router Sportipedia.Catalog.Equipment.Router
  router Sportipedia.Catalog.Athlete.Router
end
