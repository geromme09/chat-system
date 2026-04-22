# Observability Backlog

This is the follow-up checklist for logging, tracing, metrics, and Kibana work.

The current chat system is good enough for MVP development, but we should add the items below before we treat realtime chat as production-ready.

## Chat Realtime

- Add structured logs for WebSocket connect, disconnect, reconnect attempt, reconnect success, ping timeout, and failed write.
- Include `user_id`, `conversation_id`, `request_id`, and `instance_id` in chat-related logs when available.
- Track active WebSocket connection count and per-user connection count.
- Add counters for realtime delivery attempts, realtime delivery successes, and realtime delivery failures.
- Add reconnect counters and reconnect-duration metrics on the mobile/client side if we later add client telemetry.

## Chat API

- Measure send-message latency end to end: HTTP request -> Postgres write -> realtime delivery attempt.
- Measure unread-count query latency and mark-conversation-read latency.
- Add counters for conversation creation, message send, message history fetch, unread-count fetch, and read-mark operations.
- Add error-rate metrics per chat endpoint.

## Tracing

- Add tracing for chat send flow:
  request received -> auth -> conversation lookup -> message persistence -> realtime publish attempt -> response.
- Add tracing for read flow:
  request received -> auth -> unread lookup -> message_reads insert/update -> response.
- Add trace correlation between HTTP requests and realtime delivery attempts where possible.

## Kibana / Dashboards

- Build a dashboard for active WebSocket connections over time.
- Build a dashboard for realtime delivery success vs failure.
- Build a dashboard for reconnect spikes and disconnect spikes.
- Build a dashboard for chat send volume and message-read volume.
- Build a dashboard for slow chat endpoints and slow database queries related to chat.

## Alerts

- Alert on unusual disconnect spikes.
- Alert on elevated realtime delivery failure rate.
- Alert on high chat endpoint error rate.
- Alert on sustained slow chat queries or slow message send latency.

## Safety

- Never log auth tokens.
- Do not log full message bodies by default.
- If temporary debug logging for message content is ever enabled, keep it behind an explicit environment toggle and disable it by default.
- Redact personally sensitive fields consistently before shipping logs to central storage.

## Future Scale

- When we add cross-instance delivery, add metrics for pub/sub or queue fanout lag.
- Add visibility into which API instance owns which live socket connections.
- Track dropped cross-instance deliveries and resync fallback frequency.
