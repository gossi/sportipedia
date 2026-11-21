# Test Data

How a test gets the state it needs, and what a passing test is allowed to
prove.

## Table rows go through the fixture, behavior through the API

### DO NOT

Hand-write a `%{title: "sample-title", …}` map into a test that needs a
read-model row — or call the public API to set up state a generated case
already creates.

### DO INSTEAD

Where a case needs a read-model row directly, use the fixture functions
`sparch man test_support` generates
([test-support](test-support.md)): `new_<domain_object>/1` and
`new_<domain_object>s/1`. The fixture is the single source of truth for that
citizen's data, and its id is a stable `UUID.uuid5(:dns, <key>)` the rest of
the graph refers to. Reach state through the **public API** when the test is
about behavior — only a command dispatch builds the event-sourced state an
update or delete acts on. Generated `describe "Aggregate"` and
`describe "Projector"` cases already project the citizen's create event
themselves; add to them, don't pre-seed past them.

## Assert the rule that speaks, never a crash

### DO NOT

Lock in broken behavior with `assert_raise`: a test that asserts the
validator blows up on a blank id passes *only while the 500 bug exists* — it
goes green against a command answering through its own exception.

### DO INSTEAD

Name the rule that should answer and assert its verdict — `[:presence]` for
an absent id, the existence rule's `[:by]` for a malformed one
([domain-object-exists](domain-object-exists.md)). The check the model does
not state goes into the model first, never into a hand-edited assertion —
invariant cases are a known gap the generators do not fill.
