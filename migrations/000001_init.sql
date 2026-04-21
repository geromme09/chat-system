CREATE TABLE users (
    id TEXT PRIMARY KEY,
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    account_status TEXT NOT NULL,
    auth_provider TEXT NOT NULL,
    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    profile_complete BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE user_profiles (
    user_id TEXT PRIMARY KEY REFERENCES users(id),
    display_name TEXT NOT NULL,
    bio TEXT NOT NULL DEFAULT '',
    avatar_url TEXT NOT NULL DEFAULT '',
    city TEXT NOT NULL DEFAULT '',
    country TEXT NOT NULL DEFAULT '',
    skill_level TEXT NOT NULL DEFAULT '',
    visible BOOLEAN NOT NULL DEFAULT TRUE,
    last_modified TIMESTAMPTZ NOT NULL
);

CREATE TABLE user_sports (
    user_id TEXT NOT NULL REFERENCES users(id),
    sport_name TEXT NOT NULL,
    PRIMARY KEY (user_id, sport_name)
);

CREATE TABLE auth_accounts (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id),
    provider TEXT NOT NULL,
    provider_subject TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE auth_sessions (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id),
    token_hash TEXT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE friendships (
    id TEXT PRIMARY KEY,
    requester_user_id TEXT NOT NULL REFERENCES users(id),
    addressee_user_id TEXT NOT NULL REFERENCES users(id),
    status TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE friend_qr_tokens (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id),
    token TEXT NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE conversations (
    id TEXT PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE conversation_participants (
    conversation_id TEXT NOT NULL REFERENCES conversations(id),
    user_id TEXT NOT NULL REFERENCES users(id),
    PRIMARY KEY (conversation_id, user_id)
);

CREATE TABLE messages (
    id TEXT PRIMARY KEY,
    conversation_id TEXT NOT NULL REFERENCES conversations(id),
    sender_user_id TEXT NOT NULL REFERENCES users(id),
    body TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE message_reads (
    message_id TEXT NOT NULL REFERENCES messages(id),
    user_id TEXT NOT NULL REFERENCES users(id),
    read_at TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (message_id, user_id)
);

CREATE TABLE discovery_preferences (
    user_id TEXT PRIMARY KEY REFERENCES users(id),
    radius_km INT NOT NULL DEFAULT 10,
    is_visible BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE swipe_actions (
    id TEXT PRIMARY KEY,
    actor_user_id TEXT NOT NULL REFERENCES users(id),
    target_user_id TEXT NOT NULL REFERENCES users(id),
    sport_name TEXT NOT NULL,
    decision TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE matches (
    id TEXT PRIMARY KEY,
    user_a_id TEXT NOT NULL REFERENCES users(id),
    user_b_id TEXT NOT NULL REFERENCES users(id),
    sport_name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE challenges (
    id TEXT PRIMARY KEY,
    sport_name TEXT NOT NULL,
    challenger_user_id TEXT NOT NULL REFERENCES users(id),
    challenged_user_id TEXT NOT NULL REFERENCES users(id),
    area_label TEXT NOT NULL,
    scheduled_for TIMESTAMPTZ,
    status TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE challenge_results (
    challenge_id TEXT PRIMARY KEY REFERENCES challenges(id),
    winner_user_id TEXT REFERENCES users(id),
    submitted_by_user_id TEXT NOT NULL REFERENCES users(id),
    confirmed BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE feed_posts (
    id TEXT PRIMARY KEY,
    author_user_id TEXT NOT NULL REFERENCES users(id),
    challenge_id TEXT REFERENCES challenges(id),
    post_type TEXT NOT NULL,
    caption TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE feed_media (
    id TEXT PRIMARY KEY,
    feed_post_id TEXT NOT NULL REFERENCES feed_posts(id),
    media_type TEXT NOT NULL,
    media_url TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE rank_entries (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id),
    sport_name TEXT NOT NULL,
    geography_scope TEXT NOT NULL,
    geography_value TEXT NOT NULL,
    points INT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE location_scopes (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id),
    barangay TEXT NOT NULL DEFAULT '',
    city TEXT NOT NULL DEFAULT '',
    country TEXT NOT NULL DEFAULT '',
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    updated_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE outbox_events (
    id TEXT PRIMARY KEY,
    event_name TEXT NOT NULL,
    event_version INT NOT NULL,
    aggregate_type TEXT NOT NULL,
    aggregate_id TEXT NOT NULL,
    payload JSONB NOT NULL,
    published_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX idx_messages_conversation_id_created_at ON messages (conversation_id, created_at);
CREATE INDEX idx_friendships_requester_user_id ON friendships (requester_user_id);
CREATE INDEX idx_friendships_addressee_user_id ON friendships (addressee_user_id);
CREATE INDEX idx_matches_sport_name_created_at ON matches (sport_name, created_at);
CREATE INDEX idx_rank_entries_lookup ON rank_entries (sport_name, geography_scope, geography_value, points DESC);
