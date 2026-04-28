-- +goose Up
CREATE INDEX IF NOT EXISTS idx_feed_comments_post_created_at_id
    ON feed_comments (feed_post_id, created_at ASC, id ASC);

-- +goose Down
DROP INDEX IF EXISTS idx_feed_comments_post_created_at_id;
