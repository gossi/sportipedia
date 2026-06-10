# Projector

| Attribute | Value |
| --- | --- |
| Schema | [Core](../../schemas/core/v1.yaml) (see `projection`) |
| File Path | `/services/api/lib/sportipedia/<_subdomain>/<_composite>/<domain_object>/projector.ex` |
| Module Name | `Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Projector` |
| Test | See [Operation Test](./operation-test.md) |

## Prerequisite

- The [Domain Model](../../../../domain-model/README.md) contains the projection

## Implementation

Applies fact changes to the read-model(s)

- Projector uses `commanded_ecto_projections`
- `project` macro on the Projector
- use changeset functions from [read model](./read-model.md) (if applicable)

### Implementation Template

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

### Example: `CREATE` Row

```elixir
  project %<Event>{} = event, _metadata, fn multi ->
    multi
    |> Ecto.Multi.insert(
      :<_event>,
      <DomainObject>ReadModel.insert_changeset(Map.from_struct(event))
    )
  end
```

### Example: `UPDATE` Row

```elixir
  project %<Event>{} = event, _metadata, fn multi ->
    case <DomainObject>Internal.<domain_object>_by_id(event.id) do
      nil ->
        multi

      %<DomainObject>ReadModel{} = <domain_object> ->
        # Here the event contains a partial update and has a `get_changes/1` 
        # function to get only the changed fields
        attrs = <Event>.get_changes(event)

        multi
        |> Ecto.Multi.update(
          :<_event>,
          <DomainObject>ReadModel.update_changeset(<domain_object>, attrs)
        )
    end
  end
```

### Example: `DELETE` Row

```elixir
  project %<Event>{} = event, _metadata, fn multi ->
    case <DomainObject>Internal.<domain_object>_by_id(event.id) do
      nil ->
        multi

      %<DomainObject>ReadModel{} = <domain_object> ->
        multi
        |> Ecto.Multi.delete(:<_event>, <domain_object>)
    end
  end
```

### Register Projector at Supervisor

- register the projector at the nearest supervisor
- supervisor locations:
  - `/services/api/lib/sportipedia/<_subdomain>/<_composite>/supervisor.ex`
  - `/services/api/lib/sportipedia/<_subdomain>/supervisor.ex`
- add projector to children

## Test

Tests the projection logic by calling the projector's `handle/2` directly — needs DB.

The `project` macro in `projector.ex` generates a `handle(event, metadata)` function clause.

- Call `handle/2` with the event and a metadata map (see template below)
  - Required fields: `handler_name`, `event_number`
  - The `handler_name` in test metadata MUST exactly match the `:name` option in the projector's `use Commanded.Projections.Ecto` declaration.
  - The `event_number` to be: unique non-negative integer

Example:

```elixir
metadata = %{
  handler_name: "<_projection>",
  event_number: 1,
  event_id: UUID.uuid4(),
  stream_id: "entity-#{event.id}",
  stream_version: 1,
  correlation_id: nil,
  causation_id: nil,
  created_at: DateTime.utc_now(),
  application: Sportipedia.<Subdomain>,
  state: nil
}
```

**Success case:**

```elixir
assert :ok = <Projector>.handle(event, metadata)

record = Repo.get!(ReadModel, event.id)
assert record.field == expected
```

**Idempotency case** (same `event_number` is skipped via `ProjectionVersion`):

```elixir
assert :ok = <Projector>.handle(event, metadata)
assert :ok = <Projector>.handle(event, metadata)

assert [record] == Repo.all(ReadModel)
```

**Error case** (e.g. DB constraint violation):

```elixir
assert {:error, _} == <Projector>.handle(event, metadata)
```
