# Command

| Attribute | Value |
| --- | --- |
| Schema | [Core](../../../../schemas/core/v1.yaml) |
| File Path | `/services/api/lib/sportipedia/<_subdomain>/<_composite>/<domain_object>/operation/<_operation>/command.ex` |
| Module Name | `Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Command.<Command>` |
| Test | See [Operation Test](./operation-test.md) |

## Prerequisite

- The [Domain Model](../../../../domain-model/README.md) contains the command,
  rules and invariants

## Implementation

- Is a `commanded` command
- Struct creation with enforced fields
  - use TypedStruct
  - use ExConstructor
  - use field-level `enforce: true` on each required field, NOT struct-level `enforce: true`

### Validation

When needed use `vex` to validate commands.

Read [Vex documentation](https://hexdocs.pm/vex/)

- `use Vex.Struct` on the command
- use `validates :<_field>` with built-in checks, eg. `presence: true`

#### Custom Validations

Vex allows custom validations

- Use a [custom validator](./validator.md)
- apply it with `by: [function: &<Validator>.validate/2]` and combine it with needed options
  - use `allow_nil: true` when domain logic requires it to

### Documentation

Derive all documentation from the [Domain Model](../../../../domain-model/README.md):

- **`@moduledoc`**: Describe what the command does to the aggregate, using the command name from the domain model.
- **`@doc`**: Describe the `new/1` function (creates a new command instance).

Example:

```elixir
@moduledoc """
Suggests a new sport to the catalog.
"""

@doc """
Creates a new SuggestSport command.
"""
```

### Implementation Template

- use `alias` for the validator

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
    field :<_field>, <field type>, enforce: true/false
  end

  # Validation
  use Vex.Struct

  validates :title, presence: true
  validates :slug, presence: true, by: [function: &Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Validators.<Validator>.validate/2]
end
```

### Register Command

- register at a commanded router
- router locations: `/services/api/lib/sportipedia/<_subdomain>/<_composite>/router.ex`
- dispatch contents:

```elixir
  identify <DomainObject>Aggregate, by: :id, prefix: "<-composite>/<domain-object>/"
  dispatch <Command>, to: <Command>Handler, aggregate: <DomainObject>Aggregate
```

## Tests

What to test:

- Struct creation with enforced fields
  - When testing enforced fields, use `struct!(Command, %{})` which raises
    `ArgumentError` if required fields are missing
  - Optional fields (no `enforce: true`) can be omitted in struct literals
    without raising — test this by creating events without optional fields
- Validation

### Example: Command requires an id

```elixir
    test "requires id" do
      assert_raise ArgumentError, fn ->
        struct!(<Command>, %{})
      end
    end
```

### Example: id cannot be nil

```elixir
    test "id cannot be nil" do
      cmd = %<Command>{id: nil}

      assert_raise ArgumentError, fn ->
        Vex.validate(cmd)
      end
    end
```

### Example: When the command has a constraint the id must exist

When the [domain model exists](./examples/domain-object-exists.md) example is used.

```elixir
    test "error when id does not exist" do
      cmd = %<Command>{id: UUID.uuid4()}

      assert {:error, [{:error, :id, :by, "<domain_object> does not exist"}]} = Vex.validate(cmd)
    end

    test "id must exist" do
      id = UUID.uuid4()

      <DomainObject>ReadModel.insert_changeset(%<DomainObject>ReadModel{}, %{
        # properties..
      })
      |> Repo.insert()

      cmd = %<Command>{id: id}

      assert {:ok, _} = Vex.validate(cmd)
    end
```

### Example: Test for Slug (Create Operation)

When using the [unique-slug example](./examples/unique-slug.md). Also include
these tests.

When slug is required, validate the presence:

```elixir
    test "validates presence of slug" do
      cmd = %<Command>{
        id: UUID.uuid4(),
        title: "Vaulting Table",
        slug: nil
      }

      assert {:error, _errors} = Vex.validate(cmd)
    end
```

Check if the slug is unique (against an empty database)

```elixir
    test "check slug for uniqueness" do
      cmd = %<Command>{
        id: UUID.uuid4(),
        title: "Vaulting Table",
        slug: "any-slug"
      }

      assert {:ok, _} = Vex.validate(cmd)
    end
```

Reject, when the slug already exists:

```elixir
    test "rejects when slug is not unique" do
      new_apparatus(%{
        id: UUID.uuid4(),
        title: "Beam",
        slug: "beam"
      })

      cmd = %<Command>{
        id: UUID.uuid4(),
        title: "Balance Beam",
        slug: "beam"
      }

      assert {:error, [{:error, :slug, :by, "slug already exists"}]} =
               Vex.validate(cmd)
    end
```

### Example: Test for Slug (Edit Operation)

When using the [unique-slug example](./examples/unique-slug.md). Also include
these tests.

Slug stays the same as part of the command. No change intended, but payload was given:

```elixir
    test "change title, but keep slug" do
      id = UUID.uuid4()

      new_<domain_object>(%{
        id: id,
        title: "Vaulting Table",
        slug: "vaulting-table"
      })

      cmd = %<Command>{
        id: id,
        title: "Vaulting",
        slug: "vaulting-table"
      }

      assert {:ok, _} = Vex.validate(cmd)
    end
```

Accept slug, when it doesn't exist:

```elixir
    test "check slug for uniqueness" do
      id = UUID.uuid4()

      new_<domain_object>(%{
        id: id,
        title: "Vaulting Table",
        slug: "vaulting-table"
      })

      cmd = %<Command>{
        id: id,
        slug: "any-slug"
      }

      assert {:ok, _} = Vex.validate(cmd)
    end
```

Reject when slug already exists:

```elixir
    test "rejects when slug is not unique" do
      id = UUID.uuid4()

      new_<domain_object>s([
        %{
          id: UUID.uuid4(),
          title: "Beam",
          slug: "beam"
        },
        %{
          id: id,
          title: "Vaulting Table",
          slug: "vaulting-table"
        }
      ])

      cmd = %<Command>{
        id: id,
        slug: "beam"
      }

      assert {:error, [{:error, :slug, :by, "slug already exists"}]} =
               Vex.validate(cmd)
    end
```

Slug is `nil` is the same as no slug is given:

```elixir
    test "does not validate slug when slug is nil" do
      id = UUID.uuid4()

      new_<domain_object>(%{
        id: id,
        title: "Vaulting Table",
        slug: "vaulting-table"
      })

      cmd = %<Command>{
        id: id,
        slug: nil
      }

      assert {:ok, _} = Vex.validate(cmd)
    end
```
