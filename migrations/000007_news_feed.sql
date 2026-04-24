-- +goose Up
CREATE TABLE IF NOT EXISTS feed_posts (
    id TEXT PRIMARY KEY,
    author_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    post_type TEXT NOT NULL,
    caption TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE IF NOT EXISTS feed_media (
    id TEXT PRIMARY KEY,
    feed_post_id TEXT NOT NULL REFERENCES feed_posts(id) ON DELETE CASCADE,
    media_type TEXT NOT NULL,
    media_url TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_feed_posts_created_at ON feed_posts (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_feed_media_feed_post_id ON feed_media (feed_post_id);

-- +goose Down
DROP TABLE IF EXISTS feed_media;
DROP TABLE IF EXISTS feed_posts;
