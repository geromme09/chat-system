# ADR 0002: Postgres As Source Of Truth

## Decision
Postgres will be the primary persistent data store.

## Why
- relational consistency fits users, profiles, friendships, notifications, and chat
- query flexibility is valuable for inbox views, social graph lookups, and conversation data
