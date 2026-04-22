-- +goose Up
CREATE TABLE notifications (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type TEXT NOT NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL DEFAULT '',
    data JSONB NOT NULL DEFAULT '{}'::jsonb,
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notifications_user_created_at
    ON notifications (user_id, created_at DESC);

CREATE INDEX idx_notifications_user_read_at
    ON notifications (user_id, read_at);

-- +goose Down
DROP INDEX IF EXISTS idx_notifications_user_read_at;
DROP INDEX IF EXISTS idx_notifications_user_created_at;
DROP TABLE IF EXISTS notifications;
