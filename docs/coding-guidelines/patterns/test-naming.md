# Test Naming

What a test's name promises.

## A name is the contract it asserts

### DO NOT

Name a test after the mechanism it exercises, or after a module or private
function.

### DO INSTEAD

An endpoint test's name is the status it asserts ("returns 403 when
unauthenticated") — that is the contract the endpoint owes the client
([status codes](status-codes.md)). An operation test's name says what the
system does through the interface, in the model's vocabulary.
