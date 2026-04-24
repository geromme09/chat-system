-- +goose Up
CREATE INDEX IF NOT EXISTS idx_feed_posts_author_created_at_id
    ON feed_posts (author_user_id, created_at DESC, id DESC);

-- +goose Down
DROP INDEX IF EXISTS idx_feed_posts_author_created_at_id;
