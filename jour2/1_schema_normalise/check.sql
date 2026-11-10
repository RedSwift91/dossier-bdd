-- check.sql : Lab 8.2
-- (on remplace les CHECK sans nom du jour 1 ; notre schéma dit 'administrateur' et 'refusee')
BEGIN;

ALTER TABLE mesure
    DROP CONSTRAINT IF EXISTS mesure_batterie_pct_check,
    DROP CONSTRAINT IF EXISTS mesure_humidite_pct_check,
    DROP CONSTRAINT IF EXISTS mesure_poids_kg_check,
    DROP CONSTRAINT IF EXISTS mesure_batterie_0_100,
    DROP CONSTRAINT IF EXISTS mesure_humidite_0_100,
    DROP CONSTRAINT IF EXISTS mesure_poids_positif,
    ADD CONSTRAINT mesure_batterie_0_100 CHECK (batterie_pct BETWEEN 0 AND 100),
    ADD CONSTRAINT mesure_humidite_0_100 CHECK (humidite_pct BETWEEN 0 AND 100),
    ADD CONSTRAINT mesure_poids_positif  CHECK (poids_kg >= 0);

ALTER TABLE utilisateur
    DROP CONSTRAINT IF EXISTS utilisateur_role_check,
    DROP CONSTRAINT IF EXISTS utilisateur_role_valide,
    ADD CONSTRAINT utilisateur_role_valide
        CHECK (role IN ('apicultrice', 'coordinateur', 'gestionnaire', 'administrateur'));

ALTER TABLE alerte
    DROP CONSTRAINT IF EXISTS alerte_statut_check,
    DROP CONSTRAINT IF EXISTS alerte_statut_valide,
    ADD CONSTRAINT alerte_statut_valide CHECK (statut IN ('ouverte', 'en_cours', 'traitee'));

ALTER TABLE recolte
    DROP CONSTRAINT IF EXISTS recolte_statut_check,
    DROP CONSTRAINT IF EXISTS recolte_statut_valide,
    ADD CONSTRAINT recolte_statut_valide CHECK (statut IN ('declaree', 'validee', 'refusee'));

COMMIT;
