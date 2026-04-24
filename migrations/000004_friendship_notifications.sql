-- +goose Up
ALTER TABLE friendships
    ADD COLUMN IF NOT EXISTS seen_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_friendships_addressee_status ON friendships (addressee_user_id, status, created_at DESC);

-- +goose Down
DROP INDEX IF EXISTS idx_friendships_addressee_status;
ALTER TABLE friendships
    DROP COLUMN IF EXISTS updated_at,
    DROP COLUMN IF EXISTS seen_at;
