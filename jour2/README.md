# Queen Bee - Dossier de conception, jour 2 - Groupe Killian Morvan

> TP Jour 2 · M1 Cyber · Labs 6 à 10
> Le sujet est écrit pour un autre jeu d'essai : nous gardons **notre** base du jour 1 et remplaçons chaque élément cité par son équivalent (Fatou Ba = Awa Diop, `f.ba` = `awa.diop`, `coord.sn` = `m.ndiaye`...). Correspondance complète : `1_schema_normalise/normalisation_j2.md` et `2_roles_privileges/matrice_droits.md`.

## Les 5 parties

1. **Schéma normalisé** : `1_schema_normalise/` (BCNF des formations et trigger, synthèse, export pseudonymisé, journal, ON DELETE, CHECK ; schéma complet exporté dans `schema_j2.sql`)
2. **Rôles et privilèges** : `2_roles_privileges/` (4 rôles, 8 vues, 1 fonction de validation ; 12 tests de contournement)
3. **Trigger d'audit** : `3_trigger_audit/` (tables auditées : `recolte`, `utilisateur` ; journal en ajout seul)
4. **Test de concurrence** : `4_test_concurrence/` (2 sessions avant, 1 après ; sauvegarde restaurée, empreinte `OK`)
5. **Revue de sécurité** : `5_revue_securite/` (8 constats, 8 corrigés : P1 à P3, R1 à R5)

Les 8 vues : `v_moi`, `v_mes_ruches`, `v_mes_mesures`, `v_mes_recoltes`, `v_carte_ruches` (apicultrice) ; `v_ruches_site`, `v_recoltes_site` (coordinateur) ; `v_export_bailleur` (gestionnaire, avec la vue matérialisée `synthese_site_jour`).

## Reconstruire (après la base du jour 1, avec -v ON_ERROR_STOP=1)

Base du jour 1, depuis `dossier-bdd` : `schema.sql`, `donnees.sql`, `plat.sql`, puis `contraintes.sql` **sans** `ON_ERROR_STOP` (il pose l'unicité des logins du lab 4, et contient exactement 2 refus voulus : `utilisateur_login_unique` avant nettoyage, `utilisateur_login_ci` pour `Awa.Diop`).

Puis, depuis `dossier-bdd/jour2` :

1. `1_schema_normalise/formation.sql`
2. `1_schema_normalise/volume.sql` (une fois)
3. `1_schema_normalise/denormalisation.sql`
4. `1_schema_normalise/references.sql` puis `1_schema_normalise/check.sql`
5. `3_trigger_audit/audit.sql`
6. `2_roles_privileges/roles.sql`
7. `4_test_concurrence/jeton.sql`
8. `5_revue_securite/corrections.sql`

```bash
psql -U postgres -d postgres -c "CREATE DATABASE queenbee_rebuild"
psql -U postgres -d queenbee_rebuild -v ON_ERROR_STOP=1 -f schema.sql
psql -U postgres -d queenbee_rebuild -v ON_ERROR_STOP=1 -f donnees.sql
psql -U postgres -d queenbee_rebuild -v ON_ERROR_STOP=1 -f plat.sql
psql -U postgres -d queenbee_rebuild -f contraintes.sql
psql -U postgres -d queenbee_rebuild -v ON_ERROR_STOP=1 -f jour2/1_schema_normalise/formation.sql
# ... et ainsi de suite, dans l'ordre ci-dessus
psql -U postgres -d queenbee_rebuild -f jour2/2_roles_privileges/tests_contournement.sql
```

Aucun mot de passe n'est écrit dans ces fichiers : la connexion se fait avec `pgpass.conf`, et les rôles de test sont essayés par `SET ROLE`.

## Nos choix principaux

- **BCNF + trigger pour les formations**, parce que la table reçue (3NF) laissait un formateur enseigner deux thèmes sans un message. La règle perdue est rétablie par un trigger, qu'on sait contournable par deux insertions simultanées (démontré dans `concurrence.md`) : une contrainte composée serait plus sûre.
- **La synthèse est rafraîchie toutes les nuits** (`REFRESH MATERIALIZED VIEW CONCURRENTLY`), donc avec jusqu'à 24 h de retard. **Le vol est détecté sur les mesures brutes**, jamais sur la synthèse.
- **L'export du bailleur** : un HMAC à clé secrète (pas un haché simple, cassé en moins d'une seconde), positions arrondies à ~11 km, ni nom, ni téléphone, ni code de ruche.
- **Personne n'a de droit sur les tables métier** : tout passe par des vues `security_barrier` filtrées sur `qui()`, ou par `valider_recolte()` (`SECURITY DEFINER`, `search_path` fixé). Les preuves (mesures, inspections, récoltes, alertes) sont en `ON DELETE RESTRICT`.
- **Un jeton ne sert qu'une fois**, deux fois protégé : `UPDATE ... RETURNING` dans le code, `UNIQUE (jeton_id)` dans la base.

## Limites connues

- Un superutilisateur peut désactiver les triggers du journal (`ALTER TABLE journal_audit DISABLE TRIGGER ...` passe en `postgres`) : le journal doit aussi être **copié hors de la base, vers le SIEM**, et personne ne doit travailler au quotidien en superutilisateur.
- Le compte applicatif `qb_recherche` (constat R1) est créé sans mot de passe : pour que `recherche.py` s'y connecte vraiment, il faut lui en donner un (`\password qb_recherche`) et le mettre dans `pgpass.conf`, jamais dans le dépôt.
- `pg_dump` ne sauvegarde pas les rôles : il faut aussi `pg_dumpall --roles-only --no-role-passwords`.

## Test de reconstruction (étape 11.5)

Dans une base vide `queenbee_rebuild`, en suivant ce README : les 8 fichiers du jour 2 passent **sans aucune ERROR** (code de retour 0 pour chacun). Puis `tests_contournement.sql` donne les **mêmes 12 résultats** que sur la base de travail (les 10 refus, les 2 acceptations) ; le journal nomme `awa.diop` (INSERT) et `m.ndiaye` (UPDATE).
