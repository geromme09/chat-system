-- +goose Up
CREATE TABLE IF NOT EXISTS feed_hidden_posts (
    feed_post_id TEXT NOT NULL REFERENCES feed_posts(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (feed_post_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_feed_hidden_posts_user_created_at
    ON feed_hidden_posts (user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS feed_post_reports (
    id TEXT PRIMARY KEY,
    feed_post_id TEXT NOT NULL REFERENCES feed_posts(id) ON DELETE CASCADE,
    reporter_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reason TEXT NOT NULL DEFAULT 'unspecified',
    status TEXT NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL,
    UNIQUE (feed_post_id, reporter_user_id)
);

CREATE INDEX IF NOT EXISTS idx_feed_post_reports_status_created_at
    ON feed_post_reports (status, created_at DESC);

-- +goose Down
DROP TABLE IF EXISTS feed_post_reports;
DROP TABLE IF EXISTS feed_hidden_posts;
