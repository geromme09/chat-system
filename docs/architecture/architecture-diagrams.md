# Architecture Diagrams

This document follows a practical industry-standard split:

- `System Context`
  Shows the system and the external actors around it
- `Container View`
  Shows the main deployable/runtime pieces
- `Sequence Diagrams`
  Show important request and event flows per functionality

This is intentionally better than one giant diagram. Large mixed diagrams become hard to read, hard to update, and low-signal during onboarding.

## 1. System Context

```mermaid
flowchart LR
    User["User"]
    Mobile["Flutter Mobile App"]
    Social["FaceOff Social"]
    Game["Future FaceOff Game Client / Services"]
    PG["PostgreSQL"]
    MQ["RabbitMQ"]
    Redis["Redis"]
    MinIO["MinIO / S3-Compatible Object Storage"]

    User --> Mobile
    Mobile --> Social
    Social --> PG
    Social --> MQ
    Social --> Redis
    Social --> MinIO
    Game --> Social
```

Use this when explaining:

- what FaceOff Social is
- what is inside the repo
- what is outside the repo
- where game integration will sit later

## 2. Container View

```mermaid
flowchart TB
    subgraph Client["Client Layer"]
        Mobile["Flutter Mobile App"]
    end

    subgraph App["FaceOff Social Runtime"]
        API["Go API (`cmd/api`)"]
        Consumer["Go Consumer (`cmd/consumer`)"]
    end

    subgraph Data["Data / Infra"]
        PG["PostgreSQL"]
        Redis["Redis"]
        MQ["RabbitMQ"]
        MinIO["MinIO / S3-Compatible Storage"]
    end

    Mobile --> API
    API --> PG
    API --> Redis
    API --> MQ
    API --> MinIO
    Consumer --> MQ
    Consumer --> PG
    Consumer --> Redis
```

Notes:

- `API` owns synchronous mobile-facing flows
- `Consumer` is for asynchronous work and notification/event handling
- `MinIO` is used locally, but the storage adapter is S3-compatible

## 3. Domain View

```mermaid
flowchart LR
    User["User Domain"]
    Friendship["Friendship Domain"]
    Feed["Feed Domain"]
    Chat["Chat Domain"]
    Notification["Notification Domain"]
    Storage["Object Storage Adapter"]

    User --> Storage
    Feed --> Storage
    Friendship --> Notification
    Feed --> Notification
    Chat --> Notification
```

Use this to explain ownership:

- `user`
  signup, login, profile, avatar metadata
- `friendship`
  friend requests and accepted relationships
- `feed`
  posts, reactions, comments, replies, post media metadata
- `chat`
  conversations, messages, unread state
- `notification`
  in-app notification fanout and read state

## 4. Sequence: Sign Up With Avatar Upload

```mermaid
sequenceDiagram
    actor User
    participant App as Flutter App
    participant API as Go API
    participant UserSvc as User Service
    participant Storage as S3-Compatible Storage Adapter
    participant MinIO as MinIO
    participant DB as PostgreSQL

    User->>App: Fill sign up form + select avatar
    App->>API: POST /api/v1/auth/signup (multipart/form-data)
    API->>UserSvc: SignUp(input)
    UserSvc->>Storage: SaveAvatarDataURL(...)
    Storage->>MinIO: PutObject(profile-media, profiles/{userID}/avatar/{uuid}.jpg)
    MinIO-->>Storage: Object stored
    Storage-->>UserSvc: {bucket, object_key, content_type}
    UserSvc->>DB: Insert user
    UserSvc->>DB: Upsert profile with avatar metadata
    UserSvc-->>API: AuthResult
    API-->>App: token + profile
```

Key point:

- image bytes go to object storage
- metadata goes to PostgreSQL

## 5. Sequence: Create Feed Post With Image

```mermaid
sequenceDiagram
    actor User
    participant App as Flutter App
    participant API as Go API
    participant FeedSvc as Feed Service
    participant Storage as S3-Compatible Storage Adapter
    participant MinIO as MinIO
    participant DB as PostgreSQL

    User->>App: Write caption + select image
    App->>API: POST /api/v1/feed (multipart/form-data)
    API->>FeedSvc: CreatePost(input)
    FeedSvc->>Storage: SaveFeedImageDataURL(...)
    Storage->>MinIO: PutObject(post-media, posts/{uuid}.png)
    MinIO-->>Storage: Object stored
    Storage-->>FeedSvc: {bucket, object_key, content_type}
    FeedSvc->>DB: Insert feed_posts row
    FeedSvc->>DB: Insert feed_media metadata row
    FeedSvc-->>API: Post
    API-->>App: Post JSON with rebuilt image_url
```

## 6. Sequence: Read Feed Post Image

```mermaid
sequenceDiagram
    actor User
    participant App as Flutter App
    participant API as Go API
    participant FeedRepo as Feed Repository
    participant DB as PostgreSQL
    participant MinIO as MinIO

    User->>App: Open feed
    App->>API: GET /api/v1/feed
    API->>FeedRepo: ListPosts(...)
    FeedRepo->>DB: Read feed_posts + feed_media metadata
    DB-->>FeedRepo: bucket + object_key + content_type
    FeedRepo-->>API: Post DTO with rebuilt image_url
    API-->>App: Feed page JSON
    App->>MinIO: GET /post-media/posts/{uuid}.png
    MinIO-->>App: Image bytes
```

## 7. Sequence: Replace Avatar

```mermaid
sequenceDiagram
    actor User
    participant App as Flutter App
    participant API as Go API
    participant UserSvc as User Service
    participant Storage as S3-Compatible Storage Adapter
    participant MinIO as MinIO
    participant DB as PostgreSQL

    User->>App: Update profile + choose new avatar
    App->>API: PUT /api/v1/profile/me (multipart/form-data)
    API->>UserSvc: UpdateProfile(input)
    UserSvc->>DB: Read current profile
    UserSvc->>Storage: Save new avatar
    Storage->>MinIO: PutObject(new avatar)
    Storage-->>UserSvc: new metadata
    UserSvc->>DB: Update profile metadata
    UserSvc->>Storage: Delete old avatar object (best-effort)
    Storage->>MinIO: RemoveObject(old avatar)
    UserSvc-->>API: Updated profile
    API-->>App: Updated profile JSON
```

## 8. Sequence: Delete Post With Cleanup

```mermaid
sequenceDiagram
    actor User
    participant App as Flutter App
    participant API as Go API
    participant FeedSvc as Feed Service
    participant DB as PostgreSQL
    participant Storage as S3-Compatible Storage Adapter
    participant MinIO as MinIO

    User->>App: Delete post
    App->>API: DELETE /api/v1/feed/{postID}
    API->>FeedSvc: DeletePost(postID)
    FeedSvc->>DB: Read post metadata
    FeedSvc->>DB: Delete post rows
    FeedSvc->>Storage: Delete image object (best-effort)
    Storage->>MinIO: RemoveObject(post-media, posts/{uuid}.png)
    API-->>App: deleted=true
```

## 9. Sequence: Send Chat Message

```mermaid
sequenceDiagram
    actor User
    participant App as Flutter App
    participant API as Go API
    participant ChatSvc as Chat Service
    participant DB as PostgreSQL
    participant WS as Realtime Hub

    User->>App: Send message
    App->>API: POST /api/v1/chat/conversations/{id}/messages
    API->>ChatSvc: SendMessage(input)
    ChatSvc->>DB: Insert messages row
    ChatSvc->>WS: Broadcast message event
    ChatSvc-->>API: Message
    API-->>App: Message JSON
    WS-->>App: Realtime message update
```

## 10. Sequence: Notification Fanout

```mermaid
sequenceDiagram
    actor User
    participant App as Flutter App
    participant API as Go API
    participant Domain as Feed / Friendship / Chat Service
    participant Notif as Notification Service
    participant DB as PostgreSQL
    participant WS as Realtime Hub

    User->>App: Trigger domain action
    App->>API: Request
    API->>Domain: Execute use case
    Domain->>DB: Persist domain state
    Domain->>Notif: Notify(...)
    Notif->>DB: Insert notification row
    Notif->>WS: Push realtime notification event
    API-->>App: Success response
    WS-->>App: Realtime notification update
```

## 11. Sequence: Domain Event Flow

```mermaid
sequenceDiagram
    actor User
    participant App as Flutter App
    participant API as Go API
    participant Domain as App Service
    participant DB as PostgreSQL
    participant Publisher as messaging.Publisher
    participant Consumer as Future Consumer / Broker Worker

    User->>App: Trigger domain action
    App->>API: Request
    API->>Domain: Execute use case
    Domain->>DB: Persist domain state
    Domain->>Publisher: Publish(domain event)
    Publisher-->>Domain: ack
    Domain-->>API: Success result
    API-->>App: Response
    Note over Publisher,Consumer: Today the publisher is NoopPublisher
    Note over Publisher,Consumer: Target design is outbox + RabbitMQ consumer flow
```

## Why This Split Is Better

- `Context diagram`
  Best for orientation
- `Container diagram`
  Best for runtime/deployment understanding
- `Sequence diagrams`
  Best for implementation and debugging

This is the pattern to keep using as features grow:

1. add one stable high-level view
2. add one sequence diagram per important use case
3. avoid mixing structure and behavior in one diagram
