# Chat System

Chat System is a mobile-first sports social app project with a Go backend and a Flutter mobile shell.

## Repository

- GitHub: `https://github.com/geromme09/chat-system`
- Go module: `github.com/geromme09/chat-system`

## Current scope

- Domain-first modular monolith structure in Go
- Runnable API skeleton for auth, profile, and 1:1 chat
- In-memory adapters for fast local development
- SQL migrations for Postgres
- RabbitMQ-ready event contracts for future async flows
- Flutter mobile shell targeting Android and iOS

## Project structure

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

## Backend quick start

1. Copy the environment file.
2. Start local infrastructure and the API.

```bash
cp .env.example .env
make infra-up
```

The API starts on `:8080` by default.

If you prefer to run the API outside Docker:

```bash
make api
```

## Environment

Default values live in [`.env.example`](./.env.example).

```env
APP_ENV=dev
HTTP_ADDR=:8080
TOKEN_SECRET=change-me
POSTGRES_DSN=postgres://postgres:postgres@localhost:5432/chat_system?sslmode=disable
RABBITMQ_URL=amqp://guest:guest@localhost:5672/
STORAGE_BASE_URL=https://cdn.example.com
```

## Local infrastructure with Docker

Start Postgres, run migrations, start Redis and RabbitMQ, and launch the API:

```bash
make infra-up
```

Useful commands:

```bash
make infra-up
make api-logs
make migrate-logs
make infra-logs
```

Postgres uses [`docker/postgres/Dockerfile`](./docker/postgres/Dockerfile), and migrations run through [`docker/migrate/Dockerfile`](./docker/migrate/Dockerfile).

## Migration behavior

- Migrations use `goose` with SQL `Up` and `Down` sections.
- SQL files in [`migrations/`](./migrations) are applied in filename order.
- `goose` supports rollbacks, status inspection, and new migration creation.

Useful migration commands:

```bash
make migrate-up
make migrate-down
make migrate-status
make migrate-create name=add_rank_indexes
```

## Swagger docs

Every API endpoint should be documented with Swagger annotations in its handler, then regenerated into the OpenAPI docs.

Generate the OpenAPI docs:

```bash
make swagger
```

Start the API:

```bash
make infra-up
```

Then access Swagger UI at:

```text
http://localhost:8080/swagger/index.html
```

The generated spec files live in [`docs/swagger/`](./docs/swagger).

Swagger workflow for backend changes:

```bash
make swagger
make test
```

When adding or changing an endpoint, update its Swagger annotations in the handler in the same change.

## Logging

Supported environments:

- `dev`
- `staging`
- `prod`

HTTP request logs include:

- request ID
- method
- path
- URL query string
- status
- remote address
- duration
- request and response sizes

Default logging profile by environment:

- `dev`: access logs on, request/response body debug on, SQL debug on, text logs
- `staging`: access logs off, request/response body debug off, SQL debug off, JSON logs
- `prod`: access logs on, request/response body debug off, SQL debug off, JSON logs

You can still override any default with explicit environment variables.

Request and response bodies are disabled outside `dev` by default for safety. Enable them only when debugging:

```bash
LOG_BODY_DEBUG=true
```

SQL query logging is also optional and can be enabled when you need to inspect GORM activity:

```bash
SQL_LOG_DEBUG=true
SQL_SLOW_THRESHOLD_MS=200
```

## Testing and formatting

```bash
make test
make fmt
```

## Mobile app

Fetch Flutter dependencies:

```bash
make mobile-get
```

Run the mobile app against the backend:

```bash
make mobile-run
```

Override the API host when needed:

```bash
make mobile-run API_BASE_URL=http://<your-machine-ip>:8080
```

## Current API endpoints

- `POST /api/v1/auth/signup`
- `POST /api/v1/auth/login`
- `GET /api/v1/profile/me`
- `PUT /api/v1/profile/me`
- `GET /api/v1/chat/conversations`
- `POST /api/v1/chat/conversations`
- `GET /api/v1/chat/conversations/{id}/messages`
- `POST /api/v1/chat/conversations/{id}/messages`
- `GET /api/v1/sports`
- `GET /healthz`

Use `Authorization: Bearer <token>` for authenticated endpoints.

## Git workflow

For now, the plan is:

1. Push the current baseline to `main`.
2. Create a feature branch for each new feature.
3. Test the feature branch.
4. Merge back into `main` once validated.

Example:

```bash
git checkout -b feature/feature-2
```
