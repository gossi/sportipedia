defmodule Sportipedia.Catalog.Application do
  # use Commanded,
  #   router: Sportipedia.Catalog.Router,
  #   event_store: Sportipedia.Catalog.EventStore

  # commanded app + router
  use Commanded.Application, otp_app: :sportipedia

  router(Sportipedia.Catalog.Router)
end
