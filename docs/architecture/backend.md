# Backend Architecture

The backend uses hexagonal architecture with ports and adapters.

## Actors

There are two main actors in the codebase

1. Domain actor
2. Web actor

## Domain Actor

This is where the core work is happening, herein lies the business domain.

Location: `/services/api/lib/sportipedia`

### Ports

Each domain object provides a public API. These are the available ports

## Web Actor

Provides a stateless REST API to which clients can connect.

Location: `/services/api/lib/sportipedia_web`

### Ports

The provided endpoints are the ports.

### Adapters

The controller call the public API of the Domain Objects.
