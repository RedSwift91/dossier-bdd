-- tests_audit.sql : Lab 8.3, points 2 à 4 (en postgres)

UPDATE recolte SET quantite_kg = 14.0
WHERE ruche_id = (SELECT id FROM ruche WHERE code = 'SN-CASA-021');
SELECT acteur, table_cible, operation, avant ->> 'quantite_kg' AS avant, apres ->> 'quantite_kg' AS apres
FROM journal_audit ORDER BY id DESC LIMIT 1;
-- postgres | recolte | UPDATE | 12.50 | 14.00

SELECT count(*) FROM journal_audit;
UPDATE journal_audit SET acteur = 'personne';
-- ERREUR: journal_audit est en ajout seul : UPDATE interdit
DELETE FROM journal_audit;
-- ERREUR: journal_audit est en ajout seul : DELETE interdit
TRUNCATE journal_audit;
-- ERREUR: journal_audit est en ajout seul : TRUNCATE interdit
SELECT count(*) FROM journal_audit;
-- même nombre qu'avant

ALTER TABLE journal_audit DISABLE TRIGGER journal_ajout_seul;
-- ALTER TABLE : accepté pour le propriétaire (limite)
ALTER TABLE journal_audit ENABLE TRIGGER journal_ajout_seul;
