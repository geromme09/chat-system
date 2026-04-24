# FaceOff Social Transition Plan

## Summary

This document replaces the old sports-social MVP direction with the current product transition:

- this repo becomes **FaceOff Social**
- FaceOff Social is the social and identity layer
- a future fighting game will become a separate game product that integrates with it

The planning goal is no longer “build a sports social app.”

The planning goal is now:

1. finish FaceOff Social as a stable social platform
2. define the boundary between Social and the future game
3. prepare the data and UX surfaces that the game will need later

## Product Direction

FaceOff Social is a player identity and social platform where users can:

- register and log in
- maintain a player profile
- add friends
- chat one-to-one
- receive notifications
- later display their selected fighter identity and game progress

The fighting game is a separate future product where users will:

- authenticate using FaceOff Social identity
- create their fighter
- play matches
- earn rank
- sync selected character and progression summaries back into Social

## Current Progress

Implemented now:

- auth
- sessions
- profile read/update
- profile completion flow with social-only fields
- friend requests and accepted friendships
- notifications
- direct chat
- realtime chat socket updates
- mobile social UI
- paginated friends and notifications

Stable enough to stop major UI churn for now:

- chat list visual treatment
- notification behavior
- bottom navigation structure
- route transitions for pushed screens

## New MVP For FaceOff Social

The new MVP for this repo is:

- player can create an account
- player can maintain a social profile
- player can add friends
- player can chat with friends
- player can receive basic social notifications
- player profile is ready to later display game-owned fighter summary

This repo does **not** need to implement the game itself to complete its own MVP.

## Social Scope We Still Need

These are the main product gaps still worth implementing in FaceOff Social:

### 1. Player Identity Cleanup

We need to decide which fields belong to the social profile and which belong to the future game character.

Likely social-owned:

- display name
- username
- basic avatar or profile picture
- country / region
- optional public-facing identity metadata

Likely game-owned:

- fighter body settings
- skin tone for fighter rendering
- selected portrait or generated face asset
- outfit selection
- rank and match stats

### 2. Player Card / Profile Surface

We need a cleaner profile card that can later display:

- selected fighter portrait
- fighter or player title
- current rank
- wins/losses summary
- challenge/fight CTA later if needed

### 3. Integration Contract With The Game

We need to define the minimum future contract for:

- trusted authentication from game client to Social APIs
- reading friend graph from Social
- optionally sending back fighter summary metadata to Social
- optionally sending back progression summaries for display

### 4. Social Features Needed For Game Readiness

Likely next useful features:

- friend invite or match invite concept
- richer notification types
- player presence or online state refinement
- conversation shortcuts from player cards

## Things We Should Not Build Here

These belong to the future game stack and should not be forced into FaceOff Social:

- 2D fighting gameplay
- combo system
- voice input combat mechanics
- controller combat mechanics
- fighter animation graph
- hitboxes and move timing
- matchmaking for live fights
- rank calculation as the source of truth
- full character generation pipeline

FaceOff Social may consume summaries from those systems, but should not own them.

## Recommended System Split

### FaceOff Social

Owns:

- auth
- profile
- friends
- chat
- notifications
- social mobile UX

### Future Game Layer

Owns:

- fighter creation
- portrait or avatar generation pipeline
- body and outfit configuration
- fights
- matchmaking
- rank
- match history

### Shared Integration Direction

- Social remains source of truth for player identity and social graph
- Game remains source of truth for fighter and progression
- Social displays game-owned summaries through explicit APIs or sync events

## Technical Tasks Needed Next

### Near-term Social tasks

- define `player profile` vs `fighter profile`
- prepare profile UI for future fighter summary slot
- document integration contract between Social and game
- tighten notification taxonomy around future game events

### Backend tasks

- create a stable player summary response contract
- decide whether game-facing auth uses shared JWT or a token exchange flow
- add game-ready player lookup endpoints if needed
- document future event contracts for game-to-social summary sync

### Mobile tasks

- keep current polish stable
- avoid more large UI redesign work unless it supports the new direction
- prepare profile screen to later display fighter summary cleanly

## Success Criteria For This Repo

FaceOff Social is successful when:

- a player can sign up and log in reliably
- a player can add friends and chat
- the profile can act as a stable player identity surface
- the future game can reuse the same account system
- the social app can later display selected fighter data without a major rewrite
