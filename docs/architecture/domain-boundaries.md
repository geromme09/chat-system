# Domain Boundaries

## User
Owns account registration, login, session issuance, profile data, avatar metadata, and sport preferences.

## Friendship
Owns QR friend connections, requests, accepted friendships, and block rules.

## Chat
Owns conversations, participants, messages, message reads, and realtime delivery contracts.

## Discovery
Owns visibility rules, location-aware filtering, swipe decisions, and mutual matches.

## Challenge
Owns challenge lifecycle, scheduling metadata, and result capture.

## Feed
Owns feed posts, media references, and challenge recap content.

## Ranking
Owns sport ranking points and geographic leaderboard queries.

## Notification
Owns push and in-app notification fanout.

## Extraction reminder
These boundaries are defined so they can later become service boundaries if needed.

Likely future service candidates:
- `chat-api`
- `challenge-api`
- `discovery-api`
- `feed-api`
- `user-api` only when identity and trust flows become operationally complex
