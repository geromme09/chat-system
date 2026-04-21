-- +goose Up
ALTER TABLE friendships
    ADD COLUMN seen_at TIMESTAMPTZ,
    ADD COLUMN updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

CREATE INDEX idx_friendships_addressee_status ON friendships (addressee_user_id, status, created_at DESC);

-- +goose Down
DROP INDEX IF EXISTS idx_friendships_addressee_status;
ALTER TABLE friendships
    DROP COLUMN IF EXISTS updated_at,
    DROP COLUMN IF EXISTS seen_at;
