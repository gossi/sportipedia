---
name: build-domain-endpoint
description: Build a web endpoint for a domain operation
agent: builder
model: opencode-go/deepseek-v4-flash
---

# Build Endpoint for Domain Operation: $1

Load the [domain-endpoint recipe](@recipes/domain-endpoint.recipe.md) and execute it.

Parameters:
- `${parameters.operation}` = `$1`
