-- +goose Up
CREATE TABLE sports (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    slug TEXT NOT NULL UNIQUE,
    icon_url TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO sports (id, name, slug, sort_order) VALUES
    ('4d2b0b0d-a706-4de0-b2fa-2fe7c59ec6f6', 'Basketball', 'basketball', 10),
    ('2c8fba34-33ea-4ba5-bb65-8c9d1f9af877', 'Badminton', 'badminton', 20),
    ('b1c7f2aa-aef9-4dd4-b811-8a823eb2ef7e', 'Volleyball', 'volleyball', 30),
    ('94c1c028-2dde-4323-9d86-cf7091748548', 'Table Tennis', 'table-tennis', 40),
    ('d7bb8fa9-32f5-4b2c-ab20-24a5352a1798', 'Tennis', 'tennis', 50),
    ('670bde52-a83c-4ed8-839c-b080fcd69dd1', 'Futsal', 'futsal', 60),
    ('20efaa0b-bf56-4195-8f2c-f3945cf98133', 'Football', 'football', 70),
    ('cf68df2c-faa6-4e07-a8d3-fbdd3450198f', 'Boxing', 'boxing', 80),
    ('20d71d7d-38ae-4b55-8f8e-aedfb931f4dd', 'MMA', 'mma', 90),
    ('c1d5bdc8-7690-4f0e-84e8-c52505b19434', 'Billiards', 'billiards', 100),
    ('7d937470-89d9-4d16-84f5-9cd85e11d6ca', 'Bowling', 'bowling', 110),
    ('80c67aef-649f-48bd-8b54-b417b559b4e6', 'Swimming', 'swimming', 120),
    ('006457b7-b6d0-44e3-bc1c-c20da49a26f1', 'Running', 'running', 130),
    ('bf8e1e5b-d791-449f-b6c8-5127af99fd9c', 'Cycling', 'cycling', 140),
    ('30c0ef26-7e99-4eae-b7d0-0845904c4898', 'Pickleball', 'pickleball', 150),
    ('fd13e7e3-652a-44a0-b822-4f0f5cb6fb4a', 'Golf', 'golf', 160),
    ('6a31a694-113d-4ea2-87d8-2f0f8908fccd', 'Baseball', 'baseball', 170),
    ('29fa5e2b-e86e-474e-bb6f-42cc202306ea', 'Softball', 'softball', 180),
    ('3977ae58-f3e6-4149-964f-86770b65d9ec', 'Skateboarding', 'skateboarding', 190),
    ('ae8f041f-9004-42cf-a5db-a7e909975744', 'Climbing', 'climbing', 200);

CREATE INDEX idx_sports_sort_order_name ON sports (sort_order, name);

-- +goose Down
DROP TABLE IF EXISTS sports;
