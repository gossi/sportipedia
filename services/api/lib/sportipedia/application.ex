defmodule Sportipedia.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SportipediaWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:sportipedia, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Sportipedia.PubSub},
      {Cachex, name: :jwks_cache},
      # Start a worker by calling: Sportipedia.Worker.start_link(arg)
      # {Sportipedia.Worker, arg},
      # Start to serve requests, typically the last entry
      SportipediaWeb.Endpoint,

      # Run commanded applications here
      Sportipedia.Catalog.Repo,
      Sportipedia.Catalog.Supervisor
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Sportipedia.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SportipediaWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
