# Domain Object exists: Validator

For many operations, the domain object (read model/aggregate) needs to exist. Check the
existance through a validator via id, the functionality should already provided
by internal API.

Make a [validator](../validator.md) which calls internal API:

```elixir
defmodule Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Validators.<DomainObject>Exists do
  @moduledoc """
  Validates that an <domain_object> exists.
  """

  use Vex.Validator

  alias Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Internal

  @doc """
  Validates the given id exists
  """
  @spec validate(String.t(), map()) :: :ok | {:error, String.t()}
  def validate(id, _context) do
    case <DomainObject>Internal.<domain_object>_by_id(id) do
      nil -> {:error, "<domain_object> does not exist"}
      _ -> :ok
    end
  end
end
```

Use that validator in the [command](../command.md);

```elixir
defmodule Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Command.<Command> do
  @moduledoc """
  <Describe what the command does to the aggregate, derived from the domain model.>
  """

  use TypedStruct
  use ExConstructor

  @doc """
  Creates a new <Command> command.
  """
  typedstruct do
    field :id, String.t(), enforce: true
  end

  # Validation
  use Vex.Struct

  validates :id, presence: true, by: [function: &Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Validators.<DomainObject>Exists.validate/2]
end
```
