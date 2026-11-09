-- tests_schema.sql : essayer de casser la base
-- Lancer SANS ON_ERROR_STOP (les erreurs sont voulues) : psql -U postgres -d queenbee -f tests_schema.sql

-- Test 1 : une ruche dont l'apicultrice n'existe pas. Attendu : refus
INSERT INTO ruche (code, latitude, longitude, date_installation, site_id, apicultrice_id)
VALUES ('SN-CASA-900', 12.5, -16.2, current_date, 'SN-CASA', gen_random_uuid());
-- Obtenu : refus. ERREUR: une instruction insert ou update sur la table « ruche » viole la contrainte
--   de clé étrangère « ruche_apicultrice_fk » ; la clé (apicultrice_id)=(...) n'est pas présente dans « apicultrice ».

-- Test 2 : supprimer une apicultrice qui a des ruches. Attendu : refus
DELETE FROM apicultrice WHERE telephone = '+221 77 000 01 01';
-- Obtenu : refus. ERREUR: UPDATE ou DELETE sur la table « apicultrice » viole la contrainte de clé étrangère
--   « ruche_apicultrice_fk » de la table « ruche » ; la clé (id)=(...) est toujours référencée.

-- Test 3 : une ruche sans apicultrice. Attendu : refus
INSERT INTO ruche (code, latitude, longitude, date_installation, site_id)
VALUES ('SN-CASA-901', 12.5, -16.2, current_date, 'SN-CASA');
-- Obtenu : refus. ERREUR: une valeur NULL viole la contrainte NOT NULL de la colonne « apicultrice_id »
--   dans la relation « ruche ».

-- Test 4 : une table sans clé étrangère accepte une ruche orpheline, qui disparaît à la jointure.
-- Attendu : accepté, puis 0 ligne
DROP TABLE IF EXISTS ruche_sans_fk;
CREATE TABLE ruche_sans_fk (code text, apicultrice_id uuid);
INSERT INTO ruche_sans_fk VALUES ('SN-CASA-902', gen_random_uuid());
SELECT r.code, a.nom FROM ruche_sans_fk r JOIN apicultrice a ON a.id = r.apicultrice_id;
DROP TABLE ruche_sans_fk;
-- Obtenu : INSERT 0 1 (accepté), puis la jointure renvoie 0 ligne : l'orpheline est invisible, personne ne la voit.

-- Test 5 : un id serial se devine. Attendu : 1, 2, 3
DROP TABLE IF EXISTS ruche_serial;
CREATE TABLE ruche_serial (id serial PRIMARY KEY, code text);
INSERT INTO ruche_serial (code) VALUES ('A'), ('B'), ('C');
SELECT id, code FROM ruche_serial;
DROP TABLE ruche_serial;
-- Obtenu : 1 A, 2 B, 3 C : les identifiants se suivent, qui voit /ruches/2 essaie /ruches/3.

-- Test 6 : rejouer une mesure déjà reçue (même ruche, même instant). Attendu : refus
INSERT INTO mesure (ruche_id, horodatage, poids_kg)
SELECT ruche_id, horodatage, 99.99 FROM mesure
WHERE ruche_id = (SELECT id FROM ruche WHERE code = 'SN-CASA-014')
ORDER BY horodatage LIMIT 1;
-- Obtenu : refus. ERREUR: la valeur d'une clé dupliquée rompt la contrainte unique « mesure_anti_rejeu » ;
--   la clé (ruche_id, horodatage)=(..., 2027-03-14 01:00:00+01) existe déjà.

-- Test 7 : les ruches dont le site diffère de celui de leur apicultrice.
-- Attendu : selon notre hypothèse du lab 1 (une ruche peut être déplacée), le schéma l'autorise ;
-- dans le jeu d'essai, aucune ruche n'est dans ce cas.
SELECT r.code, r.site_id AS site_ruche, a.site_id AS site_apicultrice
FROM ruche r JOIN apicultrice a ON a.id = r.apicultrice_id
WHERE r.site_id <> a.site_id;
-- Obtenu : 0 ligne. Aucune règle ne l'interdit (hypothèse : une ruche peut être déplacée), le jeu d'essai est cohérent.

-- Test 8 : passer une récolte « déclarée » à « validée » sans validateur. Attendu : refus
UPDATE recolte SET statut = 'validee' WHERE statut = 'declaree';
-- Obtenu : refus. ERREUR: la nouvelle ligne de la relation « recolte » viole la contrainte de vérification
--   « recolte_validation_tracee » (statut validee, validee_par et date_validation NULL).

-- Un UUID suffit-il à protéger la ruche d'une autre apicultrice ?
-- Non. Un UUID n'est pas devinable (contrairement à 1, 2, 3 du test 5), ce qui empêche d'énumérer les
-- ruches. Mais ce n'est pas un contrôle d'accès : un UUID fuit (URL partagée, journal, capture d'écran,
-- export), et une fois connu, rien dans la base n'empêche une autre apicultrice de lire ou modifier la
-- ruche. La protection, c'est l'autorisation : vérifier à chaque requête que ruche.apicultrice_id est
-- celui du compte connecté (droits, vues, ou Row Level Security au jour 2).
