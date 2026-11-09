-- contraintes.sql : confronter les dépendances fonctionnelles aux données, puis rendre les logins uniques
-- À exécuter requête par requête dans le Query Tool (ou psql -f, sans ON_ERROR_STOP)

-- ===== Étape 4.3 · Une requête par dépendance : attendu 0 ligne pour chacune =====

-- DF1 : site_id -> site_nom, pays
SELECT site_id FROM extrait_plat GROUP BY site_id
HAVING count(DISTINCT site_nom) > 1 OR count(DISTINCT pays) > 1;
-- Obtenu : 0 ligne

-- DF2 : ruche_code -> site_id, telephone
SELECT ruche_code FROM extrait_plat GROUP BY ruche_code
HAVING count(DISTINCT site_id) > 1 OR count(DISTINCT telephone) > 1;
-- Obtenu : 0 ligne

-- DF3 : telephone -> apicultrice, cooperative
SELECT telephone FROM extrait_plat GROUP BY telephone
HAVING count(DISTINCT apicultrice) > 1 OR count(DISTINCT cooperative) > 1;
-- Obtenu : 0 ligne

-- DF4 : ruche_code, horodatage -> poids_kg, temp_int_c
SELECT ruche_code, horodatage FROM extrait_plat GROUP BY ruche_code, horodatage
HAVING count(DISTINCT poids_kg) > 1 OR count(DISTINCT temp_int_c) > 1;
-- Obtenu : 0 ligne

-- Fausse DF : apicultrice -> telephone. Attendu : « Aminata Diop », 2 téléphones
SELECT apicultrice, count(DISTINCT telephone) AS nb_telephones
FROM extrait_plat GROUP BY apicultrice
HAVING count(DISTINCT telephone) > 1;
-- Obtenu : Aminata Diop | 2 : la DF est fausse, deux personnes portent ce nom

-- ===== Étape 4.4 · Rendre les logins uniques (dans l'ordre, une par une) =====

-- Commande 1 : les logins en double. Attendu : a.diop, 3 fois
SELECT login, count(*) AS nb FROM utilisateur GROUP BY login HAVING count(*) > 1;
-- Obtenu : a.diop | 3

-- Commande 2 : la contrainte UNIQUE sur des données en double. Attendu : refus
ALTER TABLE utilisateur ADD CONSTRAINT utilisateur_login_unique UNIQUE (login);
-- Obtenu : refus. ERREUR: n'a pas pu créer l'index unique « utilisateur_login_unique » ;
--   la clé (login)=(a.diop) est dupliquée.

-- Commande 3 : un login différent pour chaque personne (prénom.nom, suffixé du site pour les homonymes)
UPDATE utilisateur u SET login = 'aminata.diop.casa'
FROM apicultrice a WHERE u.apicultrice_id = a.id AND a.telephone = '+221 77 000 01 01';
UPDATE utilisateur u SET login = 'aminata.diop.kold'
FROM apicultrice a WHERE u.apicultrice_id = a.id AND a.telephone = '+221 77 000 02 01';
UPDATE utilisateur u SET login = 'awa.diop'
FROM apicultrice a WHERE u.apicultrice_id = a.id AND a.telephone = '+221 77 000 01 02';
-- Obtenu : UPDATE 1, UPDATE 1, UPDATE 1

-- Commande 4 : la même contrainte. Attendu : acceptée
ALTER TABLE utilisateur ADD CONSTRAINT utilisateur_login_unique UNIQUE (login);
-- Obtenu : ALTER TABLE (acceptée)

-- Commande 5 : le piège des majuscules. Attendu : accepté, puis supprimé
INSERT INTO utilisateur (login, role) VALUES ('Awa.Diop', 'gestionnaire');
DELETE FROM utilisateur WHERE login = 'Awa.Diop';
-- Obtenu : INSERT 0 1 (accepté : 'Awa.Diop' <> 'awa.diop' pour UNIQUE), puis DELETE 1

-- Commande 6 : index unique insensible à la casse, puis de nouveau. Attendu : refus
CREATE UNIQUE INDEX utilisateur_login_ci ON utilisateur (lower(login));
INSERT INTO utilisateur (login, role) VALUES ('Awa.Diop', 'gestionnaire');
-- Obtenu : CREATE INDEX, puis refus. ERREUR: la valeur d'une clé dupliquée rompt la contrainte unique
--   « utilisateur_login_ci » ; la clé « (lower(login))=(awa.diop) » existe déjà.

-- Quelles lettres STRIDE un login partagé permet-il ?
-- S (Spoofing) : quand deux personnes ont le même login, l'une peut se connecter (ou être
--   authentifiée) à la place de l'autre ;
-- R (Repudiation) : le journal dit « a.diop a validé », mais on ne sait pas laquelle :
--   chacune peut nier ;
-- E (Elevation of privilege) : si le login partagé est résolu vers le mauvais compte, on hérite
--   des droits de l'autre (par exemple ses ruches, ou un rôle plus élevé) ;
-- I (Information disclosure) : on voit les ruches (GPS) et les récoltes de l'homonyme.
