-- roles.sql : Lab 8.4 et 8.5
-- Les rôles portent les logins de la table utilisateur. Pas de mot de passe : tests par SET ROLE.

INSERT INTO utilisateur (login, role) VALUES ('gest.beeafrica', 'gestionnaire')
ON CONFLICT (login) DO NOTHING;
UPDATE utilisateur SET login = 'admin.beeafrica' WHERE login = 'admin';

-- 1. Les groupes, puis les personnes
DO $$
DECLARE r text;
BEGIN
    FOREACH r IN ARRAY ARRAY['qb_apicultrice', 'qb_coordinateur', 'qb_gestionnaire', 'qb_admin'] LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r) THEN
            EXECUTE format('CREATE ROLE %I NOLOGIN', r);
        END IF;
    END LOOP;
    FOREACH r IN ARRAY ARRAY['awa.diop', 'aminata.diop.casa', 'm.ndiaye', 'gest.beeafrica', 'admin.beeafrica'] LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r) THEN
            EXECUTE format('CREATE ROLE %I LOGIN', r);
        END IF;
    END LOOP;
END $$;

GRANT qb_apicultrice  TO "awa.diop", "aminata.diop.casa";
GRANT qb_coordinateur TO "m.ndiaye";
GRANT qb_gestionnaire TO "gest.beeafrica";
GRANT qb_admin        TO "admin.beeafrica";

-- 2. Tout fermer, puis ouvrir le minimum
DO $$ BEGIN
    EXECUTE format('REVOKE CONNECT ON DATABASE %I FROM PUBLIC', current_database());
    EXECUTE format('GRANT CONNECT ON DATABASE %I TO qb_apicultrice, qb_coordinateur, qb_gestionnaire, qb_admin',
                   current_database());
END $$;
REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL TABLES    IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;

GRANT USAGE ON SCHEMA public    TO qb_apicultrice, qb_coordinateur, qb_gestionnaire, qb_admin;
GRANT EXECUTE ON FUNCTION qui() TO qb_apicultrice, qb_coordinateur, qb_gestionnaire, qb_admin;

CREATE OR REPLACE FUNCTION utilisateur_courant() RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
    SELECT id FROM utilisateur WHERE login = qui()
$$;
REVOKE ALL ON FUNCTION utilisateur_courant() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION utilisateur_courant() TO qb_apicultrice;

-- 3. Les vues
DROP VIEW IF EXISTS v_moi, v_mes_mesures, v_mes_recoltes, v_ruches_site, v_recoltes_site CASCADE;
DROP VIEW IF EXISTS v_mes_ruches CASCADE;

CREATE VIEW v_moi AS
SELECT id, login, role, site_id, apicultrice_id FROM utilisateur WHERE login = qui();

CREATE VIEW v_mes_ruches AS
SELECT r.id, r.code, r.site_id, r.latitude, r.longitude, r.date_installation
FROM ruche r JOIN utilisateur u ON u.apicultrice_id = r.apicultrice_id
WHERE u.login = qui();

CREATE VIEW v_mes_mesures AS
SELECT m.ruche_id, m.horodatage, m.poids_kg, m.temp_int_c, m.temp_ext_c, m.humidite_pct,
       m.activite_sonore_db, m.batterie_pct
FROM mesure m
WHERE m.ruche_id IN (SELECT id FROM v_mes_ruches);

CREATE VIEW v_mes_recoltes AS
SELECT rc.id, rc.ruche_id, rc.date_recolte, rc.quantite_kg, rc.statut, rc.declaree_par, rc.date_validation
FROM recolte rc
WHERE rc.ruche_id IN (SELECT id FROM v_mes_ruches)
WITH CHECK OPTION;
ALTER VIEW v_mes_recoltes ALTER COLUMN declaree_par SET DEFAULT utilisateur_courant();

CREATE VIEW v_ruches_site AS
SELECT r.id, r.code, r.latitude, r.longitude, a.nom AS apicultrice, a.telephone
FROM ruche r JOIN apicultrice a ON a.id = r.apicultrice_id
WHERE r.site_id = (SELECT site_id FROM utilisateur WHERE login = qui() AND role = 'coordinateur');

CREATE VIEW v_recoltes_site AS
SELECT rc.id, r.code AS ruche, rc.date_recolte, rc.quantite_kg, rc.statut, rc.date_validation
FROM recolte rc JOIN ruche r ON r.id = rc.ruche_id
WHERE r.site_id = (SELECT site_id FROM utilisateur WHERE login = qui() AND role = 'coordinateur');

-- 4. Les droits (matrice_droits.md)
GRANT SELECT ON v_moi TO qb_apicultrice, qb_coordinateur, qb_gestionnaire, qb_admin;
GRANT SELECT ON v_mes_ruches, v_mes_mesures TO qb_apicultrice;
GRANT SELECT, INSERT (ruche_id, date_recolte, quantite_kg) ON v_mes_recoltes TO qb_apicultrice;
GRANT SELECT ON v_ruches_site, v_recoltes_site TO qb_coordinateur;
GRANT SELECT ON synthese_site_jour, v_export_bailleur TO qb_gestionnaire;
GRANT EXECUTE ON FUNCTION hmac(text, text, text) TO qb_gestionnaire;
GRANT SELECT, INSERT, UPDATE ON utilisateur TO qb_admin;
GRANT SELECT ON journal_audit TO qb_admin;

-- 8.5 La validation d'une récolte
CREATE OR REPLACE FUNCTION valider_recolte(p_recolte uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
    v_coord uuid;
    v_site  text;
    n       int;
BEGIN
    SELECT id, site_id INTO v_coord, v_site
    FROM utilisateur WHERE login = qui() AND role = 'coordinateur';
    IF v_coord IS NULL THEN
        RAISE EXCEPTION 'validation réservée aux coordinateurs';
    END IF;

    UPDATE recolte
    SET statut = 'validee', validee_par = v_coord, date_validation = now()
    WHERE id = p_recolte
      AND statut = 'declaree'
      AND ruche_id IN (SELECT id FROM ruche WHERE site_id = v_site);
    GET DIAGNOSTICS n = ROW_COUNT;
    IF n = 0 THEN
        RAISE EXCEPTION 'récolte introuvable, déjà traitée ou hors de votre site';
    END IF;
END;
$$;
REVOKE ALL ON FUNCTION valider_recolte(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION valider_recolte(uuid) TO qb_coordinateur;

SELECT m.rolname AS personne, g.rolname AS groupe
FROM pg_auth_members am
JOIN pg_roles g ON g.oid = am.roleid
JOIN pg_roles m ON m.oid = am.member
WHERE g.rolname LIKE 'qb\_%'
ORDER BY 2, 1;
