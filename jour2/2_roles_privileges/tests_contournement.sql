-- tests_contournement.sql : Lab 8.6 (en postgres, sans ON_ERROR_STOP)
-- f.ba du sujet = awa.diop, coord.sn = m.ndiaye, la récolte de l'autre site = CI-KORH-003

SELECT id AS ruche_autre FROM ruche WHERE code = 'SN-KOLD-011' \gset
SELECT id AS ruche_moi FROM ruche WHERE code = 'SN-CASA-030' \gset
SELECT rc.id AS recolte_autre_site FROM recolte rc JOIN ruche r ON r.id = rc.ruche_id
WHERE r.code = 'CI-KORH-003' \gset

SET ROLE "awa.diop";

-- 1. lire apicultrice : refusé -> attendu
SELECT * FROM apicultrice;

-- 2. lire v_mes_ruches : SN-CASA-030 seulement -> attendu
SELECT code, site_id FROM v_mes_ruches;

-- 3. déclarer sur sa ruche : INSERT 0 1 -> attendu
INSERT INTO v_mes_recoltes (ruche_id, date_recolte, quantite_kg)
VALUES (:'ruche_moi', '2027-03-15', 9.5);

-- 4. déclarer sur la ruche d'une autre : refusé (check option) -> attendu
INSERT INTO v_mes_recoltes (ruche_id, date_recolte, quantite_kg)
VALUES (:'ruche_autre', '2027-03-15', 30);

-- 5. déclarer avec statut = 'validee' : refusé -> attendu
INSERT INTO v_mes_recoltes (ruche_id, date_recolte, quantite_kg, statut)
VALUES (:'ruche_moi', '2027-03-15', 9.5, 'validee');

-- 6. UPDATE recolte : refusé -> attendu
UPDATE recolte SET quantite_kg = 99;

-- 7. appeler valider_recolte : refusé -> attendu
SELECT valider_recolte(id) FROM v_mes_recoltes LIMIT 1;

-- 8. écrire dans journal_audit : refusé -> attendu
INSERT INTO journal_audit (acteur, table_cible, operation) VALUES ('m.ndiaye', 'recolte', 'DELETE');

-- 9. désactiver le trigger d'audit : refusé (doit être le propriétaire) -> attendu
ALTER TABLE recolte DISABLE TRIGGER recolte_audit;

RESET ROLE;
SELECT rc.id AS recolte_t3 FROM recolte rc JOIN ruche r ON r.id = rc.ruche_id
WHERE r.code = 'SN-CASA-030' AND rc.statut = 'declaree' ORDER BY rc.date_recolte DESC LIMIT 1 \gset
SET ROLE "m.ndiaye";

-- 10. valider la récolte du test 3 : accepté, puis refusé la 2e fois -> attendu
SELECT valider_recolte(:'recolte_t3');
SELECT valider_recolte(:'recolte_t3');

-- 11. valider une récolte d'un autre site : refusé -> attendu
SELECT valider_recolte(:'recolte_autre_site');

RESET ROLE;
SET ROLE "admin.beeafrica";

-- 12. lire le journal : awa.diop INSERT et m.ndiaye UPDATE ; supprimer un utilisateur : refusé -> attendu
SELECT acteur, table_cible, operation FROM journal_audit ORDER BY id DESC LIMIT 4;
DELETE FROM utilisateur WHERE login = 'gest.beeafrica';

RESET ROLE;
