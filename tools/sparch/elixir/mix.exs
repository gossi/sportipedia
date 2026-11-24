defmodule SparchElixir.MixProject do
  use Mix.Project

  @moduledoc """
  The little Elixir binding of the BE generators: `mix sp.gen.*` and
  `mix sp.validate` as reached from `services/api`. The generators themselves
  are the `sparch-elixir` Rust binary in this workspace (see
  `../crates/sparch-elixir`); these tasks find the repo, build the binary
  when stale, delegate argv, and let the project formatter normalize what
  the run wrote — the same `Code.format_string!` engine the Elixir tool
  applied inside its merge.

  The tasks live in a dependency of the API on purpose (the rule the old
  tool stated, README decision 9): Mix resolves a dependency's tasks
  without compiling the host project first, so a generator can repair a
  tree that does not compile — that is exactly the state it is called for.
  """

  def project do
    [
      app: :sparch,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: []
    ]
  end

  def application, do: [extra_applications: [:logger]]
end
