-- +goose Up
ALTER TABLE users ADD COLUMN username TEXT;

WITH normalized AS (
    SELECT
        id,
        COALESCE(
            NULLIF(
                lower(regexp_replace(split_part(email, '@', 1), '[^a-z0-9_]+', '_', 'g')),
                ''
            ),
            'player'
        ) AS base_username
    FROM users
    WHERE username IS NULL OR username = ''
),
ranked AS (
    SELECT
        id,
        base_username,
        row_number() OVER (
            PARTITION BY base_username
            ORDER BY id
        ) AS duplicate_rank
    FROM normalized
)
UPDATE users
SET username = CASE
    WHEN ranked.duplicate_rank = 1
        THEN ranked.base_username || '_' || substr(users.id, 1, 6)
    ELSE ranked.base_username || '_' || ranked.duplicate_rank || '_' || substr(users.id, 1, 6)
END
FROM ranked
WHERE users.id = ranked.id;

ALTER TABLE users
    ALTER COLUMN username SET NOT NULL;

ALTER TABLE users
    ADD CONSTRAINT users_username_unique UNIQUE (username);

CREATE INDEX idx_users_username ON users (username);

-- +goose Down
DROP INDEX IF EXISTS idx_users_username;
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_username_unique;
ALTER TABLE users DROP COLUMN IF EXISTS username;
