# Backend Go Standards

This document should be used together with [go-backend-skill.md](/Users/gerommebeligon/WorkSpace/portfolio-projects/chat-system/docs/standards/go-backend-skill.md). If there is a conflict, treat the backend skill as the stronger implementation rule for Go backend work.

- Organize code by domain module before technical layer.
- Keep handlers thin and delegate business logic to app services.
- Keep repository logic in `infra`.
- Use GORM for Postgres-backed repository implementations while keeping domain contracts independent from ORM structs where practical.
- Use `context.Context` in request and async paths.
- Prefer constructor-based dependency injection over globals.
- Use interfaces only at meaningful boundaries.
- Keep cross-module access explicit and narrow.
- Update docs and migrations together with behavior changes.
- Treat Docker Compose as the default local infrastructure setup for Postgres and RabbitMQ.
- Keep module boundaries clean enough that future extraction into Kubernetes-managed services remains practical.

## Mapping To The Backend Skill
- Treat `transport/http` as the handler layer
- Treat `app` as the service layer
- Treat `infra` repository implementations as the repository layer
- Keep business logic out of transport code
- Keep database access behind repository interfaces only
- Use constructor injection for all module wiring

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
