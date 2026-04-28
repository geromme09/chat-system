# System Overview

## Current Role

This repository is now the backend and mobile shell for **FaceOff Social**.

FaceOff Social is the social platform layer for the FaceOff ecosystem. It owns:

- account identity
- user profile
- friend graph
- chat
- notifications
- mobile social surfaces

It does **not** own the future fighting gameplay stack.

## Runtime Components

- `cmd/api`
  HTTP API for mobile clients and future trusted game integrations
- `cmd/consumer`
  asynchronous event processing and notifications
- `cmd/migrate`
  migration visibility and migration execution
- `mobile/`
  Flutter social companion app for auth, profile, friends, chat, and notifications

## Local Environment

Current local stack:

- Postgres via Docker
- migrations via a dedicated Docker container
- RabbitMQ via Docker
- Redis via Docker
- API in Docker or on the host
- mobile app run separately with Flutter

## High-Level Ecosystem Direction

Planned ecosystem split:

- `FaceOff Social`
  This repo. Source of truth for social identity and user relationships.
- future game client and game services
  Separate game domain responsible for fighter creation, combat, ranking, matchmaking, and match outcomes.

Expected integration direction:

- users authenticate into the game using FaceOff Social credentials or trusted session exchange
- the game stores game-owned fighter and combat data
- FaceOff Social may display a selected fighter summary and rank summary provided by the game domain

## Module Strategy

Current module ownership in this repo:

- `user`
  signup, login, sessions, profile
- `friendship`
  friend requests and accepted friend graph
- `chat`
  conversations, messages, unread state, realtime delivery
- `notification`
  in-app notification fanout and read state

Modules intentionally de-emphasized for this pivot:

- `discovery`
- `challenge`
- `feed`
- `ranking`

These can remain as future placeholders, but they are no longer the product center of gravity.

## Current Implementation Status

Built and working:

- modular monolith backend in Go
- Postgres-backed social flows
- auth and profile management
- profile completion with social-only metadata
- friend requests and accepted friendships
- notifications
- 1:1 chat with realtime socket updates
- Flutter mobile UI for social flows
- paginated friends and notifications lists

Not yet built but now strategically important:

- game integration contract
- public user card suitable for game-linked identity
- selected character summary on profile
- rank summary display sourced from game results
- social challenge / invite patterns for future matches

## Long-Term Deployment Direction

FaceOff Social can remain a modular monolith for a long time if scale allows it.

If growth requires extraction later, likely service candidates would be:

- `identity-api`
- `social-api`
- `chat-api`
- `notification-worker`

The future game stack should be treated as a separate delivery unit from the beginning, even if both products share auth and profile identity.
