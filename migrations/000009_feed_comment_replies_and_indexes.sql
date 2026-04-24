-- +goose Up
ALTER TABLE feed_comments
    ADD COLUMN IF NOT EXISTS parent_comment_id TEXT REFERENCES feed_comments(id) ON DELETE CASCADE;

DROP INDEX IF EXISTS idx_feed_posts_created_at;
CREATE INDEX IF NOT EXISTS idx_feed_posts_created_at_id
    ON feed_posts (created_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_feed_comments_post_parent_created_at
    ON feed_comments (feed_post_id, parent_comment_id, created_at ASC, id ASC);

CREATE INDEX IF NOT EXISTS idx_feed_comments_parent_comment_id
    ON feed_comments (parent_comment_id);

-- +goose Down
DROP INDEX IF EXISTS idx_feed_comments_parent_comment_id;
DROP INDEX IF EXISTS idx_feed_comments_post_parent_created_at;
DROP INDEX IF EXISTS idx_feed_posts_created_at_id;
CREATE INDEX IF NOT EXISTS idx_feed_posts_created_at
    ON feed_posts (created_at DESC);

ALTER TABLE feed_comments
    DROP COLUMN IF EXISTS parent_comment_id;
