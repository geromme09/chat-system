-- +goose Up
ALTER TABLE user_profiles
    ADD COLUMN IF NOT EXISTS gender TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS hobbies_text TEXT NOT NULL DEFAULT '';

ALTER TABLE user_profiles
    DROP COLUMN IF EXISTS skill_level;

-- +goose Down
ALTER TABLE user_profiles
    ADD COLUMN IF NOT EXISTS skill_level TEXT NOT NULL DEFAULT '';

ALTER TABLE user_profiles
    DROP COLUMN IF EXISTS hobbies_text,
    DROP COLUMN IF EXISTS gender;
