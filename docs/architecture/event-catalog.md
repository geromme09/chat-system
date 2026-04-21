# Event Catalog

## Reserved events
- `user.created.v1`
- `friendship.accepted.v1`
- `chat.message.sent.v1`
- `match.created.v1`
- `challenge.completed.v1`
- `ranking.updated.v1`

## Event rules
- events are versioned from day one
- producers publish from app/use-case level, not HTTP handlers
- important persistence-coupled events should move to an outbox flow when Postgres adapters are introduced
- event contracts should be written as if they may later cross service boundaries in Kubernetes-managed deployments
