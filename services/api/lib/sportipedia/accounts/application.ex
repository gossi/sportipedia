defmodule Sportipedia.Accounts.Application do
  use Commanded.Application, otp_app: :sportipedia

  router(Sportipedia.Accounts.Router)
end
