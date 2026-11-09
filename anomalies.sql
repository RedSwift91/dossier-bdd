-- anomalies.sql : provoquer les trois anomalies de extrait_plat, puis nettoyer et prouver
-- Avant : psql -U postgres -d queenbee -v ON_ERROR_STOP=1 -f plat.sql   (extrait propre)
-- À exécuter partie par partie, dans l'ordre, dans le Query Tool.

-- ===== PARTIE 1 · Étape 5.1 : provoquer les anomalies =====

-- Enquête de référence : mesures et poids moyen par pays. Attendu : 3 pays
SELECT pays, count(*) AS nb_mesures, round(avg(poids_kg), 2) AS poids_moyen
FROM extrait_plat GROUP BY pays ORDER BY pays;
-- Obtenu : 3 lignes
--   Cameroun 96 mesures 38.15 kg | Côte d'Ivoire 96 37.56 | Sénégal 336 37.38

-- Anomalie de mise à jour : Sénégal devient Senegal sur une seule ligne...
UPDATE extrait_plat SET pays = 'Senegal'
WHERE ruche_code = 'SN-KOLD-011'
  AND horodatage = (SELECT min(horodatage) FROM extrait_plat WHERE ruche_code = 'SN-KOLD-011');
-- ... et le téléphone d'Awa Diop change sur une seule ligne
UPDATE extrait_plat SET telephone = '+221 77 999 99 99'
WHERE ruche_code = 'SN-CASA-030'
  AND horodatage = (SELECT min(horodatage) FROM extrait_plat WHERE ruche_code = 'SN-CASA-030');
-- Obtenu : UPDATE 1, UPDATE 1

-- L'enquête de nouveau. Attendu : 4 pays
SELECT pays, count(*) AS nb_mesures, round(avg(poids_kg), 2) AS poids_moyen
FROM extrait_plat GROUP BY pays ORDER BY pays;
-- Obtenu : 4 lignes : la base se contredit
--   Cameroun 96 38.15 | Côte d'Ivoire 96 37.56 | Senegal 1 36.14 | Sénégal 335 37.39

-- Anomalie de suppression : on efface les mesures de Fatou Sow (une seule ruche, SN-KOLD-020)
BEGIN;
DELETE FROM extrait_plat WHERE ruche_code = 'SN-KOLD-020';
SELECT apicultrice, telephone FROM extrait_plat WHERE apicultrice = 'Fatou Sow';
ROLLBACK;
-- Obtenu : DELETE 48, puis 0 ligne : Fatou Sow et son téléphone ont disparu avec ses mesures
--   (ROLLBACK annule ensuite la suppression)

-- Anomalie d'insertion : avec la clé (ruche_code, horodatage), un site sans ruche est refusé
ALTER TABLE extrait_plat ADD PRIMARY KEY (ruche_code, horodatage);
INSERT INTO extrait_plat (site_id, site_nom, pays) VALUES ('CM-BAFO', 'Bafoussam', 'Cameroun');
-- Obtenu : ALTER TABLE, puis refus. ERREUR: une valeur NULL viole la contrainte NOT NULL de la colonne
--   « ruche_code » dans la relation « extrait_plat » : pas de site sans ruche ni mesure.

-- ===== PARTIE 2 · Étape 5.2 : après l'échec de migration_3nf.sql, nettoyer =====

-- Migration (1er lancement, avant nettoyage) : refus. ERREUR: la valeur d'une clé dupliquée rompt la
--   contrainte unique « site_pkey » ; la clé « (site_id)=(SN-KOLD) » existe déjà. Rien n'est créé.

-- Les sites qui ont plusieurs pays
SELECT site_id, array_agg(DISTINCT pays) AS pays FROM extrait_plat
GROUP BY site_id HAVING count(DISTINCT pays) > 1;
-- Obtenu : SN-KOLD | {Senegal,Sénégal}

-- Les ruches qui ont plusieurs téléphones
SELECT ruche_code, array_agg(DISTINCT telephone) AS telephones FROM extrait_plat
GROUP BY ruche_code HAVING count(DISTINCT telephone) > 1;
-- Obtenu : SN-CASA-030 | {"+221 77 000 01 02","+221 77 999 99 99"}

-- On garde la valeur majoritaire (la bonne), on corrige la copie fautive
UPDATE extrait_plat SET pays = 'Sénégal' WHERE site_id = 'SN-KOLD' AND pays <> 'Sénégal';
UPDATE extrait_plat SET telephone = '+221 77 000 01 02'
WHERE ruche_code = 'SN-CASA-030' AND telephone <> '+221 77 000 01 02';
-- Obtenu : UPDATE 1, UPDATE 1
-- Puis relancer : psql -U postgres -d queenbee -v ON_ERROR_STOP=1 -f migration_3nf.sql
-- Obtenu : 4 sites, 8 apicultrices, 11 ruches, 528 mesures, COMMIT

-- ===== PARTIE 3 · Étape 5.3 : prouver que rien n'est perdu =====

CREATE OR REPLACE VIEW norm.reconstruit AS
SELECT r.ruche_code, s.site_id, s.site_nom, s.pays, a.apicultrice, a.telephone, a.cooperative,
       m.horodatage, m.poids_kg, m.temp_int_c
FROM norm.mesure m
JOIN norm.ruche r       ON r.ruche_code = m.ruche_code
JOIN norm.site s        ON s.site_id = r.site_id
JOIN norm.apicultrice a ON a.telephone = r.telephone;

-- Différence dans les deux sens. Attendu : 0 ligne
(SELECT * FROM extrait_plat EXCEPT SELECT * FROM norm.reconstruit)
UNION ALL
(SELECT * FROM norm.reconstruit EXCEPT SELECT * FROM extrait_plat);
-- Obtenu : 0 ligne : la décomposition est sans perte

-- Attaque rejouée 1 : un second pays pour un site existant. Attendu : refus
INSERT INTO norm.site (site_id, site_nom, pays) VALUES ('SN-KOLD', 'Kolda', 'Senegal');
-- Obtenu : refus. ERREUR: la valeur d'une clé dupliquée rompt la contrainte unique « site_pkey » ;
--   la clé « (site_id)=(SN-KOLD) » existe déjà.

-- Attaque rejouée 2 : un site sans ruche. Attendu : accepté
INSERT INTO norm.site (site_id, site_nom, pays) VALUES ('CM-BAFO', 'Bafoussam', 'Cameroun');
-- Obtenu : INSERT 0 1 (accepté : un site existe sans ruche)

-- L'enquête par pays sur les tables norm. Attendu : de nouveau 3 pays
SELECT s.pays, count(*) AS nb_mesures, round(avg(m.poids_kg), 2) AS poids_moyen
FROM norm.mesure m
JOIN norm.ruche r ON r.ruche_code = m.ruche_code
JOIN norm.site s  ON s.site_id = r.site_id
GROUP BY s.pays ORDER BY s.pays;
-- Obtenu : de nouveau 3 lignes
--   Cameroun 96 38.15 | Côte d'Ivoire 96 37.56 | Sénégal 336 37.38
