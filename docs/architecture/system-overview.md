# System Overview

The backend is a modular monolith in Go with one primary HTTP API process and one consumer process for asynchronous work.

## Runtime components
- `cmd/api`: HTTP API for mobile clients
- `cmd/consumer`: asynchronous event processing and notifications
- `cmd/migrate`: migration visibility and future migration execution

## Local environment
For local testing, infrastructure services should run through Docker Compose.

Current local stack direction:
- Postgres via Docker
- migrations via a dedicated Docker container
- RabbitMQ via Docker
- API and consumer can run either on the host machine or inside containers later

## Module strategy
- `user`: signup, login, sessions, profile
- `friendship`: QR friend flows
- `chat`: conversations and messages
- `discovery`: nearby swipe discovery
- `challenge`: challenge lifecycle
- `feed`: posts and media metadata
- `ranking`: score and leaderboard logic
- `notification`: push and in-app fanout

## Current implementation status
- Foundations and standards documented
- In-memory application adapters for `user` and `chat`
- Schema and event contracts laid out for future Postgres and RabbitMQ adapters

## Long-term deployment note
The current implementation starts as a modular monolith, but the intended direction is a Kubernetes-managed service topology when the product grows.

Examples of future deployable units:
- `chat-api`
- `challenge-api`
- `discovery-api`
- `feed-api`
- dedicated consumer or worker deployments

The mobile app is a separate client application and should evolve independently from backend deployables.
