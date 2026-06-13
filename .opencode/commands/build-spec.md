---
name: build-spec
description: Build a given spec
agent: builder
model: opencode-go/deepseek-v4-flash
---

# Build Spec: $1

Load the [spec recipe](@recipes/spec.recipe.md) and execute it.

Parameters:

- `${parameters.spec_path}` = `$1`
