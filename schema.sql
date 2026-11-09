-- schema.sql : base Queen Bee
-- Lancer : psql -U postgres -d queenbee -v ON_ERROR_STOP=1 -f schema.sql
DROP TABLE IF EXISTS alerte, recolte, inspection, mesure, utilisateur, adhesion,
                     ruche, apicultrice, cooperative, site CASCADE;

-- Le site : code lisible, court, stable et non secret ('SN-CASA')
CREATE TABLE site (
    id       text PRIMARY KEY,
    nom      text NOT NULL,
    pays     text NOT NULL,
    localite text NOT NULL
);

CREATE TABLE cooperative (
    id      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    nom     text NOT NULL,
    site_id text NOT NULL CONSTRAINT cooperative_site_fk REFERENCES site(id)
);

-- Donnée personnelle : identifiant aléatoire, jamais le nom (homonymes)
CREATE TABLE apicultrice (
    id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    nom       text NOT NULL,
    telephone text NOT NULL,
    site_id   text NOT NULL CONSTRAINT apicultrice_site_fk REFERENCES site(id)
);

CREATE TABLE ruche (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code              text NOT NULL UNIQUE,                 -- 'SN-CASA-014' : jamais deux fois
    latitude          numeric(8,5) NOT NULL CHECK (latitude BETWEEN -90 AND 90),
    longitude         numeric(8,5) NOT NULL CHECK (longitude BETWEEN -180 AND 180),
    date_installation date NOT NULL,
    site_id           text NOT NULL CONSTRAINT ruche_site_fk REFERENCES site(id),
    apicultrice_id    uuid NOT NULL CONSTRAINT ruche_apicultrice_fk REFERENCES apicultrice(id)
);

-- Association n,n ADHÈRE : clé primaire sur les deux clés étrangères
CREATE TABLE adhesion (
    apicultrice_id uuid NOT NULL CONSTRAINT adhesion_apicultrice_fk REFERENCES apicultrice(id),
    cooperative_id uuid NOT NULL CONSTRAINT adhesion_cooperative_fk REFERENCES cooperative(id),
    date_adhesion  date NOT NULL DEFAULT current_date,
    PRIMARY KEY (apicultrice_id, cooperative_id)
);

-- Les comptes de connexion (les 4 rôles du sujet)
CREATE TABLE utilisateur (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    login             text NOT NULL,                        -- UNIQUE posé au lab 4
    mot_de_passe_hash text,                                 -- jamais le mot de passe en clair
    role              text NOT NULL
                      CHECK (role IN ('apicultrice', 'coordinateur', 'gestionnaire', 'administrateur')),
    site_id           text CONSTRAINT utilisateur_site_fk REFERENCES site(id),
    apicultrice_id    uuid UNIQUE                           -- 0,1 - 0,1 : jamais deux comptes
                      CONSTRAINT utilisateur_apicultrice_fk REFERENCES apicultrice(id),
    -- un compte « apicultrice » pointe vers une apicultrice, et lui seul
    CHECK ((role = 'apicultrice') = (apicultrice_id IS NOT NULL)),
    -- un coordinateur est toujours rattaché à son site
    CHECK (role <> 'coordinateur' OR site_id IS NOT NULL)
);

CREATE TABLE mesure (
    id                 bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ruche_id           uuid NOT NULL CONSTRAINT mesure_ruche_fk REFERENCES ruche(id),
    horodatage         timestamptz NOT NULL,
    poids_kg           numeric(5,2) CHECK (poids_kg >= 0),
    temp_int_c         numeric(4,1),
    temp_ext_c         numeric(4,1),
    humidite_pct       smallint CHECK (humidite_pct BETWEEN 0 AND 100),
    activite_sonore_db numeric(4,1) CHECK (activite_sonore_db >= 0),
    batterie_pct       smallint CHECK (batterie_pct BETWEEN 0 AND 100),
    CONSTRAINT mesure_anti_rejeu UNIQUE (ruche_id, horodatage)   -- anti-rejeu
);

CREATE TABLE inspection (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    ruche_id        uuid NOT NULL CONSTRAINT inspection_ruche_fk REFERENCES ruche(id),
    date_inspection date NOT NULL,
    etat_colonie    text NOT NULL CHECK (etat_colonie IN ('forte', 'moyenne', 'faible', 'morte')),
    reine_presente  boolean NOT NULL,
    observations    text
);

CREATE TABLE recolte (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    ruche_id        uuid NOT NULL CONSTRAINT recolte_ruche_fk REFERENCES ruche(id),
    date_recolte    date NOT NULL,
    quantite_kg     numeric(6,2) NOT NULL CONSTRAINT recolte_quantite_positive CHECK (quantite_kg > 0),
    statut          text NOT NULL DEFAULT 'declaree' CHECK (statut IN ('declaree', 'validee', 'refusee')),
    declaree_par    uuid NOT NULL CONSTRAINT recolte_declaree_par_fk REFERENCES utilisateur(id),
    validee_par    uuid CONSTRAINT recolte_validee_par_fk REFERENCES utilisateur(id),
    date_validation timestamptz,
    -- une récolte validée (ou refusée) dit toujours par qui et quand ; une récolte déclarée, jamais
    CONSTRAINT recolte_validation_tracee CHECK (
        (statut = 'declaree') = (validee_par IS NULL AND date_validation IS NULL)),
    -- personne ne valide sa propre récolte
    CONSTRAINT recolte_pas_auto_validation CHECK (validee_par IS DISTINCT FROM declaree_par)
);

CREATE TABLE alerte (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    ruche_id         uuid NOT NULL CONSTRAINT alerte_ruche_fk REFERENCES ruche(id),
    type_alerte      text NOT NULL CHECK (type_alerte IN ('essaimage', 'vol', 'capteur_silencieux')),
    date_alerte      timestamptz NOT NULL DEFAULT now(),
    niveau_confiance numeric(3,2) NOT NULL
                     CONSTRAINT alerte_confiance_bornee CHECK (niveau_confiance BETWEEN 0 AND 1),
    statut           text NOT NULL DEFAULT 'ouverte' CHECK (statut IN ('ouverte', 'traitee'))
);
