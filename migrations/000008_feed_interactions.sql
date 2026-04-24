-- +goose Up
CREATE TABLE IF NOT EXISTS feed_reactions (
    feed_post_id TEXT NOT NULL REFERENCES feed_posts(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (feed_post_id, user_id)
);

CREATE TABLE IF NOT EXISTS feed_comments (
    id TEXT PRIMARY KEY,
    feed_post_id TEXT NOT NULL REFERENCES feed_posts(id) ON DELETE CASCADE,
    author_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    body TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_feed_comments_post_created_at
    ON feed_comments (feed_post_id, created_at ASC);

-- +goose Down
DROP TABLE IF EXISTS feed_comments;
DROP TABLE IF EXISTS feed_reactions;
