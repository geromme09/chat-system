# Backend Go Standards

This document should be used together with [go-backend-skill.md](/Users/gerommebeligon/WorkSpace/portfolio-projects/chat-system/docs/standards/go-backend-skill.md). If there is a conflict, treat the backend skill as the stronger implementation rule for Go backend work.

- Organize code by domain module before technical layer.
- Keep handlers thin and delegate business logic to app services.
- Keep repository logic in `infra`.
- Use GORM for Postgres-backed repository implementations while keeping domain contracts independent from ORM structs where practical.
- Favor simple indexed Postgres queries and avoid adding complexity unless the use case truly needs it.
- Prefer cursor/seek pagination for ordered feeds and timelines.
- Update indexes in the same change whenever a new query pattern is introduced.
- Fetch only the columns needed by the current use case.
- Use `context.Context` in request and async paths.
- Prefer constructor-based dependency injection over globals.
- Use interfaces only at meaningful boundaries.
- Keep cross-module access explicit and narrow.
- Update docs and migrations together with behavior changes.
- Every HTTP endpoint must include Swagger annotations in its handler, and the generated docs must be refreshed before merging.
- Treat Docker Compose as the default local infrastructure setup for Postgres and RabbitMQ.
- Keep module boundaries clean enough that future extraction into Kubernetes-managed services remains practical.

## Mapping To The Backend Skill
- Treat `transport/http` as the handler layer
- Treat `app` as the service layer
- Treat `infra` repository implementations as the repository layer
- Keep business logic out of transport code
- Keep database access behind repository interfaces only
- Use constructor injection for all module wiring

## Cross-Domain Dependency Rules
- Organize backend code by domain module first, not by shared technical layer folders like global `handlers`, `services`, or `repositories`.
- Application services in one domain may depend on another domain only through narrow interfaces that represent the exact capability they need.
- Prefer consumer-defined interfaces for cross-domain collaboration so the dependency stays small and use-case specific.
- A domain must not import another domain's `infra` package.
- A domain must not import another domain's `transport` package.
- Cross-domain wiring belongs in `internal/bootstrap`.
- If a domain starts depending on too many methods from another domain, stop and define a smaller boundary instead of importing the whole service or repository contract.

## Response Format Direction
Target the following response shapes as the standard:

Success:
```json
{
  "data": {},
  "message": "success"
}
```

Error:
```json
{
  "error": "message"
}
```

This should be the direction for future API refinements and refactors.

## API Documentation Rule
- Treat Swagger as part of the endpoint contract, not optional follow-up work.
- Add or update `@Summary`, `@Tags`, `@Accept`, `@Produce`, `@Param`, `@Success`, `@Failure`, and `@Router` annotations in the handler whenever an endpoint is added or changed.
- Regenerate the docs with `make swagger`.
- Swagger UI is served from `http://localhost:8080/swagger/index.html` when the API is running.
