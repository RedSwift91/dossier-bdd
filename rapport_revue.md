# Revue de sécurité de notre base - Groupe Killian Morvan

> **TP Jour 2 · Lab 10** · Fichiers liés : `recherche_vuln.py`, `recherche.py`, `corrections.sql`
> Correspondance avec le sujet : Fatou Ba = Awa Diop (`awa.diop`, ruche SN-CASA-030). Voir `matrice_droits.md`.
> Toutes les corrections sont dans `corrections.sql`, appliquées puis retestées. La base se reconstruit avec nos fichiers (C12).

## Synthèse

Constats : 2 critiques (P2, P3), 3 hautes (P1, R1, R4), 2 moyennes (R2, R5), 1 basse (R3). **8 constats, 8 corrigés.**
Contrôles passés : **12 / 12** (C1 et C12 après correction de R2 et R3).

## Failles démontrées (étapes 10.1 et 10.2)

| ID | Faille | Preuve | Correction | Retest |
|----|--------|--------|------------|--------|
| P1 | injection par le tri | `recherche_vuln.py`, site `SN-CASA` : (a) par erreur, tri `cast((SELECT telephone FROM apicultrice WHERE nom = 'Awa Diop') AS int)` donne `syntaxe en entrée invalide pour le type integer : « +221 77 000 01 02 »` ; (b) à l'aveugle, `CASE WHEN (SELECT substr(telephone, 6, 2) ...) = '77' THEN code ELSE longitude::text END` donne l'ordre 014, 021, 030, 099, et avec `'78'` l'ordre 021, 014, 099, 030 : l'ordre répond ; (c) empilée, `code; DROP TABLE journal_audit` donne `ne peut pas insérer les commandes multiples dans une instruction préparée` | `recherche.py` : une liste blanche, `sql.Identifier`, et l'erreur de la base n'est plus affichée | l'attaque (a) donne `Tri refusé : choisissez code ou date_installation` ✅ ; le tri `date_installation` marche ✅ |
| P2 | vue `v_carte_ruches` trop large | en `awa.diop` : `apicultrice` refusée, mais la vue montre **11 ruches avec 8 noms et téléphones** | `corrections.sql` : la vue est réécrite (ses ruches seulement, sans nom ni téléphone) et passe en `security_barrier` | même session : 1 ligne (SN-CASA-030), sans téléphone ✅ |
| P3 | fuite par fonction espion | en `awa.diop`, `pg_temp.espion(code, latitude, longitude)` (COST minimal) sur `v_mes_ruches` : le résultat n'a qu'une ligne, mais **11 NOTICE** donnent le GPS des 11 ruches | `security_barrier` sur les 7 vues filtrantes ; `REVOKE TEMPORARY ON DATABASE queenbee FROM PUBLIC` | même session : 1 NOTICE (sa ruche) ✅ ; nouvelle session : `droit refusé pour la création de tables temporaires` ✅ |

## Grille

| N° | Contrôle | Résultat | Verdict |
|----|----------|----------|---------|
| C1 | aucune fonction exécutable par PUBLIC | 0 ligne. **Mais** une fonction créée ensuite (`f_test`, dans une transaction annulée) est exécutable par PUBLIC : voir R2 | ✅ avec un constat |
| C2 | `search_path` fixé dans toute fonction SECURITY DEFINER | `valider_recolte`, `audit_ligne`, `utilisateur_courant` : `search_path=public, pg_temp` | ✅ |
| C3 | les vues filtrantes sont des barrières | les 7 vues filtrantes ont `security_barrier=true`. Les exceptions sont expliquées : `v_export_bailleur` et `synthese_site_jour` ne filtrent pas par utilisateur et sont données au seul gestionnaire ; `v_ruche_coordinateur` (jour 1) n'est donnée à personne | ✅ (R4) |
| C4 | aucune vue ne montre de données hors périmètre | en `awa.diop` : `v_moi` 1, `v_mes_ruches` 1, `v_mes_mesures` 4 368 (sa ruche seule), `v_mes_recoltes` 2, `v_carte_ruches` 1 ; les autres vues sont refusées | ✅ |
| C5 | le journal est en ajout seul | UPDATE, DELETE et TRUNCATE sont refusés, il reste 6 lignes | ✅ |
| C6 | le journal nomme le vrai acteur | `admin.beeafrica \| utilisateur \| UPDATE` | ✅ |
| C7 | une apicultrice n'écrit pas chez une autre | `la nouvelle ligne viole la contrainte de vérification pour la vue « v_mes_recoltes »` | ✅ |
| C8 | un jeton ne sert qu'une fois | `course_jeton.py RT-awa.diop-20` (version vulnérable) : 1 session, et l'autre requête reçoit `duplicate key` | ✅ |
| C9 | pas de requête construite par `+` ou `f"` | seulement dans `query_vuln.py` et `recherche_vuln.py`, des démonstrations **volontairement** vulnérables ; aucune dans le code utilisé | ✅ (à discuter) |
| C10 | les preuves ne partent pas en cascade | `mesure`, `inspection`, `recolte`, `alerte` sont en RESTRICT (`r`) | ✅ |
| C11 | pas de mot de passe dans le dépôt | `git grep -i password` ne trouve que 2 commentaires, aucun secret ; les rôles de test n'ont pas de mot de passe | ✅ |
| C12 | la base se reconstruit avec nos fichiers | base vide `queenbee_rebuild`, en suivant `jour2/README.md` : les 8 fichiers du jour 2 passent sans aucune ERROR ; `tests_contournement.sql` donne les mêmes 12 résultats. Avant R3, `roles.sql` rejoué dans cette base fermait... la base `queenbee` (nom écrit en dur) | ✅ (après R3) |

## Constats de la grille

| ID | Contrôle | Gravité | Constat | Preuve (commande et résultat) | Correction | Retest |
|----|----------|---------|---------|-------------------------------|------------|--------|
| R1 | C9 / moindre privilège | haute | les scripts Python se connectent en `postgres`, un superutilisateur : l'injection P1 lisait donc toute la base | `recherche_vuln.py` avec `PGUSER=postgres` : le téléphone d'Awa Diop apparaît dans l'erreur (P1) | compte applicatif `qb_recherche`, avec un seul droit : `SELECT (code, date_installation, site_id) ON ruche` | `SET ROLE qb_recherche;` la recherche normale donne les 4 ruches ✅ ; l'attaque `ORDER BY cast((SELECT telephone FROM apicultrice ...) AS int)` donne `droit refusé pour la table apicultrice` ✅. Il reste à lui donner un mot de passe hors du dépôt (voir README) |
| R2 | C1 | moyenne | une fonction créée **après** `roles.sql` est exécutable par PUBLIC (privilège par défaut de PostgreSQL) | `BEGIN; CREATE FUNCTION public.f_test() ...;` puis la requête C1 : `f_test()` (1 ligne) ; `ROLLBACK` | `ALTER DEFAULT PRIVILEGES FOR ROLE postgres REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;` | la même preuve : 0 ligne ✅ |
| R3 | C12 | basse | `roles.sql` et `corrections.sql` écrivaient le nom `queenbee` en dur : rejoués dans une autre base, ils fermaient la mauvaise | `REVOKE CONNECT ON DATABASE queenbee` dans le fichier | `EXECUTE format('... ON DATABASE %I ...', current_database())` | `datacl` de `queenbee` : plus de `PUBLIC` (ni `c`, ni `T`), les 4 groupes et `qb_recherche` en `c` ✅ ; la reconstruction C12 passe |
| R4 | revue BCNF (6.4) | haute | rien ne garantissait que les ruches d'une apicultrice sont sur son site : `ruche.site_id` pouvait diverger, et le mauvais coordinateur aurait validé ses récoltes | `UPDATE ruche SET site_id = 'SN-KOLD' WHERE code = 'SN-CASA-030';` était accepté | `UNIQUE (id, site_id)` sur `apicultrice`, et la clé étrangère composée `ruche_apicultrice_site_fk (apicultrice_id, site_id)` | le même `UPDATE` : `viole la contrainte de clé étrangère « ruche_apicultrice_site_fk »` ✅ |
| R5 | C4 (étendu aux autres rôles) | moyenne | le gestionnaire ne pouvait **pas** lire `v_export_bailleur` : la matrice (UC-G02) n'était pas respectée. Une fonction appelée dans une vue est vérifiée avec les droits de celui qui lit, et `roles.sql` avait retiré `hmac()` à PUBLIC. Trouvé en préparant les captures : C4 n'avait été passé qu'en apicultrice | `SET ROLE "gest.beeafrica"; SELECT * FROM v_export_bailleur;` donne `droit refusé pour la fonction hmac` | `GRANT EXECUTE ON FUNCTION hmac(text, text, text) TO qb_gestionnaire;` (dans `roles.sql`) | export lu : 8 lignes ✅ ; `cle_pseudonymisation` toujours refusée ✅ ; coordinateur (4 ruches, 4 récoltes) et admin (11 comptes, journal) lisent bien leurs objets ✅ |

## Testez-vous · Lab 10

1. **Pourquoi `conn.execute("... ORDER BY %s", (tri,))` ne trie-t-il pas par la colonne choisie ?** Le `%s` envoie une **valeur** : `ORDER BY 'code'` trie par une chaîne constante, identique pour toutes les lignes. L'ordre reste celui du hasard. Un nom de colonne doit passer par `sql.Identifier`, choisi dans une liste blanche.
2. **L'injection empilée a échoué : `recherche_vuln.py` est-il sûr pour autant ?** **Non.** Une seule commande suffit : l'attaque par erreur a fait sortir le téléphone, et l'attaque à l'aveugle le reconstitue chiffre par chiffre. Seule l'attaque empilée est bloquée, par le protocole.
3. **`security_barrier` ou `security_invoker` ?** `security_barrier` : la vue garde les droits de son propriétaire, mais son filtre passe **avant** les conditions de l'utilisateur (plus de fonction espion). `security_invoker` : la vue s'exécute avec les droits de **celui qui la lit** (il lui faut alors les droits sur les tables, ou la sécurité au niveau des lignes).
4. **Classez par gravité.** La vue `v_carte_ruches` d'origine est **critique** (fuite des téléphones et du GPS de toutes les apicultrices). Une fonction SECURITY DEFINER sans `search_path` est **haute** (on peut faire exécuter son propre code avec les droits du propriétaire). Un README absent est **basse** (une bonne pratique).
