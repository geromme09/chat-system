# Schema Decisions

## Primary database
Postgres is the source of truth for FaceOff Social.

## Current modeling choices
- account identity lives in `users`
- public social profile data lives in `user_profiles`
- `users.profile_complete` is the gate for onboarding completion
- optional social metadata such as `gender` and `hobbies_text` stays in `user_profiles`
- friendships are modeled separately from notifications so request state and inbox state can evolve independently
- chat separates conversations, participants, messages, and read tracking
- outbox events remain first-class infrastructure data for future reliable event publishing

## Explicit non-goals for this schema
The social database does not own:
- sports catalogs
- discovery swipes
- match records
- challenge records
- rankings
- fighter creation data

Those concerns either belong to the removed pre-pivot scope or to the future game domain.
