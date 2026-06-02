---
name: seek-implementation-for-domain-operation
description: Seek implementation details for a read or write CQRS/ES operation in the Sportipedia domain.
---

# Implement Domain Operation

## Overview

Gives implementation details for a piece about exactly ONE! CQRS/ES operation in the Sportipedia domain.
The operation is defined in the [Domain Model](../../../docs/domain-model/README.md).

Context: This should be run when a plan for that operation is ready for implementation.

## When to Use This Skill

Use this skill when:

- You have a plan for implementing a domain operation
- The operation is known
- You are using TDD to implement
- You are seeking implementation details

## Context for Execting the Skill

- [Read Placeholder Naming Substitution](../../../docs/architecture/naming-substitution.md)
- [Respect Code Access Policy](../../code-access-policy.md)
- This skill counts as documentation
- DO not run discovery, this documentation is sufficient

### Code Templates

- Code Templates give you a scaffolding, when creating the file from scratch
- They are templates, not strict guidelines
- Sorting functions in modules when they contain both queries and commands:
  1. All commands
  2. All queries

## Implementation Details

Here is a list of implementation details to seek

### Public API

- One function per command operation
- One function per query operation

#### Command

- Dispatches the command with strong consistency
- Vex runs as commanded middleware and validates the command
- If the command results in a CREATE projection, instantiate a UUID for it
- If the command addresses a read model, return it
- Unless the command resuslts in DELETE projection, then don't

#### Query

- Query Ecto for the read model
  - read one read model: try Internal API fallback to `Repo.get`
  - list many read models: use `Repo.all` with `Sportipedia.Support.JSONAPI.QueryBuilder`
  - all others:
    - may use internal API for partial query
    - use the respective custom query

If the params to the query are `oneOf`, then the params should reflect this, eg: `def <_operation>(id_or_slug) do`. 
Identify this as part of the implementation where to query. Use as much private function as it needs

#### Return Types

Return types for any operation is:

- With result: `{:ok, result} | {:error, reason}`
- Without result: `:ok | {:error, reason}`

#### Code Template

```elixir
defmodule Sportipedia.<Subdomain>.<Composite>.<DomainObject> do
  def <_operation>(params) do
    # implementation logic
  end
end
```

### Policy

Derive authorization from the domain model and present rules and invariants.

- Policy uses the bodyguard framework
- One function for "can actor do x for y"
- Only functions needed for the given operation

### Aggregate

- Use `TypedStruct` (not `defstruct`) for the aggregate struct

#### Evolve State

- One `apply/2` function clause per event type
- Return a new aggregate struct with updated fields
- For events resulting in deleting the aggregate, return `nil`

#### Code Template

```elixir
defmodule Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Aggregate do
  use TypedStruct

  typedstruct do
    field :<field>, type
  end

  def apply(%__MODULE__{} = aggregate, %<Event>{} = event) do
    # apply event to aggregate
  end
end
```

- Pattern match both aggregate and event in the function head

### Command

Read command from the domain model and present rules and invariants.

- Is a commanded command
- Struct creation with enforced fields
  - use TypedStruct
  - use ExConstructor
  - use field-level `enforce: true` on each required field, NOT struct-level `enforce: true`

#### Validation

When needed use `vex` to validate commands.

Read [Vex documentation](https://hexdocs.pm/vex/)

- `use Vex.Struct` on the command
- use `validates :<_field>` with built-in checks, eg. `presence: true`

##### Custom Validations

Vex allows custom validations

- Use a custom validator (see below)
- apply it with `by: [function: &<Validator>.validate/2]` and combine it with needed options, eg. `allow_nil: true`, if domain logic requires it to

#### Code Template

- use `alias` for the validator

```elixir
defmodule Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Command.<Command> do
  use TypedStruct
  use ExConstructor

  typedstruct do
    field :<_field>, <field type>, enforce: true/false
  end

  # Validation
  use Vex.Struct

  validates :title, presence: true
  validates :slug, presence: true, by: [function: &Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Validators.<Validator>.validate/2]
end
```

### Validator

- `use Vex.Validator` on the validator
- **Critical**: Do NOT configure them as "global" validators
- implementation logic:
  - according to test the given invariance
  - May make use of a given query (if applicable)

#### Code Template

```elixir
defmodule Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Validators.<Validator> do
  use Vex.Validator

  def validate(value, _context) do
    # run logic
  end
end
```

### Command Handler

Implement the actual command behavior.

- Is a commanded command-handler
- Takes the command as input
- Outputs events

- Implementation depth:
  - Shallow by mapping the command to events
  - Deep to handle complex business logic

#### Code Template

```elixir
defmodule Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Command.<Command>Handler do
  @behaviour Commanded.Commands.Handler

  def handle(aggregate, %<Command>{} = cmd) do
    # implement logic here
    # return events
  end
end
```

### Events

Facts about the system

- Struct creation with enforced fields
  - use TypedStruct
  - use ExConstructor
- Add `@derive Jason.Encoder` before `typedstruct` to enable JSON serialization
  (required for event serialization in tests and event store)
- Use `typedstruct` (no `enforce: true` at struct level) — enforce only on
  required fields individually. Optional fields must NOT have `enforce: true`.

#### Code Template

```elixir
defmodule Sportipedia.Catalog.<Composite>.<DomainObject>.Event.<Event> do
  use TypedStruct
  use ExConstructor

  @derive Jason.Encoder
  typedstruct do
    field :<_field>, <field type>, enforce: true/false
  end
end
```

### ReadModel

Read Model for querying.

- Struct creation with enforced fields
  - Use TypedEctoSchema
  - Ecto.Changeset
- Contains necessary changeset function for this operation

#### Code Template

```elixir
defmodule Sportipedia.Catalog.<Composite>.<DomainObject>.<DomainObject>ReadModel do
  use TypedEctoSchema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: false}
  @timestamps_opts [type: :utc_datetime_usec]
  @schema_prefix "<_subdomain>"

  typed_schema "<domain_object>" do
    field :<_field>, <field type>, <field opts>

    timestamps()
  end

  # changesets
end
```

#### Migrations

- table name = read model name (as in the domain model)
- table name is singular
- migration can be present
- altering fields needs a migration

### Projection

Applies fact changes to the read-model(s)

- Projector uses `commanded_ecto_projections`
- `project` macro on the Projector
- use changeset functions from read model (if applicable)

```elixir
defmodule Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Projector do
  use Commanded.Projections.Ecto,
    application: Sportipedia.<Subdomain>,
    repo: Sportipedia.<Subdomain>.Repo,
    name: "<_composite>.<domain_object>_projection",
    schema_prefix: "<_subdomain>",
    consistency: :strong

  project %<Event>{} = event, _metadata, fn multi ->
    # projection code
  end
end
```

### Query

- Query modules use `import Ecto.Query` pattern with a struct and `new/1` constructor

#### Code Template

```elixir
defmodule Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Queries.<Query> do
  import Ecto.Query

  def new(params) do
    # construct and return query
  end
end
```

### Internal API

Internal API is used within a constituent (including tests), but never from another constituent or composite.
It contains function giving mnemonic to hide the technical call.
For example, it will very much likely contain a function to retrieve the main domain object.

In other places (eg Public API): Instead of calling Repo directly, use the internal API that is much more memorable.

#### Code Template

```elixir
defmodule Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Internal do
  def <domain_object>_by_id(id) do
    # ecto query to read on record by id
  end

  def <domain_object>_by_id!(id) do
    # ecto query to read on record by id
  end
end
```

## Register

### Register Command

- register at a commanded router
- router locations: `/services/api/lib/sportipedia/<_subdomain>/<_composite>/router.ex`
- dispatch contents:

```elixir
  identify <DomainObject>Aggregate, by: :id, prefix: "<-composite>/<domain-object>/"
  dispatch <Command>, to: <Command>Handler, aggregate: <DomainObject>Aggregate
```

### Projector at Supervisor

- register the projector at a supervisor
- supervisor locations:
  - `/services/api/lib/sportipedia/<_subdomain>/<_composite>/supervisor.ex`
  - `/services/api/lib/sportipedia/<_subdomain>/supervisor.ex`
- add projector to children
