defmodule Sportipedia.Accounts.EventStore do
  use EventStore, otp_app: :sportipedia, schema: "accounts_events"
end
