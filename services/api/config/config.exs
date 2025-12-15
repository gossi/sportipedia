# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :sportipedia,
  ecto_repos: [Sportipedia.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

# Event Stores
config :sportipedia, event_stores: [Sportipedia.Accounts.EventStore]

config :sportipedia, Sportipedia.Accounts.Application,
  event_store: [
    adapter: Commanded.EventStore.Adapters.EventStore,
    serializer: Commanded.Serialization.JsonSerializer,
    event_store: Sportipedia.Accounts.EventStore
  ]

config :guardian, Guardian.DB,
  adapter: Guardian.DB.EctoAdapter,
  repo: Sportipedia.Repo

# Configures the endpoint
config :sportipedia, SportipediaWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: SportipediaWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Sportipedia.PubSub,
  live_view: [signing_salt: "FAkFxBA3"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :sportipedia, Sportipedia.Mailer, adapter: Swoosh.Adapters.Local

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
