# ADR 0005: REST First With Realtime Chat Path

## Decision
Use REST-first APIs and reserve realtime transport for chat delivery.

## Why
- REST keeps initial implementation simple
- chat still has a clean path to WebSocket transport later
