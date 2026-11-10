-- jeton.sql : Lab 9 (f.ba du sujet = awa.diop)
DROP TABLE IF EXISTS session_app, jeton CASCADE;

CREATE TABLE jeton (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    utilisateur_id uuid NOT NULL REFERENCES utilisateur (id),
    valeur         text NOT NULL UNIQUE,
    expire_le      timestamptz NOT NULL,
    utilise_le     timestamptz
);

CREATE TABLE session_app (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    utilisateur_id uuid NOT NULL REFERENCES utilisateur (id),
    jeton_id       uuid NOT NULL REFERENCES jeton (id),
    ouverte_le     timestamptz NOT NULL DEFAULT clock_timestamp()
);

INSERT INTO jeton (utilisateur_id, valeur, expire_le)
SELECT id, 'RT-' || login || '-' || n, now() + INTERVAL '1 day'
FROM utilisateur CROSS JOIN generate_series(1, 30) AS n
WHERE login = 'awa.diop';

-- 9.4 correction 3
ALTER TABLE session_app ADD CONSTRAINT session_jeton_unique UNIQUE (jeton_id);
