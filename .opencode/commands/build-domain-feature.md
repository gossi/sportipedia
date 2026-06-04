---
name: build-domain-feature
description: Build a complete domain feature (operation + endpoint)
agent: builder
model: opencode-go/deepseek-v4-flash
---

# Build Domain Feature: $1

Load the [domain-feature recipe](@recipes/domain-feature.recipe.md) and execute it.

Parameters:
- `${parameters.operation}` = `$1`
