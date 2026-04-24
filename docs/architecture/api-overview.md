# API Overview

## Versioning

All public APIs are versioned under `/api/v1`.

## Current Response Envelope

Success:

```json
{
  "data": {},
  "error": null
}
```

Error:

```json
{
  "error": {
    "message": "..."
  }
}
```

## Implemented Groups

- auth
- profile
- users
- friends
- notifications
- chat

## Implemented Endpoints

- `POST /api/v1/auth/signup`
- `POST /api/v1/auth/login`
- `GET /api/v1/profile/me`
- `PUT /api/v1/profile/me`
- `GET /api/v1/users/search`
- `POST /api/v1/friends/requests`
- `GET /api/v1/friends/requests/incoming`
- `POST /api/v1/friends/requests/{id}/accept`
- `POST /api/v1/friends/requests/{id}/decline`
- `GET /api/v1/friends`
- `GET /api/v1/notifications`
- `POST /api/v1/notifications/read-all`
- `POST /api/v1/notifications/{id}/read`
- `GET /api/v1/chat/conversations`
- `POST /api/v1/chat/conversations`
- `GET /api/v1/chat/conversations/{id}/messages`
- `POST /api/v1/chat/conversations/{id}/messages`
- `POST /api/v1/chat/conversations/{id}/read`
- `GET /api/v1/chat/unread-count`

## Current Paging Contract

Friends and notifications now use paged responses:

```json
{
  "data": {
    "items": [],
    "page": 1,
    "limit": 15,
    "next_page": 2
  },
  "error": null
}
```

Supported query parameters:

- `page`
- `limit`

## Reserved Future Social Groups

Potential future FaceOff Social groups:

- player summary
- social invites
- presence
- game-linked profile summary

## Planned Game Integration Surface

The game should eventually be able to:

- authenticate using FaceOff Social identity
- read the friend graph for social match flows
- read player profile basics
- publish selected fighter summary or progression summary for display in Social

Those game-facing contracts should be added intentionally rather than mixed into existing social endpoints ad hoc.
