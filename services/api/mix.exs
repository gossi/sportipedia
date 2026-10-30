defmodule Sportipedia.MixProject do
  use Mix.Project

  def project do
    [
      app: :sportipedia,
      version: "0.1.0",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      listeners: [Phoenix.CodeReloader]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Sportipedia.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:bcrypt_elixir, "~> 3.3"},
      {:phoenix, "~> 1.8.5"},
      {:phoenix_ecto, "~> 4.7.0"},
      {:ecto_sql, "~> 3.13"},
      {:elixir_uuid, "~> 1.2"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.3"},
      {:phoenix_live_dashboard, "~> 0.8.7"},
      {:swoosh, "~> 1.25"},
      {:req, "~> 0.5"},
      {:cachex, "~> 3.6"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.3"},
      {:gettext, "~> 1.0.2"},
      {:jason, "~> 1.4"},
      {:dns_cluster, "~> 0.2.0"},
      {:bandit, "~> 1.10"},
      {:slugify, "~> 1.3"},
      {:typed_ecto_schema, "~> 0.4.3"},

      # objects, validation
      {:typedstruct, "~> 0.5"},
      {:exconstructor, "~> 1.3"},
      {:vex, "~> 0.9"},

      # API
      {:jsonapi, "~> 1.10.0"},
      {:open_api_spex, "~> 3.22"},

      # Security
      {:cors_plug, "~> 3.0"},
      {:ssl_verify_fun, "~> 1.1"},
      {:certifi, "~> 2.15"},

      # Authentication + Authorization
      {:guardian, "~> 2.4"},
      {:jose, "~> 1.11"},
      {:bodyguard, "~> 2.4.3"},

      # Commanded (CQRS/ES)
      {:commanded, "~> 1.4"},
      {:commanded_ecto_projections, "~> 1.4"},
      {:commanded_eventstore_adapter, "~> 1.4"},
      {:commanded_eventsourcingdb_adapter, "0.0.1"},
      {:eventstore, "~> 1.4"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      i: ["deps.get"],
      ic: ["deps.get", "deps.compile"],
      dev: ["phx.server"],
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": [
        "ecto.create",
        # "event_store.create",
        # "event_store.init",
        "ecto.migrate",
        "run priv/repo/seeds.exs"
      ],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end
