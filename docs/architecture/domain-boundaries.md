# Domain Boundaries

## User

Owns:

- account registration
- login
- session issuance
- base profile data
- public player identity metadata

Should remain social-platform focused and not absorb full fighter-creation state.

## Friendship

Owns:

- friend requests
- accepted friendships
- relationship rules
- future social challenge or invite entry points if needed

## Chat

Owns:

- conversations
- participants
- messages
- read state
- realtime delivery contracts

## Notification

Owns:

- in-app notification fanout
- read state
- future notification taxonomy for social and game-linked summaries

## Sport

Currently owns the legacy onboarding catalog support still present in the app.

This module is no longer the strategic center of the product and should be revisited later. It may be reduced, repurposed, or removed depending on the final character-creation flow.

## Future External Game Boundary

The following should be treated as an external future game domain, not as new modules inside FaceOff Social by default:

- fighter creation
- fighter appearance attributes
- portrait generation
- gameplay
- matchmaking
- ranking
- match history

## Extraction Reminder

These boundaries are defined so FaceOff Social can later remain focused as a social platform even after the game exists.

Likely future service candidates inside Social if extraction is needed:

- `identity-api`
- `social-api`
- `chat-api`
- `notification-worker`
