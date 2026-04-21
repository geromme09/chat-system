# API Guidelines

- All endpoints live under `/api/v1`.
- Use a consistent JSON envelope for success and errors.
- Validate input at the edge and enforce authorization in use-case logic.
- Keep request and response DTOs explicit.
- Use versioned event names alongside API changes where async side effects exist.
