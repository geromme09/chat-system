# FaceOff Social

FaceOff Social is the social platform layer for the broader FaceOff ecosystem.

It is responsible for:

- account registration and login
- user profile and identity
- friend graph
- direct chat
- notifications
- mobile companion experience for social features

It is not the fighting game client itself. The planned game experience will authenticate through FaceOff Social and may later publish selected character summaries back into the social app.

## Repository

- GitHub: `https://github.com/geromme09/chat-system`
- Go module: `github.com/geromme09/chat-system`

## Product Role

FaceOff Social is the user-facing social service that sits beside the future FaceOff game layer.

Current direction:

- `FaceOff Social`
  The identity, friends, chat, and notification platform
- `FaceOff Arena` or equivalent future game client
  Character creation, fighting gameplay, matchmaking, ranking, and match results

## Current Progress

Implemented or working now:

- signup and login
- profile read and update flow
- profile completion flow with optional gender and hobbies
- self-profile navigation from the feed back into the main mobile shell
- friend requests
- accepted friendships
- feed post creation, reactions, comments, and replies
- notifications for friend request events
- notifications when someone comments on your post
- notifications when someone replies to your comment
- 1:1 chat conversations
- realtime chat socket support
- Flutter mobile shell for auth, chat, friends, notifications, and profile
- paginated friends and notifications APIs with mobile lazy loading

Already polished enough for the current phase:

- chat screen hierarchy and spacing
- lightweight bottom navigation
- notifications interaction rules for friend requests, post comments, and comment replies
- route transitions for pushed screens
- post detail flow that lets notification taps reopen the post conversation context

## What Is Still Missing

Before FaceOff Social is a solid long-term platform for the game ecosystem, we still need:

- clearer public user card / identity surface
- stable profile fields that are useful outside chat
- game-facing identity integration plan
- selected fighter summary display in profile once the game exists
- friend challenge / invite surfaces if the game needs social invites
- match history and ranking summary display once the game starts sending results
- stronger API and data contracts between Social and the future game service
- production-grade auth/session strategy if the game becomes a separate client

## What Should Not Move Into This Repo

The following belong to the future game domain, not FaceOff Social:

- fighting gameplay
- hitboxes, moves, combos, and combat systems
- controller and voice combat input
- fighter animation systems
- in-match ranking logic
- core matchmaking orchestration for live fights
- full character generation pipeline and asset production

FaceOff Social may display game-owned data, but it should not become the source of truth for combat systems.

## Project Structure

```text
.
├── cmd/          # application entry points
├── internal/     # domain modules and platform code
├── migrations/   # SQL migration files
├── docker/       # local database and migration images
├── docs/         # architecture and standards
├── contracts/    # event contracts
├── test/         # integration tests
└── mobile/       # Flutter mobile shell
```

## Current Tech Stack

- Backend: Go 1.25
- HTTP API: Gin
- Database: PostgreSQL
- ORM: GORM
- Cache / realtime support: Redis
- Messaging infra: RabbitMQ
- Object storage: MinIO locally, through an S3-compatible storage adapter
- Structured logging: Zap
- Metrics: Prometheus
- Tracing: OpenTelemetry -> Jaeger
- Log aggregation: Loki + Promtail
- Dashboards: Grafana
- Mobile app: Flutter
- Local orchestration: Docker Compose
- API docs: Swagger / OpenAPI

Messaging note:

- RabbitMQ is part of the local infrastructure and target architecture
- current application event publishing still uses a `NoopPublisher`
- realtime chat and notification updates currently flow through the WebSocket hub, not RabbitMQ

## Architecture Docs

- System overview: [docs/architecture/system-overview.md](/Users/gerommebeligon/WorkSpace/portfolio-projects/chat-system/docs/architecture/system-overview.md)
- Domain boundaries: [docs/architecture/domain-boundaries.md](/Users/gerommebeligon/WorkSpace/portfolio-projects/chat-system/docs/architecture/domain-boundaries.md)
- Architecture diagrams: [docs/architecture/architecture-diagrams.md](/Users/gerommebeligon/WorkSpace/portfolio-projects/chat-system/docs/architecture/architecture-diagrams.md)
- Current vs target system design: [docs/architecture/current-vs-target-system-design.md](/Users/gerommebeligon/WorkSpace/portfolio-projects/chat-system/docs/architecture/current-vs-target-system-design.md)
- Observability backlog: [docs/observability-backlog.md](/Users/gerommebeligon/WorkSpace/portfolio-projects/chat-system/docs/observability-backlog.md)

## Backend Quick Start

To start the full local stack:

```bash
cp .env.example .env
make infra-up
```

The API starts on `:8080` by default.

To run only the Go API on the host:

```bash
make api
```

To run only the API container with Docker dependencies:

```bash
docker compose up -d --build api
```

## Environment

Default values live in [`.env.example`](./.env.example).

```env
APP_ENV=dev
HTTP_ADDR=:8080
TOKEN_SECRET=change-me
POSTGRES_DSN=postgres://postgres:postgres@localhost:5432/chat_system?sslmode=disable
RABBITMQ_URL=amqp://guest:guest@localhost:5672/
REDIS_ADDR=localhost:6379
STORAGE_BASE_URL=http://localhost:8080
STORAGE_DRIVER=s3
STORAGE_PUBLIC_BASE_URL=http://localhost:9000
STORAGE_S3_ENDPOINT=localhost:9000
STORAGE_S3_ACCESS_KEY=minioadmin
STORAGE_S3_SECRET_KEY=minioadmin
STORAGE_S3_REGION=us-east-1
STORAGE_S3_USE_SSL=false
STORAGE_S3_PROFILE_BUCKET=profile-media
STORAGE_S3_POST_BUCKET=post-media
OBS_ENABLED=true
OBS_SERVICE_NAME=chat-system-api
TRACING_ENABLED=true
OTEL_EXPORTER_OTLP_ENDPOINT=localhost:4318
OTEL_EXPORTER_OTLP_INSECURE=true
OTEL_TRACE_SAMPLE_RATIO=1
METRICS_ENABLED=true
```

## Local Infrastructure With Docker

```bash
make infra-up
make infra-down
make infra-logs
make api-logs
make migrate-logs
```

Local service ports:

- API: `http://localhost:8080`
- Prometheus: `http://localhost:9090`
- Grafana: `http://localhost:3000`
- Jaeger: `http://localhost:16686`
- Loki: `http://localhost:3100`
- MinIO API: `http://localhost:9000`
- MinIO Console: `http://localhost:9001`
- Postgres: `localhost:5432`
- Redis: `localhost:6379`
- RabbitMQ: `localhost:5672`
- RabbitMQ Console: `http://localhost:15672`

Grafana defaults:

- user: `admin`
- password: `admin`

## Observability

Current local observability flow:

- API writes structured JSON logs to `stdout` with Zap
- Promtail tails Docker container logs and ships them to Loki
- Prometheus scrapes `GET /metrics`
- OpenTelemetry sends traces to Jaeger over OTLP HTTP
- Grafana reads Prometheus, Loki, and Jaeger as datasources

## Migrations

```bash
make migrate-up
make migrate-down
make migrate-status
make migrate-create name=add_rank_indexes
```

## Testing And Formatting

```bash
make test
make fmt
```

## Mobile App

```bash
make mobile-get
make mobile-run
```

Override the API host when needed:

```bash
make mobile-run API_BASE_URL=http://<your-machine-ip>:8080
```

## Media Storage

Current media flow:

- mobile sends avatar and post images to the backend using `multipart/form-data`
- backend validates the uploaded bytes as real images
- backend uploads image bytes to MinIO through the S3-compatible storage adapter
- backend stores media metadata in PostgreSQL
- backend rebuilds public image URLs from stored metadata on reads

What is stored in MinIO:

- the actual image bytes
- object bucket
- object key
- object content type

What is stored in PostgreSQL:

- profile avatars: `user_profiles.avatar_bucket`, `user_profiles.avatar_key`, `user_profiles.avatar_type`
- post media: `feed_media.bucket`, `feed_media.object_key`, `feed_media.content_type`

Current bucket layout:

- `profile-media`
- `post-media`

Example object keys:

- `profiles/{userID}/avatar/{uuid}.jpg`
- `posts/{uuid}.png`

Notes:

- MinIO is the local object storage server
- the application uses a generic `s3` storage driver, so AWS S3 migration is config-driven
- legacy URL columns still exist as read fallback for older rows during transition

## Current API Surface

Implemented endpoints include:

- `POST /api/v1/auth/signup`
- `POST /api/v1/auth/login`
- `GET /api/v1/profile/me`
- `PUT /api/v1/profile/me`
- `GET /api/v1/profile/{userID}`
- `GET /api/v1/users/search`
- `POST /api/v1/friends/requests`
- `GET /api/v1/friends`
- `GET /api/v1/notifications`
- `POST /api/v1/notifications/read-all`
- `POST /api/v1/notifications/{id}/read`
- `GET /api/v1/feed`
- `POST /api/v1/feed`
- `GET /api/v1/feed/{id}`
- `POST /api/v1/feed/{id}/reactions`
- `GET /api/v1/feed/{id}/comments`
- `POST /api/v1/feed/{id}/comments`
- `GET /api/v1/chat/conversations`
- `POST /api/v1/chat/conversations`
- `GET /api/v1/chat/conversations/{id}/messages`
- `POST /api/v1/chat/conversations/{id}/messages`
- `GET /api/v1/chat/unread-count`
- `GET /healthz`

Use `Authorization: Bearer <token>` for authenticated endpoints.

## Next Planning Focus

The next documentation and implementation phase should define:

- FaceOff Social responsibilities vs future game responsibilities
- the minimum shared identity contract between social and game
- what game-created character data is mirrored into social
- what progression summaries Social should display
- which current onboarding fields remain social-only and which move into fighter creation later
