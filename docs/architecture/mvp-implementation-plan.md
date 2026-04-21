# Mobile-First Sports Social App MVP Implementation Plan

## Summary
This project will be built as a **domain-first modular monolith** in Go, with clear module boundaries, event contracts, and RabbitMQ-ready async workflows so we can split parts into microservices later without rewriting the core business logic.

Persistence direction for the Go backend:
- use **GORM** as the ORM on top of Postgres
- keep repository boundaries at the module level even when GORM is used
- avoid leaking raw GORM models directly into transport contracts

Local development direction:
- use **Docker Compose** for local testing of infrastructure services
- keep the app runnable outside Docker as well for faster inner-loop development
- standardize local Postgres and RabbitMQ startup through Docker first
- run migrations in a dedicated container so local behavior matches the planned Kubernetes deployment model

The first user-facing slice is:
- signup and login
- profile onboarding with picture
- QR-based friend connections
- 1:1 chat

After that, the roadmap expands into:
- nearby swipe-based discovery by sport
- challenge flows
- feed posts
- rankings by sport and geography

This document is the working implementation baseline for both backend and mobile.

## Product Direction
The app is not positioned as a pure dating app. It is a mobile-first social sports platform where users can:
- meet nearby people who want to play a sport
- add existing real-life friends through QR
- chat one-to-one
- challenge other people to play
- post results or videos
- earn rank points in specific sports
- view rankings by barangay, city, or country

The main differentiator is the combination of:
- social connection
- local sports discovery
- real-world challenge participation
- lightweight competition and rankings

## Architecture Direction

### Core approach
We will start with a **single deployable backend** and one primary Postgres database.

RabbitMQ will be introduced for:
- async workflows
- notifications
- event-driven side effects
- future service decoupling

For chat realtime delivery, a local in-memory WebSocket connection map is acceptable for:
- local development
- single-instance deployment
- early MVP validation

However, it is **not horizontally scalable** by itself. When the system scales to multiple instances:
- each instance will only know about its own connected clients
- a message published on one instance will not automatically reach sockets connected to another instance
- we will need a shared fanout strategy such as RabbitMQ-backed delivery events, Redis pub/sub, or a dedicated realtime gateway

This is not a blocker for the first MVP, but it must not be treated as the final scaling design.

We will not start with independent deployable microservices. Instead, we will structure the code so each domain can be extracted later if needed.

For local testing, Docker will be the default environment for:
- Postgres
- RabbitMQ
- future supporting services such as Redis, object storage emulators, or mail testing tools

Long-term deployment direction:
- the system is expected to move toward **microservice architecture on Kubernetes**
- likely deployable units may include services such as `chat-api`, `challenge-api`, `discovery-api`, `feed-api`, and supporting worker or consumer processes
- the mobile app remains a separate client application and should be treated as its own delivery unit, even if internal naming later uses terms like `chat-mobile`
- current repo boundaries should make that split easier later, not harder

### Main principles
- Organize by business domain, not by technical layer alone
- Keep shared infrastructure in a small platform layer
- Keep module ownership explicit
- Keep API contracts and event contracts stable early
- Use documentation and database design as part of implementation, not after implementation

## Recommended Repository Structure

```text
chat-system/
├── cmd/
│   ├── api/
│   │   └── main.go
│   ├── consumer/
│   │   └── main.go
│   └── migrate/
│       └── main.go
├── internal/
│   ├── bootstrap/
│   │   ├── api.go
│   │   ├── app.go
│   │   └── consumer.go
│   ├── platform/
│   │   ├── auth/
│   │   ├── config/
│   │   ├── db/
│   │   ├── httpx/
│   │   ├── logger/
│   │   ├── messaging/
│   │   ├── storage/
│   │   └── validate/
│   └── modules/
│       ├── user/
│       │   ├── domain/
│       │   ├── app/
│       │   ├── infra/
│       │   └── transport/http/
│       ├── friendship/
│       │   ├── domain/
│       │   ├── app/
│       │   ├── infra/
│       │   └── transport/http/
│       ├── chat/
│       │   ├── domain/
│       │   ├── app/
│       │   ├── infra/
│       │   ├── transport/http/
│       │   └── transport/ws/
│       ├── discovery/
│       ├── challenge/
│       ├── feed/
│       ├── ranking/
│       └── notification/
├── api/
│   └── openapi/
├── contracts/
│   └── events/
├── migrations/
├── test/
│   ├── fixtures/
│   └── integration/
├── docs/
│   ├── adr/
│   ├── architecture/
│   ├── database/
│   └── standards/
├── mobile/
│   └── lib/
│       ├── app/
│       ├── core/
│       └── features/
├── scripts/
├── deploy/
├── .env.example
├── docker-compose.yml
├── Makefile
└── README.md
```

## Why This Structure

### Domain-first modules
Each domain owns its own:
- business rules
- HTTP or WebSocket transport
- persistence logic
- events

This prevents one giant `service` package or one giant `model` package from becoming unmanageable.

### Platform layer
`internal/platform` is only for technical shared concerns such as:
- configuration
- database connection
- validation
- logging
- auth utilities
- storage
- RabbitMQ wiring

This layer should not contain business rules.

### Bootstrap layer
`internal/bootstrap` wires the application together:
- config loading
- connection setup
- module registration
- HTTP server setup
- consumer registration

### Contracts
Keep explicit contracts in:
- `api/openapi` for HTTP APIs
- `contracts/events` for event payloads and versions

These contracts help us avoid implicit coupling and make later service extraction easier.

## Domain Boundaries

### User
Owns:
- signup
- login
- sessions
- profile setup
- avatar metadata
- sport preferences
- skill level
- visibility settings
- location metadata

Likely tables:
- `sports`
- `users`
- `user_profiles`
- `auth_accounts`
- `auth_sessions`
- `user_sports`
- `location_scopes`

### Friendship
Owns:
- QR-based friend add
- friend requests
- accept/decline/remove
- block rules
- friend-based chat eligibility

Likely tables:
- `friendships`
- `friend_qr_tokens`

### Chat
Owns:
- conversations
- conversation participants
- messages
- unread counts
- read state
- realtime delivery

Likely tables:
- `conversations`
- `conversation_participants`
- `messages`
- `message_reads`

### Discovery
Owns:
- nearby player browsing
- swipe decisions
- mutual matches
- stranger-chat eligibility
- distance and privacy rules

Likely tables:
- `discovery_preferences`
- `swipe_actions`
- `matches`

### Challenge
Owns:
- challenge creation
- scheduling
- status lifecycle
- result recording
- winner confirmation

Likely tables:
- `challenges`
- `challenge_results`

### Feed
Owns:
- feed posts
- challenge recap posts
- media metadata
- content visibility rules

Likely tables:
- `feed_posts`
- `feed_media`

### Ranking
Owns:
- rank point calculation
- leaderboard queries
- geographic ranking scopes

Likely tables:
- `rank_entries`

### Notification
Owns:
- push notification orchestration
- in-app notification delivery
- async fanout handling

This can begin as a lightweight module and expand later.

## Module Internal Shape
Each module should follow this internal structure:

- `domain`
  Entities, value objects, repository interfaces, rules, and domain events
- `app`
  Use cases, commands, queries, DTOs, and transaction orchestration
- `infra`
  Postgres repositories, RabbitMQ publishers/consumers, storage adapters
- `transport/http`
  Handlers, request DTOs, response DTOs, and route registration
- `transport/ws`
  Only for modules that need realtime communication, mainly chat

This keeps the code understandable and prevents transport or persistence code from leaking into domain rules.

## Coding Standards And Patterns

### Backend Go
- Follow idiomatic Go naming and file organization
- Keep handlers thin
- Keep use cases in the app layer
- Keep data access in repositories
- Use interfaces mainly at architectural boundaries
- Pass `context.Context` through request and async flows
- Keep DTOs separate from domain and persistence models where needed
- Centralize error mapping, logging, and validation

### Design patterns to apply
- Layered flow inside each module: transport -> app -> domain/repository
- Repository pattern for data access
- Transaction boundary at app/use-case level
- Outbox pattern for important domain events tied to DB state
- Constructor-based dependency injection

### Patterns to avoid
- God services
- giant utility packages
- handlers with business logic
- cross-module table access
- premature microservice splitting
- unnecessary interfaces for every type

## Mobile App Structure
The Flutter app should mirror the backend domain structure.

```text
mobile/lib/
├── app/
│   ├── app.dart
│   ├── router.dart
│   └── theme/
├── core/
│   ├── api/
│   ├── constants/
│   ├── forms/
│   ├── storage/
│   └── widgets/
└── features/
    ├── auth/
    ├── profile/
    ├── friendship/
    ├── chat/
    ├── discovery/
    ├── challenge/
    ├── feed/
    └── ranking/
```

Frontend rules:
- organize by feature
- separate presentation, state, and data concerns
- build reusable design tokens and core components
- keep navigation consistent
- keep forms and validation patterns consistent

## MVP Delivery Roadmap

### MVP 0: Foundation And Documentation
Goal: establish the development base before feature growth.

Deliver:
- backend bootstrap
- config loading
- DB and RabbitMQ wiring
- migration tooling
- shared API response and error shape
- coding standards docs
- system design docs
- database docs
- ADR template and initial ADRs
- mobile shell structure

### MVP 1: Signup, Profile, And Chat
Goal: ship the first usable social loop.

Deliver:
- signup and login
- profile onboarding
- profile picture metadata and upload flow
- session handling
- conversation list
- 1:1 message send/list/read
- unread tracking
- WebSocket-based live delivery

Product defaults:
- local/basic auth first
- reserve schema for future Google, Facebook, and phone login
- reserve schema for verification state

### MVP 2: QR Friends
Goal: support real-life friend connections.

Deliver:
- generate QR
- scan/import QR
- send friend request
- accept/decline/remove
- friend list
- start chat from friends

### MVP 3: Discovery And Swipe
Goal: introduce sports-based stranger discovery.

Deliver:
- sports selection
- nearby browsing
- distance filtering
- like/pass actions
- mutual match creation
- match-based chat eligibility

### MVP 4: Challenges
Goal: turn discovery into actual sport meetups.

Deliver:
- create sport challenge
- invite friend or match
- accept/decline/cancel
- proposed area and time
- result recording
- winner confirmation

### MVP 5: Feed And Rankings
Goal: create a visible loop that drives retention.

Deliver:
- challenge result posts
- short video feed posts
- rank point updates
- leaderboards by barangay, city, and country

## API Direction
Public API groups:
- `/api/v1/auth`
- `/api/v1/profile`
- `/api/v1/sports`
- `/api/v1/friends`
- `/api/v1/chat`
- `/api/v1/discovery`
- `/api/v1/challenges`
- `/api/v1/feed`
- `/api/v1/rankings`

API rules:
- version APIs from the start
- use a consistent error envelope
- use a consistent pagination format
- keep auth and authorization checks at service/use-case level, not only handlers
- define idempotency where retries matter

## Event Direction
RabbitMQ events should be named and versioned explicitly.

Examples:
- `user.created.v1`
- `friendship.accepted.v1`
- `chat.message.sent.v1`
- `match.created.v1`
- `challenge.completed.v1`
- `ranking.updated.v1`

Consumer design rules:
- `cmd/consumer` only wires consumers to module handlers
- business logic lives in module use cases
- important DB state changes should publish through an outbox pattern when needed

## Documentation To Maintain

### Architecture docs
- `docs/architecture/system-overview.md`
- `docs/architecture/domain-boundaries.md`
- `docs/architecture/chat-design.md`
- `docs/architecture/discovery-design.md`
- `docs/architecture/challenge-ranking-design.md`
- `docs/architecture/event-catalog.md`
- `docs/architecture/api-overview.md`

### Database docs
- `docs/database/erd.md`
- `docs/database/schema-decisions.md`
- schema dictionary
- migration convention notes
- seed data notes
- retention notes for messages, media, and location-derived data

### Standards docs
- `docs/standards/backend-go.md`
- `docs/standards/frontend-flutter.md`
- `docs/standards/api-guidelines.md`

### ADRs
Start with:
- modular monolith first
- Postgres as source of truth
- RabbitMQ for async workflows
- Flutter for mobile-first client
- REST-first API plus WebSocket for chat

## Database Ownership
- `user` owns `users`, `user_profiles`, `auth_accounts`, `auth_sessions`, `user_sports`, `location_scopes`
- `friendship` owns `friendships`, `friend_qr_tokens`
- `chat` owns `conversations`, `conversation_participants`, `messages`, `message_reads`
- `discovery` owns `discovery_preferences`, `swipe_actions`, `matches`
- `challenge` owns `challenges`, `challenge_results`
- `feed` owns `feed_posts`, `feed_media`
- `ranking` owns `rank_entries`
- shared infrastructure owns `outbox_events`

No module should directly own another module's tables.

## Test Direction

### MVP 0-1
- signup success and failure
- login and session lifecycle
- profile onboarding validation
- avatar metadata flow
- conversation creation
- send, list, and read messages
- WebSocket delivery and reconnect behavior
- unauthorized access rejection

### MVP 2
- QR generation and safe resolution
- friend request lifecycle
- friend-based chat bootstrap
- block restrictions

### MVP 3
- sport and distance filters
- like/pass behavior
- mutual match uniqueness
- privacy-safe distance display

### MVP 4
- valid and invalid challenge transitions
- result confirmation
- event generation after completion

### MVP 5
- feed post creation
- rank point updates
- leaderboard correctness by geographic scope

## Microservice Extraction Roadmap
We will not split early, but the structure should support later extraction.

Most likely extraction order:
1. `chat` if realtime load grows significantly
2. `feed` if media processing becomes heavy
3. `discovery`, `challenge`, and `ranking` into a play-related bounded context if scaling or team ownership requires it
4. `user` only when auth, verification, and trust/safety become complex enough

Until then:
- one backend deployable
- one primary Postgres database
- one RabbitMQ broker
- clear internal boundaries

Future infrastructure note:
- when services are extracted, they are expected to run as separate Kubernetes workloads
- API traffic, worker traffic, and realtime traffic should be designed with that separation in mind
- shared in-memory state must never become a long-term cross-service dependency

## Current Working Decisions
- mobile-first product
- Flutter frontend
- Go backend
- Postgres primary database
- RabbitMQ for async processing
- modular monolith first
- domain-first code organization
- signup/profile/chat as first implemented slice
- QR friend flow before stranger swipe
- verification and social login deferred but designed for

## Implementation Reminder
Every milestone must include:
- code
- tests
- documentation updates
- schema updates if needed
- architecture notes when major design choices change

This plan should be treated as the source reference before implementation starts.
