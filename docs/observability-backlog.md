# Observability Backlog

This file tracks what is already in place and what still needs to be added.

## Current Baseline

Implemented now:

- `zap` structured logging to `stdout`
- Prometheus scrape endpoint at `GET /metrics`
- generic HTTP request counters, duration histograms, and in-flight gauges
- OpenTelemetry tracing on Gin requests
- GORM tracing plugin
- Jaeger OTLP HTTP export
- Loki for centralized local logs
- Promtail for Docker log shipping
- Grafana datasources for Prometheus, Loki, and Jaeger

Current local flow:

- API writes structured JSON logs
- Docker captures container logs
- Promtail reads Docker logs
- Promtail pushes logs to Loki
- Prometheus scrapes API metrics
- API exports traces to Jaeger
- Grafana reads all three backends

## Next Metrics

- add counters per business action:
  - signup
  - login
  - create post
  - create comment
  - send friend request
  - send chat message
- add error counters per endpoint group
- add websocket connection gauges
- add websocket delivery success/failure counters
- add object storage upload/delete counters

## Next Tracing

- add explicit spans for:
  - signup with avatar upload
  - create feed post with image upload
  - send chat message
  - notification creation
- add trace attributes for:
  - `user_id`
  - `conversation_id`
  - `post_id`
  - `storage_bucket`
- improve trace correlation between HTTP flow and websocket delivery attempts

## Next Logging

- add websocket lifecycle logs:
  - connect
  - disconnect
  - failed write
  - presence change
- add consistent request/trace correlation fields
- keep auth tokens and sensitive payloads redacted
- avoid body logging for noisy endpoints like `/metrics`

## Dashboards

- HTTP request rate, latency, error rate
- chat send volume and unread-count latency
- active websocket connections
- object storage upload volume
- slow database query visibility
- notification creation volume

## Alerts

- elevated HTTP 5xx rate
- elevated chat delivery failure rate
- unusual websocket disconnect spike
- sustained high request latency
- repeated storage upload failure spike

## Future Scale

- outbox publish lag metrics
- RabbitMQ consumer lag and retry metrics
- cross-instance websocket fanout visibility
- MinIO/S3 storage latency histograms
