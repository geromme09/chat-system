# Chat System

Mobile-first sports social app backend and mobile shell.

## Current scope
- Domain-first modular monolith structure
- MVP 0 foundation docs and project standards
- Runnable Go API skeleton for signup, login, profile, and 1:1 chat
- In-memory adapters for local development
- SQL migrations and event contracts for long-term Postgres and RabbitMQ integration

## Run the API
```bash
cp .env.example .env
go run ./cmd/api
```

The API starts on `:8080` by default.

## Local infrastructure with Docker
Start Postgres, run migrations, and start RabbitMQ:
```bash
docker compose up -d
```

This is the default local testing path for infrastructure services.

Postgres now uses the local Docker build at [docker/postgres/Dockerfile](/Users/gerommebeligon/WorkSpace/portfolio-projects/chat-system/docker/postgres/Dockerfile), so we can extend it with init scripts and local DB setup as the backend moves to GORM.
Migrations run in a separate container using [docker/migrate/Dockerfile](/Users/gerommebeligon/WorkSpace/portfolio-projects/chat-system/docker/migrate/Dockerfile), which mirrors the future Kubernetes pattern of running schema changes in an isolated workload.

## Migration behavior
- SQL files in [migrations](/Users/gerommebeligon/WorkSpace/portfolio-projects/chat-system/migrations) are applied in filename order
- a `schema_migrations` table tracks which files already ran
- rerunning `docker compose up` only applies new migration files that have not been recorded yet

Useful commands:
```bash
docker compose up -d
docker compose logs migrate
docker compose ps
```

## Current endpoints
- `POST /api/v1/auth/signup`
- `POST /api/v1/auth/login`
- `GET /api/v1/profile/me`
- `PUT /api/v1/profile/me`
- `GET /api/v1/chat/conversations`
- `POST /api/v1/chat/conversations`
- `GET /api/v1/chat/conversations/{id}/messages`
- `POST /api/v1/chat/conversations/{id}/messages`

Use `Authorization: Bearer <token>` for authenticated endpoints.
