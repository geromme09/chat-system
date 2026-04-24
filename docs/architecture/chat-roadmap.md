# Chat Roadmap

This roadmap turns the current chat implementation into a clear sequence of product and engineering work.

It is written for the current state of FaceOff Social:

- 1:1 conversations exist
- message send and history exist
- unread counts exist
- realtime socket delivery exists
- typing and presence events already exist in the transport layer

The goal now is not to rebuild chat. The goal is to make chat feel dependable, complete, and safe enough for daily use.

## Current Baseline

Already present in the codebase:

- direct conversation creation
- message list and send APIs
- unread count support
- conversation read marking
- realtime WebSocket connection with reconnect behavior
- typing started and typing stopped events
- presence update events
- in-app notification surfaces

Important implication:

- the next chat phase should prioritize product completeness and reliability
- typing indicators are partially implemented already, so they are not a greenfield feature

## Must-Have Now

These are the next features that most improve the real user experience of chat.

### 1. Message Send State And Retry

Why this matters:

- mobile networks are unreliable
- users need to know whether a message is sending, failed, or delivered
- silent failures make chat feel broken even when the backend is fine

Needed behavior:

- optimistic message rendering
- local `sending` state
- visible `failed` state
- tap to retry for failed messages
- duplicate prevention when retries happen

Suggested implementation:

- add a client-side temporary message ID
- keep a local pending message model in the conversation screen or chat data layer
- reconcile pending messages with server-confirmed messages
- make send operations idempotent on the backend if possible

### 2. Read Receipts

Why this matters:

- you already mark conversations as read
- the data model already includes `read_at`
- exposing this clearly gives immediate value to users

Needed behavior:

- mark individual messages or the latest seen message as read
- show `Seen` for the latest outgoing message that the other user has opened
- keep the UI lightweight for 1:1 chat

Suggested implementation:

- start with a conversation-level last-read marker instead of per-message receipt fanout
- derive `Seen` from the other participant's latest read message or read timestamp

### 3. Push Notifications

Why this matters:

- in-app unread counts only help while the app is open
- closed-app message awareness is a baseline expectation for chat

Needed behavior:

- notify for new incoming messages when the user is offline or backgrounded
- deep link into the correct conversation
- avoid duplicate notification noise when the conversation is already open

Suggested implementation:

- use FCM and APNs through Flutter push support
- trigger push fanout from message-created events
- add suppression rules when the user is active in the same conversation

### 4. Finish Typing Indicator UX

Why this matters:

- the event plumbing already exists
- the remaining work is product polish and edge-case cleanup

Needed behavior:

- send typing signals only while actively editing
- stop signals on send, blur, navigation away, and app background
- show a stable `typing...` indicator without flicker

Suggested implementation:

- keep the current debounce approach
- add lifecycle cleanup and stale-indicator timeout protection
- verify the chat list and conversation screen react consistently

### 5. Block, Mute, And Report Safety Controls

Why this matters:

- social chat without safety controls becomes risky quickly
- this is one of the highest-value non-UI features for long-term health

Needed behavior:

- block a user from messaging
- mute notifications for a conversation
- report abusive content or behavior

Suggested implementation:

- begin with `block user`
- enforce the block in conversation creation, send message, and realtime delivery
- add report records and admin-review hooks later

## Nice Soon

These features are not as urgent as the set above, but they add a lot of product quality once the basics are dependable.

### 1. Conversation Management

- pin chats
- archive chats
- search conversations by username or display name
- mark conversation as unread

### 2. Message Actions

- copy message
- delete own message
- edit own recent message
- emoji reactions

### 3. Better History Loading

- paginate older messages
- preserve scroll position when older history loads
- restore scroll state when returning to a conversation

### 4. Presence Refinement

- last seen
- clearer online/offline freshness rules
- avoid showing stale online states after disconnects

### 5. Link And Rich Content Previews

- detect URLs
- render safe previews
- handle preview loading gracefully

## Later

These are good future features, but they should follow after core 1:1 chat feels strong.

### 1. Media Messages

- image attachments
- camera/gallery sharing in chat
- upload progress
- media moderation and storage rules

### 2. Group Chat

- group creation
- membership management
- read state complexity
- group notification rules

### 3. Voice Notes Or Advanced Attachments

- audio clips
- file sharing
- richer composer tools

### 4. Full Chat Search

- search across conversation history
- filter by media, links, or participant

## Recommended Delivery Order

The most practical order for this repo is:

1. message send state and retry
2. read receipts
3. push notifications
4. finish typing indicator UX
5. block, mute, and report
6. pagination and scroll restoration improvements
7. message actions
8. media messages
9. group chat

## Technical Notes By Layer

### Mobile

- add a local pending message model
- separate transport-confirmed messages from optimistic messages
- improve error and retry affordances in the conversation UI
- support deep links from push notifications into a conversation

### Backend

- add stable identifiers or idempotency support for message retries
- expose receipt-friendly read metadata
- add safety enforcement for block rules
- add notification fanout for push delivery

### Realtime

- keep WebSocket as the low-latency path
- preserve reconnect behavior
- ensure duplicate message handling is safe after reconnects
- keep typing and presence ephemeral rather than storing them permanently

## MVP Completion Signal

Chat should be considered product-ready for the current phase when:

- messages can fail gracefully and retry cleanly
- users can tell when their latest message has been seen
- new messages reach users outside the app through push
- typing indicators feel polished
- users can block abusive contacts

At that point, the chat system moves from "working feature" to "credible social product."
