# Event Catalog

This document reflects the events currently defined in the codebase.

## 1. Domain Events Published Through `messaging.Publisher`

These events are emitted by application services.

Current publisher implementation:

- `messaging.NoopPublisher`

That means the events are defined and emitted in code, but are not yet sent to a real broker.

### User Domain

- `user.friend_request.created`
- `user.friend_request.responded`

Source:

- [internal/modules/user/domain/user.go](/Users/gerommebeligon/WorkSpace/portfolio-projects/chat-system/internal/modules/user/domain/user.go)
- [internal/modules/user/app/service.go](/Users/gerommebeligon/WorkSpace/portfolio-projects/chat-system/internal/modules/user/app/service.go)

Payload keys:

- `friend_request`

### Chat Domain

- `chat.message.created`

Source:

- [internal/modules/chat/domain/chat.go](/Users/gerommebeligon/WorkSpace/portfolio-projects/chat-system/internal/modules/chat/domain/chat.go)
- [internal/modules/chat/app/service.go](/Users/gerommebeligon/WorkSpace/portfolio-projects/chat-system/internal/modules/chat/app/service.go)

Payload keys:

- `message`

## 2. Realtime Events Used By The WebSocket Layer

These are not broker-backed integration events right now. They are runtime events used for socket communication.

### Chat Realtime Events

- `chat.message.created`
- `chat.conversation.read`
- `chat.typing.started`
- `chat.typing.stopped`
- `chat.presence.updated`

Source:

- [internal/modules/chat/domain/chat.go](/Users/gerommebeligon/WorkSpace/portfolio-projects/chat-system/internal/modules/chat/domain/chat.go)
- [internal/modules/chat/transport/ws/hub.go](/Users/gerommebeligon/WorkSpace/portfolio-projects/chat-system/internal/modules/chat/transport/ws/hub.go)

### Notification Realtime Event

- `notification.created`

Source:

- [internal/modules/notification/domain/notification.go](/Users/gerommebeligon/WorkSpace/portfolio-projects/chat-system/internal/modules/notification/domain/notification.go)
- [internal/modules/chat/transport/ws/hub.go](/Users/gerommebeligon/WorkSpace/portfolio-projects/chat-system/internal/modules/chat/transport/ws/hub.go)

## 3. Notification Types

These are notification record types, not broker event names.

- `friend_request_received`
- `friend_request_accepted`
- `friend_request_declined`
- `feed_post_comment`
- `feed_comment_reply`

Source:

- [internal/modules/notification/domain/notification.go](/Users/gerommebeligon/WorkSpace/portfolio-projects/chat-system/internal/modules/notification/domain/notification.go)

## 4. Current Architectural Reality

Right now:

- app services emit domain events through a publisher abstraction
- the publisher is a no-op implementation
- realtime user-visible updates happen through the WebSocket hub
- notifications are persisted in PostgreSQL and then pushed to connected users

So the current event model is:

- `published domain events`
  defined and emitted, but not yet broker-backed
- `realtime transport events`
  active and used by the app right now

## 5. Recommended Next Step

The next industry-standard step is:

1. write domain state to PostgreSQL
2. write integration event to `outbox_events`
3. have a consumer publish from outbox to RabbitMQ
4. let downstream handlers trigger notifications, projections, or integrations

This avoids losing events when a request succeeds in the database but fails before publish.
