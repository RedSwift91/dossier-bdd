-- denormalisation.sql : Lab 7

-- 7.2 La synthèse
DROP MATERIALIZED VIEW IF EXISTS synthese_site_jour CASCADE;

CREATE MATERIALIZED VIEW synthese_site_jour AS
SELECT r.site_id,
       (m.horodatage AT TIME ZONE 'UTC')::date AS jour,
       count(*)                  AS nb_mesures,
       round(avg(m.poids_kg), 2) AS poids_moyen,
       min(m.poids_kg)           AS poids_min,
       min(m.batterie_pct)       AS batterie_min
FROM mesure m JOIN ruche r ON r.id = m.ruche_id
GROUP BY r.site_id, (m.horodatage AT TIME ZONE 'UTC')::date;

CREATE UNIQUE INDEX synthese_site_jour_pk ON synthese_site_jour (site_id, jour);

-- 7.3 L'export pour le bailleur
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS cle_pseudonymisation (
    id  int PRIMARY KEY CHECK (id = 1),
    cle text NOT NULL
);
INSERT INTO cle_pseudonymisation VALUES (1, encode(gen_random_bytes(32), 'hex'))
ON CONFLICT (id) DO NOTHING;
REVOKE ALL ON cle_pseudonymisation FROM PUBLIC;

DROP VIEW IF EXISTS v_export_bailleur;
CREATE VIEW v_export_bailleur AS
SELECT left(encode(hmac(a.id::text, k.cle, 'sha256'), 'hex'), 12) AS apicultrice_pseudo,
       s.pays,
       s.id                  AS site_id,
       round(r.latitude, 1)  AS latitude,
       round(r.longitude, 1) AS longitude,
       coalesce(sum(rc.quantite_kg) FILTER (WHERE rc.statut = 'validee'), 0) AS recolte_validee_kg
FROM ruche r
JOIN apicultrice a   ON a.id = r.apicultrice_id
JOIN site s          ON s.id = r.site_id
LEFT JOIN recolte rc ON rc.ruche_id = r.id
CROSS JOIN cle_pseudonymisation k
GROUP BY 1, 2, 3, 4, 5;

-- 7.4 Le journal d'audit
CREATE TABLE IF NOT EXISTS journal_audit (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    horodatage  timestamptz NOT NULL DEFAULT clock_timestamp(),
    acteur      text NOT NULL,
    table_cible text NOT NULL,
    operation   text NOT NULL CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')),
    ligne_id    text,
    avant       jsonb,
    apres       jsonb
);
REVOKE ALL ON journal_audit FROM PUBLIC;
