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
- otherwise the deny/allow pair: `is_guest?(user)` → `:error`,
  `is_user?(user)` → `:ok`.

`is_user?/1` is "authenticated", so an `admin` actor needs no extra clause;
`is_admin?/1` exists for the rare rule that is genuinely admin-only. Using the
shared guards keeps the role checks identical everywhere — do not write a
`user.role == …` comparison in a policy.

## Tests

In the [operation test](./operation-test.md), under `describe "Policy"`: the
guest denial and the user allowance, generated from the same actor list. An
admin or param-dependent case is manual ([Known gaps](../../README.md#known-gaps)).
