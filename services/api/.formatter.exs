[
  import_deps: [:ecto, :ecto_sql, :phoenix, :open_api_spex],
  subdirectories: ["priv/*/migrations"],
  inputs: ["*.{ex,exs}", "{config,lib,test}/**/*.{ex,exs}", "priv/*/seeds.exs"],
  locals_without_parens: [
    # commanded
    router: 1,
    middleware: 1,
    dispatch: 1,
    dispatch: 2,
    identify: 2,
    project: 3,
    type: 1,
    # typedstruct
    field: 2,
    field: 3,
    plugin: 1,
    plugin: 2,
    # vex
    validates: 2
  ]
]
