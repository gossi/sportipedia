---
generator: "mix sp.gen.policy <operation>"
blueprints:
  - SpGen.Blueprint.Policy
  - SpGen.Blueprint.PolicyTest
module: "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Policy"
writes: [module, operation test]
---

# Policy

One answer per operation: may this actor do this. Bodyguard, and the shared
guards from `Sportipedia.Auth.Roles` — nothing else.

## Prerequisite

- The [Domain Model](../../../../domain-model/README.md) lists the operation's
  `actors`.

## What the generator does

It appends the operation's `authorize/3` clause(s) to the constituent's policy,
creating the file with `@behaviour Bodyguard.Policy` and the `import
Sportipedia.Auth.Roles` when missing:

- `guest` among the actors → one open clause: `authorize(:op, _user, _params), do: :ok`.
- `admin` as the **only** actor → guest denial, `is_admin?` allowance, and an
  explicit denial of every other authenticated user:

  ```elixir
  def authorize(:op, user, _params) when is_guest?(user), do: :error
  def authorize(:op, user, _params) when is_admin?(user), do: :ok
  def authorize(:op, user, _params) when is_user?(user), do: :error
  ```

- otherwise the deny/allow pair: `is_guest?(user)` → `:error`,
  `is_user?(user)` → `:ok`.

`is_user?/1` is `not is_guest?/1` — "authenticated", *not* "an admin": an
`admin`-only actor list generated from the deny/allow pair would admit every
authenticated user, so the generator derives the `is_admin?` clause from the
model instead (`SpGen.Blueprint.Policy.admin_only?/1`). Using the shared guards
keeps the role checks identical everywhere — do not write a `user.role == …`
comparison in a policy.

## Tests

In the [operation test](./operation-test.md), under `describe "Policy"`: the
guest denial and the user allowance, generated from the same actor list — for
an `admin`-only list, all three answers (guest denied, non-admin user denied,
admin allowed). A param-dependent case is manual
([Known gaps](../../README.md#known-gaps)).
