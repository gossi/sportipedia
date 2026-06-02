---
name: build-domain-feature
description: Implement a read or write CQRS/ES operation in the Sportipedia domain.
agent: domain-driven-developer
model: opencode-go/qwen3.6-plus
---

# Build Domain Feature

A domain feature is represented by the operation itself and the web actor
providing the entrance through the API

Implement domain feature: $1

## Step 1: Find the Domain Operation

1. Use /find-domain-operation $1

## Step 2: Build the Domain Operation

1. /plan-domain-operation $1
2. Proceed implementing the plan with /tdd and combine it with /seek-implementation-for-domain-operation and /seek-implementation-for-domain-operation-test

## Step 3: Build the Operation Endpoint

1. /plan-domain-endpoint $1
2. Proceed implementing the plan with /tdd and /seek-implementation-for-endpoint
