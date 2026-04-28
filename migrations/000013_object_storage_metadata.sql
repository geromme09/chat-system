-- +goose Up
ALTER TABLE user_profiles
    ADD COLUMN IF NOT EXISTS avatar_bucket TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS avatar_key TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS avatar_type TEXT NOT NULL DEFAULT '';

ALTER TABLE feed_media
    ADD COLUMN IF NOT EXISTS bucket TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS object_key TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS content_type TEXT NOT NULL DEFAULT '';

CREATE INDEX IF NOT EXISTS idx_user_profiles_avatar_object ON user_profiles (avatar_bucket, avatar_key);
CREATE INDEX IF NOT EXISTS idx_feed_media_object ON feed_media (bucket, object_key);

-- +goose Down
DROP INDEX IF EXISTS idx_feed_media_object;
DROP INDEX IF EXISTS idx_user_profiles_avatar_object;

ALTER TABLE feed_media
    DROP COLUMN IF EXISTS content_type,
    DROP COLUMN IF EXISTS object_key,
    DROP COLUMN IF EXISTS bucket;

ALTER TABLE user_profiles
    DROP COLUMN IF EXISTS avatar_type,
    DROP COLUMN IF EXISTS avatar_key,
    DROP COLUMN IF EXISTS avatar_bucket;
