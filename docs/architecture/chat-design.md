# Chat Design

## Scope
The chat module provides:
- 1:1 conversation creation
- message send and list
- participant authorization
- future unread and realtime support

## Current runtime shape
- REST endpoints are implemented first
- WebSocket transport is reserved under `internal/modules/chat/transport/ws`
- messages are published to the event bus abstraction for future fanout
- repository implementations should use GORM when Postgres adapters are introduced

## Long-term design
- Postgres stores conversations, participants, messages, and reads
- RabbitMQ fans out chat-related side effects
- WebSocket gateway delivers low-latency message updates

## Scaling note: local connection maps
A local in-memory connection registry or socket map is fine for:
- development
- staging
- early single-instance production

It is not sufficient for multi-instance horizontal scaling because each app instance only tracks the sockets connected to itself.

Implication:
- if user A is connected to instance 1 and user B is connected to instance 2, a message handled only through instance-local memory will not reach both clients reliably

Recommended future path:
- keep the in-memory connection map only as a per-instance delivery cache
- publish message delivery events through RabbitMQ or another shared pub/sub layer
- let each instance consume those events and fan out only to the sockets it owns
- consider sticky sessions only as a temporary aid, not the main scaling strategy

Conclusion:
- this is not a big deal for the first MVP
- it is a real scaling concern later
- the current structure should preserve room for a distributed realtime layer
