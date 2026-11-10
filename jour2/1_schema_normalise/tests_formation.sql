-- tests_formation.sql : les tests du Lab 6 (après formation.sql)
-- psql -U postgres -d queenbee -f tests_formation.sql

-- 6.1 Les trois dépendances : 0 ligne chacune
SELECT telephone, theme FROM formation_plat GROUP BY telephone, theme HAVING count(DISTINCT formateur) > 1;
SELECT formateur FROM formation_plat GROUP BY formateur HAVING count(DISTINCT theme) > 1;
SELECT telephone, formateur FROM formation_plat GROUP BY telephone, formateur HAVING count(DISTINCT theme) > 1;
-- 0 ligne, 0 ligne, 0 ligne

-- 6.1 L'anomalie
BEGIN;
UPDATE formation_plat SET theme = 'capteurs' WHERE telephone = '+221 77 000 01 02' AND formateur = 'Moussa Sarr';
SELECT formateur, array_agg(DISTINCT theme) FROM formation_plat GROUP BY formateur HAVING count(DISTINCT theme) > 1;
-- Moussa Sarr | {capteurs,varroa} : accepté sans erreur
ROLLBACK;

-- 6.2 Le mauvais découpage
CREATE TEMP TABLE p1 AS SELECT DISTINCT telephone, theme FROM formation_plat;
CREATE TEMP TABLE p2 AS SELECT DISTINCT theme, formateur FROM formation_plat;
SELECT count(*) FROM p1 JOIN p2 USING (theme);
-- 16 (au lieu de 8)
SELECT telephone, theme, formateur FROM p1 JOIN p2 USING (theme)
EXCEPT SELECT telephone, theme, formateur FROM formation_plat ORDER BY 1, 2, 3;
-- 8 lignes inventées, dont +221 77 000 01 02 | varroa | Ibrahima Fall et Kouassi Yao

-- 6.2 La preuve que le bon découpage ne perd rien
(SELECT telephone, theme, formateur FROM formation_plat
 EXCEPT
 SELECT a.telephone, f.theme, f.nom FROM suivi_formation s
 JOIN apicultrice a ON a.id = s.apicultrice_id JOIN formateur f ON f.id = s.formateur_id)
UNION ALL
(SELECT a.telephone, f.theme, f.nom FROM suivi_formation s
 JOIN apicultrice a ON a.id = s.apicultrice_id JOIN formateur f ON f.id = s.formateur_id
 EXCEPT
 SELECT telephone, theme, formateur FROM formation_plat);
-- 0 ligne : rien de perdu, rien d'inventé

-- 6.3 La règle perdue (sans le trigger)
BEGIN;
ALTER TABLE suivi_formation DISABLE TRIGGER suivi_formation_df;
INSERT INTO suivi_formation SELECT a.id, f.id FROM apicultrice a, formateur f
WHERE a.telephone = '+221 77 000 01 02' AND f.nom = 'Ibrahima Fall';
SELECT a.nom, f.theme, array_agg(f.nom) FROM suivi_formation s
JOIN apicultrice a ON a.id = s.apicultrice_id JOIN formateur f ON f.id = s.formateur_id
GROUP BY a.id, a.nom, f.theme HAVING count(*) > 1;
-- Awa Diop | varroa | {"Moussa Sarr","Ibrahima Fall"}
ROLLBACK;

-- 6.3 Avec le trigger
INSERT INTO suivi_formation SELECT a.id, f.id FROM apicultrice a, formateur f
WHERE a.telephone = '+221 77 000 01 02' AND f.nom = 'Ibrahima Fall';
-- ERREUR: DF violée : cette apicultrice a déjà un formateur pour ce thème
INSERT INTO suivi_formation SELECT a.id, f.id FROM apicultrice a, formateur f
WHERE a.telephone = '+221 77 000 01 02' AND f.nom = 'Khady Ndiaye';
-- INSERT 0 1 : thème nouveau pour elle (supprimé ensuite pour pouvoir relancer)
DELETE FROM suivi_formation
WHERE apicultrice_id = (SELECT id FROM apicultrice WHERE telephone = '+221 77 000 01 02')
  AND formateur_id = (SELECT id FROM formateur WHERE nom = 'Khady Ndiaye');

-- 6.3 Changer de formateur dans le même thème : l'ancienne ligne ne compte pas
BEGIN;
UPDATE suivi_formation SET formateur_id = (SELECT id FROM formateur WHERE nom = 'Ibrahima Fall')
WHERE apicultrice_id = (SELECT id FROM apicultrice WHERE telephone = '+221 77 000 01 02')
  AND formateur_id = (SELECT id FROM formateur WHERE nom = 'Moussa Sarr');
-- UPDATE 1 : accepté
ROLLBACK;

-- 6.3 Changer le thème d'un formateur
UPDATE formateur SET theme = 'varroa' WHERE nom = 'Khady Ndiaye';
-- ERREUR: DF violée : une apicultrice de ce formateur a déjà un formateur pour ce thème
BEGIN;
UPDATE formateur SET theme = 'capteurs' WHERE nom = 'Kouassi Yao';
-- UPDATE 1 : accepté, son apicultrice n'a pas d'autre formateur capteurs
ROLLBACK;

-- 6.4 Les ruches d'une apicultrice sont-elles sur son site ?
SELECT a.nom, a.site_id AS site_apicultrice, array_agg(DISTINCT r.site_id) AS sites_ruches
FROM apicultrice a JOIN ruche r ON r.apicultrice_id = a.id
GROUP BY a.id, a.nom, a.site_id ORDER BY 2, 1;
-- 8 lignes : chaque apicultrice n'a de ruches que sur son site
