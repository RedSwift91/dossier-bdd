-- migration_3nf.sql : découper extrait_plat en tables BCNF, une par déterminant
-- Lancer : psql -U postgres -d queenbee -v ON_ERROR_STOP=1 -f migration_3nf.sql
BEGIN;

DROP SCHEMA IF EXISTS norm CASCADE;
CREATE SCHEMA norm;

CREATE TABLE norm.site (                -- déterminant : site_id
    site_id  text PRIMARY KEY,
    site_nom text NOT NULL,
    pays     text NOT NULL
);

CREATE TABLE norm.apicultrice (         -- déterminant : telephone
    telephone   text PRIMARY KEY,
    apicultrice text NOT NULL,
    cooperative text NOT NULL
);

CREATE TABLE norm.ruche (               -- déterminant : ruche_code
    ruche_code text PRIMARY KEY,
    site_id    text NOT NULL REFERENCES norm.site(site_id),
    telephone  text NOT NULL REFERENCES norm.apicultrice(telephone)
);

CREATE TABLE norm.mesure (              -- clé : (ruche_code, horodatage)
    ruche_code text NOT NULL REFERENCES norm.ruche(ruche_code),
    horodatage timestamptz NOT NULL,
    poids_kg   numeric(5,2),
    temp_int_c numeric(4,1),
    PRIMARY KEY (ruche_code, horodatage)
);

INSERT INTO norm.site SELECT DISTINCT site_id, site_nom, pays FROM extrait_plat;
INSERT INTO norm.apicultrice SELECT DISTINCT telephone, apicultrice, cooperative FROM extrait_plat;
INSERT INTO norm.ruche SELECT DISTINCT ruche_code, site_id, telephone FROM extrait_plat;
INSERT INTO norm.mesure SELECT ruche_code, horodatage, poids_kg, temp_int_c FROM extrait_plat;

SELECT (SELECT count(*) FROM norm.site)        AS sites,
       (SELECT count(*) FROM norm.apicultrice) AS apicultrices,
       (SELECT count(*) FROM norm.ruche)       AS ruches,
       (SELECT count(*) FROM norm.mesure)      AS mesures;

COMMIT;
