# Domain Model for Sportipedia

Sportipedia is in the field of sport. Sport science provides definitions for all terms in this bounded context.
All domain terms shall follow their definitions from established literature and
are not meant to change within the system. Ubiquitous language follows
established sport-science terminology.

The domain is described using the [Event-Sourced Domain Modeling](https://www.esdm.io).

- [Bibliography](../references/literature.bib) Bibtex file with references to
  literature

## Conventions

- **Archive means delete**: in the catalog, archiving a reference-data entry
  (position, apparatus, instrument) removes it from the catalog — no `archived`
  flag, no archived aggregate state, the row leaves the read model and its slug
  becomes reusable, the event stays in the event store, and there is no
  unarchive (see [ADR-0003](../adrs/0003-archiving-removes-from-the-catalog.md)
  and the *Archive means delete* tradeoff in
  [spec-position](../specs/catalog/athlete/spec-position-05-11-2026.md))

## Subdomains

- [Catalog](./catalog/README.md)
