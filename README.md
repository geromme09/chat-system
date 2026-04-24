# FaceOff Social

FaceOff Social is the social platform layer for the broader FaceOff ecosystem.

It is responsible for:

- account registration and login
- player profile and identity
- friend graph
- direct chat
- notifications
- mobile companion experience for player social features

It is not the fighting game client itself. The planned game experience will authenticate through FaceOff Social and may later publish selected character summaries back into the social app.

## Repository

- GitHub: `https://github.com/geromme09/chat-system`
- Go module: `github.com/geromme09/chat-system`

## Product Role

FaceOff Social is the player-facing social service that sits beside the future FaceOff game layer.

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

- clearer public player card / player identity surface
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
STORAGE_BASE_URL=http://localhost:8080
STORAGE_LOCAL_DIR=var/storage
```

## Local Infrastructure With Docker

```bash
make infra-up
make infra-down
make infra-logs
make api-logs
make migrate-logs
```

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
