-- formation.sql : Lab 6
DROP TABLE IF EXISTS suivi_formation, formateur, formation_plat CASCADE;

-- 6.1 La table reçue
CREATE TABLE formation_plat (
    telephone text NOT NULL,
    theme     text NOT NULL,
    formateur text NOT NULL,
    PRIMARY KEY (telephone, theme)
);

INSERT INTO formation_plat VALUES
('+221 77 000 01 01', 'varroa',   'Moussa Sarr'),
('+221 77 000 01 01', 'recolte',  'Khady Ndiaye'),
('+221 77 000 01 02', 'varroa',   'Moussa Sarr'),
('+221 77 000 02 01', 'varroa',   'Ibrahima Fall'),
('+221 77 000 02 01', 'capteurs', 'Oumar Diallo'),
('+225 07 000 03 01', 'varroa',   'Kouassi Yao'),
('+225 07 000 03 02', 'capteurs', 'Oumar Diallo'),
('+237 6 00 04 01',   'recolte',  'Khady Ndiaye');

-- 6.2 Le découpage BCNF
CREATE TABLE formateur (
    id    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    nom   text NOT NULL UNIQUE,
    theme text NOT NULL CHECK (theme IN ('varroa', 'recolte', 'capteurs'))
);

CREATE TABLE suivi_formation (
    apicultrice_id uuid NOT NULL REFERENCES apicultrice (id),
    formateur_id   uuid NOT NULL REFERENCES formateur (id),
    PRIMARY KEY (apicultrice_id, formateur_id)
);

INSERT INTO formateur (nom, theme)
SELECT DISTINCT formateur, theme FROM formation_plat;

INSERT INTO suivi_formation (apicultrice_id, formateur_id)
SELECT a.id, f.id
FROM formation_plat p
JOIN apicultrice a ON a.telephone = p.telephone
JOIN formateur f   ON f.nom = p.formateur;

-- 6.3 Le trigger : un seul formateur par thème pour une apicultrice
CREATE OR REPLACE FUNCTION suivi_un_formateur_par_theme() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM suivi_formation s
        JOIN formateur f ON f.id = s.formateur_id
        WHERE s.apicultrice_id = NEW.apicultrice_id
          AND s.formateur_id <> NEW.formateur_id
          AND f.theme = (SELECT theme FROM formateur WHERE id = NEW.formateur_id)
    ) THEN
        RAISE EXCEPTION 'DF violée : cette apicultrice a déjà un formateur pour ce thème';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER suivi_formation_df
BEFORE INSERT OR UPDATE ON suivi_formation
FOR EACH ROW EXECUTE FUNCTION suivi_un_formateur_par_theme();
