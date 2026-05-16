# Commanded Coding Conventions

## Aggregate (Event Sourcing)

```elixir
defmodule Sportipedia.Accounts.Aggregates.User do
  defstruct [:id, :username, :email, :hashed_password, :profile]

  alias Sportipedia.Accounts.Events.UserRegistered

  def apply(%User{} = user, %UserRegistered{} = registered) do
    %User{user | id: registered.id}
  end
end
```

## Command Handler

```elixir
defmodule Sportipedia.Accounts.CommandHandlers.RegisterUserHandler do
  @behaviour Commanded.Commands.Handler

  alias Sportipedia.Accounts.Commands.RegisterUser
  alias Sportipedia.Accounts.Events.UserRegistered

  def handle(aggregate, %RegisterUser{} = cmd) do
    with {:ok, user} <- create_user(cmd) do
      %UserRegistered{id: user.id}
    end
  end
end
```

## Validation

Use `Vex.Struct` for validation, `ExConstructor` for struct creation.
