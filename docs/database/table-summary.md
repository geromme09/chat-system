# Database Table Summary

This summary reflects the **FaceOff Social** schema after the social-only cleanup.

## User And Identity
| Table | Purpose |
|---|---|
| `users` | Core account identity, auth status, and `profile_complete` state |
| `user_profiles` | Social profile fields such as display name, bio, location, gender, hobbies, and visibility |
| `auth_accounts` | Future auth provider bindings if social login is added |
| `auth_sessions` | Future server-managed session persistence if needed |

## Friendship And Notifications
| Table | Purpose |
|---|---|
| `friendships` | Friend request lifecycle and accepted friend graph |
| `notifications` | In-app notification records and read state |

## Chat
| Table | Purpose |
|---|---|
| `conversations` | Chat thread parent record |
| `conversation_participants` | Conversation membership |
| `messages` | Chat message records |
| `message_reads` | Per-user read tracking |

## Infrastructure
| Table | Purpose |
|---|---|
| `outbox_events` | Reliable event publishing buffer for future async delivery |
| `schema_migrations` | Migration tracking table created by the migrator |
