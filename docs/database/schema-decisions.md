# Schema Decisions

## Primary database
Postgres is the long-term source of truth.

## Current implementation note
The first runnable code path uses in-memory repositories for local development speed, but the schema has already been shaped through SQL migration files.

## Design choices
- user identity and profile are separated
- sports are modeled as catalog/reference data with stable IDs in `sports`
- user sport selection is modeled as a join to the sports catalog through `user_sports`
- auth accounts and auth sessions are separated to support local and future social login
- chat separates conversations, participants, messages, and read tracking
- ranking is modeled per user, sport, and geography scope
- outbox events are first-class schema entities for future reliable event publishing
