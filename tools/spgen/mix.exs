defmodule SpGen.MixProject do
  use Mix.Project

  def project do
    [
      app: :spgen,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: escript()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp escript do
    [main_module: SpGen.CLI, name: "spgen"]
  end

  defp deps do
    [
      {:sourceror, "~> 1.7"},
      {:yaml_elixir, "~> 2.9"}
    ]
  end
end
