# ADR 0003: RabbitMQ For Async Workflows

## Decision
RabbitMQ is the primary async broker for background workflows and event fanout.

## Why
- keeps side effects decoupled from request latency
- supports consumer-based expansion as the app grows
