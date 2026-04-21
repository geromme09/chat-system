# Database Table Summary

This summary gives a fast view of what currently exists in the schema and what each table is for.

## Catalog
| Table | Purpose |
|---|---|
| `sports` | Canonical supported sports list with stable IDs, slugs, icon keys, and display order |

## User And Identity
| Table | Purpose |
|---|---|
| `users` | Core account identity and status |
| `user_profiles` | Public-facing profile details |
| `user_sports` | User-to-sport join table referencing `sports.id` |
| `auth_accounts` | Future auth provider bindings |
| `auth_sessions` | Session persistence |
| `location_scopes` | Geography and optional coordinates |
| `discovery_preferences` | Radius and visibility settings |

## Friendship And Social Graph
| Table | Purpose |
|---|---|
| `friendships` | Friend request and connection lifecycle |
| `friend_qr_tokens` | QR friend-add tokens |

## Chat
| Table | Purpose |
|---|---|
| `conversations` | Chat thread parent record |
| `conversation_participants` | Conversation membership |
| `messages` | Message records |
| `message_reads` | Per-user read tracking |

## Discovery
| Table | Purpose |
|---|---|
| `swipe_actions` | Like/pass decisions |
| `matches` | Mutual swipe outcomes |

## Challenge
| Table | Purpose |
|---|---|
| `challenges` | Sport challenge lifecycle |
| `challenge_results` | Winner/result record |

## Feed
| Table | Purpose |
|---|---|
| `feed_posts` | Feed post parent record |
| `feed_media` | Feed media items |

## Ranking
| Table | Purpose |
|---|---|
| `rank_entries` | Points and leaderboard rows |

## Infrastructure
| Table | Purpose |
|---|---|
| `outbox_events` | Reliable event publishing buffer |
| `schema_migrations` | Migration file tracking table created by the migrator |
