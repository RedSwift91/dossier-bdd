-- tests_denormalisation.sql : les tests du Lab 7 (après volume.sql et denormalisation.sql)
-- psql -U postgres -d queenbee -f tests_denormalisation.sql

-- 7.1 Le volume
SELECT count(*) FROM mesure
WHERE horodatage >= '2026-12-14 00:00+00' AND horodatage < '2027-03-14 00:00+00';
-- 47520

-- 7.1 Le tableau de bord de SN-CASA, les 3 derniers jours
SELECT (m.horodatage AT TIME ZONE 'UTC')::date AS jour, count(*) AS nb_mesures,
       round(avg(m.poids_kg), 2) AS poids_moyen, min(m.poids_kg) AS poids_min, min(m.batterie_pct) AS batterie_min
FROM mesure m JOIN ruche r ON r.id = m.ruche_id
WHERE r.site_id = 'SN-CASA'
GROUP BY 1 ORDER BY 1 DESC LIMIT 3;
-- 192 mesures par jour (4 ruches x 48)

EXPLAIN ANALYZE
SELECT (m.horodatage AT TIME ZONE 'UTC')::date AS jour, count(*) AS nb_mesures,
       round(avg(m.poids_kg), 2) AS poids_moyen, min(m.poids_kg) AS poids_min, min(m.batterie_pct) AS batterie_min
FROM mesure m JOIN ruche r ON r.id = m.ruche_id
WHERE r.site_id = 'SN-CASA'
GROUP BY 1 ORDER BY 1 DESC LIMIT 3;
-- Seq Scan sur mesure (48 048 lignes), Execution Time : 12,870 ms

-- 7.2 Le même tableau de bord dans la synthèse
EXPLAIN ANALYZE
SELECT jour, nb_mesures, poids_moyen, poids_min, batterie_min
FROM synthese_site_jour WHERE site_id = 'SN-CASA' ORDER BY jour DESC LIMIT 3;
-- Index Scan sur synthese_site_jour_pk, Execution Time : 0,267 ms

-- 7.2 Le vol : invisible dans la synthèse jusqu'au REFRESH
INSERT INTO mesure (ruche_id, horodatage, poids_kg, temp_int_c, batterie_pct)
SELECT id, '2027-03-15 06:00+00', 8.40, 33.8, 52 FROM ruche WHERE code = 'SN-CASA-021';
SELECT jour, nb_mesures, poids_min FROM synthese_site_jour WHERE site_id = 'SN-CASA' ORDER BY jour DESC LIMIT 1;
-- 2027-03-14 | 192 | 30.06 : rien d'anormal
REFRESH MATERIALIZED VIEW CONCURRENTLY synthese_site_jour;
SELECT jour, nb_mesures, poids_min FROM synthese_site_jour WHERE site_id = 'SN-CASA' ORDER BY jour DESC LIMIT 1;
-- 2027-03-15 | 1 | 8.40 : le vol n'apparaît qu'après le REFRESH
DELETE FROM mesure WHERE horodatage = '2027-03-15 06:00+00';
REFRESH MATERIALIZED VIEW CONCURRENTLY synthese_site_jour;

-- 7.3 Casser un haché simple (Awa Diop, numéros en +221 77 0...)
SELECT encode(sha256(convert_to(telephone, 'UTF8')), 'hex') AS h FROM apicultrice WHERE nom = 'Awa Diop' \gset
\timing on
SELECT '+221 77 0' || substr(n::text, 2, 2) || ' ' || substr(n::text, 4, 2) || ' ' || substr(n::text, 6, 2) AS telephone
FROM generate_series(1000000, 1999999) AS n
WHERE encode(sha256(convert_to('+221 77 0' || substr(n::text, 2, 2) || ' ' || substr(n::text, 4, 2)
                               || ' ' || substr(n::text, 6, 2), 'UTF8')), 'hex') = :'h';
-- +221 77 000 01 02, retrouvé en 1,3 s
\timing off

-- 7.3 L'export du bailleur, et la clé absente de la vue
SELECT * FROM v_export_bailleur ORDER BY pays, site_id, apicultrice_pseudo;
-- 8 lignes pour 11 ruches, sans nom ni téléphone, positions comme 12.6 | -16.3
SELECT pg_get_viewdef('v_export_bailleur') LIKE '%' || cle || '%' AS cle_dans_la_vue FROM cle_pseudonymisation;
-- f
