defmodule SpGen.MixProject do
  use Mix.Project

  def project do
    [
      app: :spgen,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
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

  # the virtual filesystem under test only: the escript stays dependency-free
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:sourceror, "~> 1.7"},
      {:yaml_elixir, "~> 2.9"},
      {:vfs, "~> 0.1.0", only: :test}
    ]
  end
end
