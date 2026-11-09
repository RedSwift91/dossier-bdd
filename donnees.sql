-- donnees.sql : jeu d'essai Queen Bee (numéros de téléphone fictifs)
-- Lancer : psql -U postgres -d queenbee -v ON_ERROR_STOP=1 -f donnees.sql
BEGIN;

SELECT setseed(0.42);   -- mesures « aléatoires » mais identiques à chaque lancement

INSERT INTO site (id, nom, pays, localite) VALUES
('SN-CASA', 'Casamance',  'Sénégal',       'Ziguinchor'),
('SN-KOLD', 'Kolda',      'Sénégal',       'Kolda'),
('CI-KORH', 'Korhogo',    'Côte d''Ivoire', 'Korhogo'),
('CM-NGAO', 'Adamaoua',   'Cameroun',      'Ngaoundéré');

INSERT INTO cooperative (nom, site_id) VALUES
('Coopérative des apicultrices de Casamance', 'SN-CASA'),
('Miel de Kolda',                             'SN-KOLD'),
('Coopérative Senoufo du miel',               'CI-KORH'),
('Abeilles de l''Adamaoua',                   'CM-NGAO');

INSERT INTO apicultrice (nom, telephone, site_id) VALUES
('Aminata Diop',   '+221 77 000 01 01', 'SN-CASA'),
('Awa Diop',       '+221 77 000 01 02', 'SN-CASA'),
('Aminata Diop',   '+221 77 000 02 01', 'SN-KOLD'),   -- homonyme volontaire
('Fatou Sow',      '+221 77 000 02 02', 'SN-KOLD'),
('Mariam Kone',    '+225 07 000 03 01', 'CI-KORH'),
('Adjoua Kouassi', '+225 07 000 03 02', 'CI-KORH'),
('Hadja Bello',    '+237 6 00 04 01',   'CM-NGAO'),
('Clarisse Ngo',   '+237 6 00 04 02',   'CM-NGAO');

-- Les ruches : l'UUID de l'apicultrice est retrouvé par son téléphone, jamais recopié
INSERT INTO ruche (code, latitude, longitude, date_installation, site_id, apicultrice_id) VALUES
('SN-CASA-014', 12.56210, -16.27150, '2025-11-03', 'SN-CASA', (SELECT id FROM apicultrice WHERE telephone = '+221 77 000 01 01')),
('SN-CASA-021', 12.56480, -16.26890, '2025-11-03', 'SN-CASA', (SELECT id FROM apicultrice WHERE telephone = '+221 77 000 01 01')),
('SN-CASA-099', 12.57020, -16.28010, '2026-02-17', 'SN-CASA', (SELECT id FROM apicultrice WHERE telephone = '+221 77 000 01 01')),
('SN-CASA-030', 12.55870, -16.29340, '2026-01-09', 'SN-CASA', (SELECT id FROM apicultrice WHERE telephone = '+221 77 000 01 02')),
('SN-KOLD-011', 12.89410, -14.94120, '2025-12-01', 'SN-KOLD', (SELECT id FROM apicultrice WHERE telephone = '+221 77 000 02 01')),
('SN-KOLD-012', 12.89770, -14.93850, '2025-12-01', 'SN-KOLD', (SELECT id FROM apicultrice WHERE telephone = '+221 77 000 02 01')),
('SN-KOLD-020', 12.88530, -14.95600, '2026-03-12', 'SN-KOLD', (SELECT id FROM apicultrice WHERE telephone = '+221 77 000 02 02')),
('CI-KORH-003',  9.45810,  -5.62930, '2025-10-20', 'CI-KORH', (SELECT id FROM apicultrice WHERE telephone = '+225 07 000 03 01')),
('CI-KORH-008',  9.46350,  -5.63480, '2026-01-15', 'CI-KORH', (SELECT id FROM apicultrice WHERE telephone = '+225 07 000 03 02')),
('CM-NGAO-005',  7.32160,  13.58420, '2025-09-30', 'CM-NGAO', (SELECT id FROM apicultrice WHERE telephone = '+237 6 00 04 01')),
('CM-NGAO-017',  7.33090,  13.57710, '2026-04-02', 'CM-NGAO', (SELECT id FROM apicultrice WHERE telephone = '+237 6 00 04 02'));

-- Chaque apicultrice adhère à la coopérative de son site
INSERT INTO adhesion (apicultrice_id, cooperative_id, date_adhesion)
SELECT a.id, c.id, DATE '2025-09-01'
FROM apicultrice a JOIN cooperative c ON c.site_id = a.site_id;

-- Un compte par apicultrice : login « initiale.nom » (donc a.diop en triple, corrigé au lab 4)
INSERT INTO utilisateur (login, role, site_id, apicultrice_id)
SELECT lower(left(nom, 1)) || '.' || lower(split_part(nom, ' ', 2)), 'apicultrice', site_id, id
FROM apicultrice;

-- Plus un coordinateur (site SN-CASA) et un administrateur
INSERT INTO utilisateur (login, role, site_id) VALUES
('m.ndiaye', 'coordinateur',   'SN-CASA'),
('admin',    'administrateur', NULL);

-- 48 mesures par ruche : une toutes les 30 minutes pendant 24 h
INSERT INTO mesure (ruche_id, horodatage, poids_kg, temp_int_c, temp_ext_c, humidite_pct,
                    activite_sonore_db, batterie_pct)
SELECT r.id,
       TIMESTAMPTZ '2027-03-14 00:00+00' + h * INTERVAL '30 minutes',
       round((30 + random() * 15)::numeric, 2),
       round((33 + random() * 3)::numeric, 1),
       round((22 + random() * 12)::numeric, 1),
       40 + floor(random() * 40)::int,
       round((35 + random() * 25)::numeric, 1),
       100 - h
FROM ruche r CROSS JOIN generate_series(0, 47) AS h;

-- 6 inspections sur 5 ruches : 6 ruches ne sont jamais inspectées
INSERT INTO inspection (ruche_id, date_inspection, etat_colonie, reine_presente, observations)
SELECT r.id, v.d::date, v.etat, v.reine, v.obs
FROM (VALUES
  ('SN-CASA-014', '2027-02-10', 'forte',   true,  'Cadres de couvain bien remplis'),
  ('SN-CASA-014', '2027-03-10', 'forte',   true,  'Cellules royales observées : risque d''essaimage'),
  ('SN-CASA-099', '2027-03-02', 'moyenne', true,  NULL),
  ('SN-KOLD-011', '2027-02-25', 'faible',  false, 'Reine absente, colonie à surveiller'),
  ('CI-KORH-003', '2027-03-05', 'forte',   true,  'Hausse posée'),
  ('CM-NGAO-005', '2027-03-08', 'moyenne', true,  'Présence de fourmis au pied')
) AS v(code, d, etat, reine, obs)
JOIN ruche r ON r.code = v.code;

-- 3 récoltes : une déclarée, deux validées par le coordinateur (avec la date)
INSERT INTO recolte (ruche_id, date_recolte, quantite_kg, statut, declaree_par, validee_par, date_validation)
SELECT r.id, v.d::date, v.q, v.statut,
       (SELECT u.id FROM utilisateur u WHERE u.apicultrice_id = r.apicultrice_id),
       CASE WHEN v.statut = 'validee' THEN (SELECT id FROM utilisateur WHERE login = 'm.ndiaye') END,
       v.dv::timestamptz
FROM (VALUES
  ('SN-CASA-021', '2027-03-01', 12.50, 'validee',  '2027-03-03 10:15+00'),
  ('SN-CASA-099', '2027-03-04',  8.20, 'validee',  '2027-03-06 16:40+00'),
  ('CI-KORH-003', '2027-03-12', 15.00, 'declaree', NULL)
) AS v(code, d, q, statut, dv)
JOIN ruche r ON r.code = v.code;

-- 4 alertes sur 4 ruches de 4 sites, dont 2 ouvertes (SN-CASA et CM-NGAO)
INSERT INTO alerte (ruche_id, type_alerte, date_alerte, niveau_confiance, statut)
SELECT r.id, v.t, v.d::timestamptz, v.conf, v.statut
FROM (VALUES
  ('SN-CASA-014', 'essaimage',          '2027-03-14 11:30+00', 0.82, 'ouverte'),
  ('CM-NGAO-017', 'vol',                '2027-03-14 03:00+00', 0.67, 'ouverte'),
  ('SN-KOLD-020', 'capteur_silencieux', '2027-03-12 08:00+00', 0.95, 'traitee'),
  ('CI-KORH-008', 'essaimage',          '2027-03-09 14:30+00', 0.55, 'traitee')
) AS v(code, t, d, conf, statut)
JOIN ruche r ON r.code = v.code;

COMMIT;
