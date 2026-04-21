# API Overview

## Versioning
All public APIs are versioned under `/api/v1`.

## Current response envelope
```json
{
  "data": {},
  "error": null
}
```

Error responses use:
```json
{
  "error": {
    "message": "..."
  }
}
```

## Implemented groups
- auth
- profile
- chat

## Reserved groups
- sports
- friends
- discovery
- challenges
- feed
- rankings

## Planned catalog endpoint
The app should expose a sports catalog endpoint for filters and selectors:

- `GET /api/v1/sports`

Expected uses:
- signup and profile sport selection
- discovery filter selection
- challenge creation sport picker
- ranking screen sport filter
