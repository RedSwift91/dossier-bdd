-- plat.sql : une seule table, une ligne par mesure, avec tout son contexte recopié
-- Lancer : psql -U postgres -d queenbee -v ON_ERROR_STOP=1 -f plat.sql
DROP TABLE IF EXISTS extrait_plat;

CREATE TABLE extrait_plat AS
SELECT r.code       AS ruche_code,
       s.id         AS site_id,
       s.nom        AS site_nom,
       s.pays       AS pays,
       a.nom        AS apicultrice,
       a.telephone  AS telephone,
       c.nom        AS cooperative,
       m.horodatage AS horodatage,
       m.poids_kg   AS poids_kg,
       m.temp_int_c AS temp_int_c
FROM mesure m
JOIN ruche r       ON r.id = m.ruche_id
JOIN site s        ON s.id = r.site_id
JOIN apicultrice a ON a.id = r.apicultrice_id
JOIN adhesion ad   ON ad.apicultrice_id = a.id
JOIN cooperative c ON c.id = ad.cooperative_id;
