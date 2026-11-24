# `sparch` - Sportipedia Architecture

`sparch`, short for "Sportipedia Architecture", is a tool that helps generating
code to comply with the architecture of this project.

## CLI and MCP

`sparch` can be used from CLI as well as MCP. This document shows the CLI calls,
the MCP calls are equivalent.

## Working with Generators

It is designed to generate code for elements in the [domain model](../../docs/domain-model/).

It will generate the respective element in the expected location with the
expected name. For some elements it can generate the entire code, for other
elements that body is left to work out.

### Workflow

The designed workflow is two steps:

1. Run one of the available generators
2. Finish the generated file with the body (if needed)

### Discover and Running Generators

The `sparch` cannot run generators directly. Install the binding for your
programming language and use their toolchain. Either through `pnpm` for
typescript or `mix` for elixir.

There is two ways to discover available generators:

- `sparch capabilities` - comprehensive list of all generators
- `sparch man` - listing of all generators
- `sparch man <generator>` - has detailed information about a generator

The manuals returns the command to execute that generator in a given project.
For example `pnpm spgen <generator> <read-model>` or
`mix sp.gen.command <command>`.

### Asking what changed (`--diff`)

After a domain-model change, generators know what is *missing* but stay quiet
on what *drifted*. `--diff` answers that: it re-renders every unit of the
plan, compares it to the file structurally (immune to `mix format`), and
reports `added`, `changed`, `removed`, `deferred`, and `blocked` per file and
unit, with the fix each one needs. It writes nothing. Suites diff all their
member plans in one pass.

    mix sp.gen.read_model widget --diff
    mix sp.gen.feature position --diff

Exit status: `0` in sync, `1` failure, `3` drift — the suite form is the
verification step after implementing a model change.

## Working with the Domain Model

`sparch` has a couple of additions to ESDM, that assist with code generation.

Run `sparch validate <subpath>` to see if everything for code-generation is
ready.

## Working with the Architecture

In case of doubt where to place an element or how to name it, `sparch` can
answer this question.

- `sparch arch name <element>` - answers with thename for that element
- `sparch arch location <element>` - answers with the location for an element
