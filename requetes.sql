-- requetes.sql : cinq questions à la base Queen Bee
-- Lancer : psql -U postgres -d queenbee -v ON_ERROR_STOP=1 -f requetes.sql

-- Q1. Les ruches du site SN-CASA, avec leur position
-- Algèbre : π code, latitude, longitude ( σ site_id = 'SN-CASA' ( ruche ) )
SELECT code, latitude, longitude FROM ruche WHERE site_id = 'SN-CASA' ORDER BY code;
-- Résultat : 4 lignes

-- Q2. Chaque apicultrice et son nombre de ruches
-- Algèbre : apicultrice ⟕ ruche (jointure externe sur apicultrice_id), puis comptage par a.id
-- GROUP BY a.id : les deux « Aminata Diop » sont comptées séparément
SELECT a.nom, a.site_id, count(r.id) AS nb_ruches
FROM apicultrice a LEFT JOIN ruche r ON r.apicultrice_id = a.id
GROUP BY a.id, a.nom, a.site_id
ORDER BY nb_ruches DESC, a.nom, a.site_id;
-- Résultat : 8 lignes

-- Q3. Les ruches jamais inspectées
-- Algèbre : π code ( ruche ) - π code ( ruche ⋈ inspection )
SELECT code FROM ruche
EXCEPT
SELECT r.code FROM ruche r JOIN inspection i ON i.ruche_id = r.id
ORDER BY code;
-- Résultat : 6 lignes

-- Q4. Les sites qui ont au moins une alerte ouverte
-- Algèbre : π site_id ( σ statut = 'ouverte' ( alerte ) ⋈ ruche )
SELECT DISTINCT r.site_id
FROM alerte al JOIN ruche r ON r.id = al.ruche_id
WHERE al.statut = 'ouverte'
ORDER BY r.site_id;
-- Résultat : 2 lignes

-- Q5. Une vue pour le coordinateur : code, site, dernière pesée ; ni nom ni téléphone
-- Algèbre : π code, site_id, horodatage, poids_kg ( ruche ⋈ σ dernière mesure ( mesure ) )
CREATE OR REPLACE VIEW v_ruche_coordinateur AS
SELECT r.code, r.site_id, m.horodatage AS derniere_pesee, m.poids_kg
FROM ruche r
LEFT JOIN LATERAL (
    SELECT horodatage, poids_kg FROM mesure
    WHERE ruche_id = r.id ORDER BY horodatage DESC LIMIT 1
) m ON true;

SELECT * FROM v_ruche_coordinateur ORDER BY code;
-- Résultat : 11 lignes

-- Pourquoi une application ne doit jamais faire SELECT * sur la table des apicultrices ?
-- SELECT * renvoie toutes les colonnes, dont le nom et le téléphone (données personnelles) :
-- l'application les reçoit même si elle n'en a pas besoin, elles peuvent fuiter dans un cache,
-- un journal ou une réponse d'API, et une colonne sensible ajoutée plus tard sera exposée sans
-- que personne ne l'ait décidé. On projette uniquement les colonnes nécessaires (moindre
-- privilège), ou on passe par une vue comme v_ruche_coordinateur.

-- ===== Testez-vous · Lab 3 =====
-- 1. JOIN ne garde que les apicultrices qui ont au moins une ruche ; LEFT JOIN garde aussi celles qui
--    n'en ont aucune (count(r.id) vaut alors 0). Pour « chaque apicultrice », il faut LEFT JOIN.
-- 2. L'apostrophe ferme la chaîne ouverte par le programme (code = ''), ce qui permet d'écrire du SQL à
--    la suite (UNION SELECT ...) ; les deux tirets transforment en commentaire le reste de la requête,
--    dont l'apostrophe finale ajoutée par le programme, qui sinon provoquerait une erreur de syntaxe.
-- 3. Parce que filtrer, c'est jouer contre l'attaquant : il existe d'autres façons de sortir du contexte
--    (champ numérique sans apostrophe : 0 OR 1=1, antislash, encodages, guillemets typographiques
--    convertis, injection de second ordre depuis une valeur déjà stockée), et on casse les vrais noms
--    (N'Diaye, Côte d'Ivoire). Seule la requête paramétrée sépare structurellement code et données.
