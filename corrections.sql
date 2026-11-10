-- corrections.sql : Lab 10 (voir rapport_revue.md)

-- P2 : la vue de carte ne montre que ses ruches, sans téléphone
DROP VIEW IF EXISTS v_carte_ruches;
CREATE VIEW v_carte_ruches WITH (security_barrier = true) AS
SELECT r.code, r.latitude, r.longitude
FROM ruche r JOIN utilisateur u ON u.apicultrice_id = r.apicultrice_id
WHERE u.login = qui();
GRANT SELECT ON v_carte_ruches TO qb_apicultrice;

-- P3 : le filtre des vues passe avant les fonctions de l'utilisateur, et plus de pg_temp
ALTER VIEW v_moi           SET (security_barrier = true);
ALTER VIEW v_mes_ruches    SET (security_barrier = true);
ALTER VIEW v_mes_mesures   SET (security_barrier = true);
ALTER VIEW v_mes_recoltes  SET (security_barrier = true);
ALTER VIEW v_ruches_site   SET (security_barrier = true);
ALTER VIEW v_recoltes_site SET (security_barrier = true);
DO $$ BEGIN
    EXECUTE format('REVOKE TEMPORARY ON DATABASE %I FROM PUBLIC', current_database());
END $$;

-- R2 : les nouvelles fonctions ne sont plus exécutables par PUBLIC
ALTER DEFAULT PRIVILEGES FOR ROLE postgres REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;

-- R4 : une ruche est sur le site de son apicultrice
ALTER TABLE ruche DROP CONSTRAINT IF EXISTS ruche_apicultrice_site_fk;
ALTER TABLE apicultrice DROP CONSTRAINT IF EXISTS apicultrice_id_site_unique;
ALTER TABLE apicultrice ADD CONSTRAINT apicultrice_id_site_unique UNIQUE (id, site_id);
ALTER TABLE ruche ADD CONSTRAINT ruche_apicultrice_site_fk
    FOREIGN KEY (apicultrice_id, site_id) REFERENCES apicultrice (id, site_id) ON UPDATE CASCADE;

-- R1 : un compte applicatif avec le minimum de droits pour recherche.py
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'qb_recherche') THEN
        CREATE ROLE qb_recherche LOGIN;
    END IF;
    EXECUTE format('GRANT CONNECT ON DATABASE %I TO qb_recherche', current_database());
END $$;
GRANT USAGE ON SCHEMA public TO qb_recherche;
GRANT SELECT (code, date_installation, site_id) ON ruche TO qb_recherche;
