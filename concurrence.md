# Transactions et concurrence - Groupe Killian Morvan

> **TP Jour 2 · Lab 9 · Étapes 9.1 à 9.4**
> Fichiers liés : `jeton.sql`, `course_jeton.py`, `course_jeton_corrige.py`
> Adaptation : `f.ba` du sujet = `awa.diop`, donc les jetons sont `RT-awa.diop-1` à `RT-awa.diop-30` ; la récolte de l'étape 9.1 est une récolte **déclarée** par Awa Diop sur SN-CASA-030 (une récolte déjà validée ne montrerait rien).

## Sommaire

1. [L'action et sa trace ensemble](#91--laction-et-sa-trace-ensemble)
2. [La course au jeton, dans deux terminaux](#92--la-course-au-jeton-dans-deux-terminaux)
3. [La course par un programme](#93--la-course-par-un-programme)
4. [Les quatre corrections](#94--les-quatre-corrections)
5. [Testez-vous](#testez-vous--lab-9)

---

## 9.1 · L'action et sa trace ensemble

### La trace qui ment

L'application écrit d'abord dans sa table temporaire `journal_appli`, puis valide sans `validee_par` :

```text
INSERT 0 1
ERREUR:  la nouvelle ligne de la relation « recolte » viole la contrainte de vérification « recolte_validation_tracee »

                 message
------------------------------------------
 récolte SN-CASA-030 validée par m.ndiaye        <- le journal de l'application affirme la validation

  statut
----------
 declaree                                         <- la base, elle, l'a refusée
```

> ❌ **La trace ment** : elle dit « fait », la base dit « pas fait ».

### La transaction : tout ou rien

| Étape | `count(*)` de `journal_audit` |
|---|---|
| avant | 6 |
| `BEGIN;` puis validation complète (`validee_par`, `date_validation`) : `UPDATE 1` | **7** (+1 : l'action et sa trace partent ensemble) |
| `SELECT 1 / 0;` | `ERREUR: division par zéro` |
| nouveau comptage | `ERREUR: la transaction est annulée, les commandes sont ignorées jusqu'à la fin du bloc de la transaction` (*current transaction is aborted*) |
| `ROLLBACK;` puis comptage | **6** ✅, et la récolte est de nouveau `declaree` |

## 9.2 · La course au jeton, dans deux terminaux

Deux sessions `psql` ouvertes en même temps sur `queenbee`, jeton `RT-awa.diop-1`, isolation par défaut (READ COMMITTED) :

| Temps | Terminal A | Terminal B |
|---|---|---|
| T1 | `BEGIN;` -> BEGIN | |
| T2 | | `BEGIN;` -> BEGIN |
| T3 | `SELECT id, utilise_le ...` -> 1 ligne, **utilise_le vide** | |
| T4 | | `SELECT id, utilise_le ...` -> 1 ligne, **utilise_le vide** |
| T5 | `UPDATE jeton SET utilise_le = now() ...` -> UPDATE 1 | |
| T6 | `INSERT INTO session_app ...` -> INSERT 0 1 | |
| T7 | `COMMIT;` | |
| T8 | | `UPDATE jeton SET utilise_le = now() ...` -> **UPDATE 1** |
| T9 | | `INSERT INTO session_app ...` -> **INSERT 0 1** |
| T10 | | `COMMIT;` |

**Sessions ouvertes avec ce jeton : 2** ❌. Les deux ont vérifié (T3, T4) avant que l'une n'agisse (T5).

## 9.3 · La course par un programme

| Programme | Jeton | Résultat |
|---|---|---|
| `course_jeton.py` (vérifier, puis agir) | RT-awa.diop-10 | requête 1 acceptée, requête 2 acceptée -> **2 sessions** ❌ |
| `course_jeton.py` | RT-awa.diop-11 | acceptée, acceptée -> **2 sessions** ❌ |
| `course_jeton_corrige.py` (`UPDATE ... RETURNING`) | RT-awa.diop-12 | une acceptée, une refusée (« jeton déjà utilisé ou expiré ») -> **1 session** ✅ |
| `course_jeton_corrige.py` | RT-awa.diop-13 | une acceptée, une refusée -> **1 session** ✅ |

Avec `time.sleep(0.2)`, la course est gagnée à chaque fois : inutile de passer à 0.5.

## 9.4 · Les quatre corrections

| Correction | Jeton | Ce qui s'est passé | Sessions |
|---|---|---|---|
| **1.** `SELECT ... FOR UPDATE` dans les deux terminaux | RT-awa.diop-2 | au T4, **B se fige** ; dès que A fait `COMMIT`, B reçoit la ligne avec `utilise_le` **rempli** ; `ROLLBACK` dans B | 1 ✅ |
| **2.** une seule instruction `UPDATE ... WHERE utilise_le IS NULL ... RETURNING id` | RT-awa.diop-3 | A reçoit un `id` ; B attend, puis reçoit **UPDATE 0** (0 ligne) | 1 ✅ |
| **3.** `UNIQUE (jeton_id)` sur `session_app` | RT-awa.diop-14 | d'abord **refusée** (`n'a pas pu créer l'index unique « session_jeton_unique »`, doublons de RT-awa.diop-1, -10, -11) ; `DELETE 3` en gardant la plus ancienne session ; posée ; puis `course_jeton.py` (vulnérable !) : un clic accepté, l'autre `la valeur d'une clé dupliquée rompt la contrainte unique « session_jeton_unique »` | 1 ✅ |
| **4.** `BEGIN ISOLATION LEVEL REPEATABLE READ;` sans `FOR UPDATE` | RT-awa.diop-4 | l'`UPDATE` de B attend, puis échoue : `n'a pas pu sérialiser un accès à cause d'une mise à jour en parallèle` (*could not serialize access due to concurrent update*) | 1 ✅ |

La contrainte est ajoutée à la fin de `jeton.sql`.

### Comparaison

| Correction | Où agit-elle ? | Que voit la seconde requête ? | Avantage | Limite |
|---|---|---|---|---|
| `SELECT ... FOR UPDATE` | dans le code : un verrou sur la ligne lue | elle **attend**, puis lit la ligne à jour (`utilise_le` rempli) | simple à ajouter à un code existant | il faut ne l'oublier dans **aucun** programme ; les requêtes en attente ralentissent, risque d'interblocage |
| `UPDATE ... WHERE ... RETURNING` | dans le code : une seule instruction qui vérifie et agit | elle attend, puis **0 ligne** (condition réévaluée) | sûr sans verrou explicite, une seule requête, le plus rapide | là encore, chaque programme doit l'écrire ainsi |
| `UNIQUE (jeton_id)` | **dans la base** | une **erreur** `duplicate key` à l'insertion | protège même le code vulnérable, et tous les clients | ne protège que ce qu'on sait écrire en contrainte ; l'erreur doit être gérée proprement |
| `REPEATABLE READ` | dans la transaction (niveau d'isolation) | une **erreur** de sérialisation | protège sans changer les requêtes | l'application doit annuler et **réessayer** ; plus d'échecs sous forte charge |

> **La meilleure défense combine les deux niveaux :** l'`UPDATE ... RETURNING` dans le code, **et** la contrainte `UNIQUE` dans la base, qui tient même si un programme l'oublie.

### Le trigger du lab 6 est aussi un « vérifier, puis agir »

**Deux insertions simultanées peuvent-elles le contourner ? Oui, et on l'a vérifié :**

| Temps | A | B |
|---|---|---|
| T1/T2 | `BEGIN;` | `BEGIN;` |
| T3 | Fatou Sow chez Moussa Sarr (varroa) -> **INSERT 0 1** | |
| T4 | | Fatou Sow chez Ibrahima Fall (varroa) -> **INSERT 0 1** |
| T5/T6 | `COMMIT;` | `COMMIT;` |

Résultat : `Fatou Sow | varroa | {Ibrahima Fall, Moussa Sarr}` ❌ (puis les deux lignes ont été supprimées). Chaque trigger a cherché « un autre formateur pour ce thème », mais la ligne de l'autre transaction n'était pas encore validée, donc invisible.

**Quelle correction le protégerait ?** Une **contrainte**, comme pour le jeton : recopier `theme` dans `suivi_formation` avec `UNIQUE (apicultrice_id, theme)` et la clé étrangère composée `(formateur_id, theme) REFERENCES formateur (id, theme)` (le « pour aller plus loin » du lab 6). L'index unique, lui, voit les insertions non validées : B attend A, puis reçoit `duplicate key`. Autres solutions : un verrou dans le trigger (`SELECT ... FROM apicultrice WHERE id = NEW.apicultrice_id FOR UPDATE`) ou l'isolation `SERIALIZABLE`.

---

## Testez-vous · Lab 9

1. **Pourquoi l'invite devient-elle `queenbee=!#` après une erreur dans une transaction ? Que faut-il taper ?**
   La transaction est **annulée** : PostgreSQL refuse toute commande jusqu'à la fin du bloc, pour ne pas valider une moitié de travail. Il faut taper `ROLLBACK;` (un `COMMIT;` ferait d'ailleurs un rollback).
2. **Pourquoi READ COMMITTED ne protège-t-il pas de la course au jeton ?**
   Chaque instruction voit les données validées **au moment où elle démarre**. Les deux `SELECT` voient le jeton libre, puisque personne n'a encore validé ; l'`UPDATE` de B, sans condition sur `utilise_le`, réussit ensuite. Rien ne relie la vérification à l'action.
3. **Pourquoi `UPDATE ... WHERE utilise_le IS NULL RETURNING id` est-il sûr, sans verrou explicite ?**
   L'`UPDATE` verrouille la ligne qu'il modifie : la seconde requête attend la fin de la première, puis PostgreSQL **réévalue la condition** sur la ligne à jour. `utilise_le` n'est plus vide : 0 ligne. La vérification et l'action sont une seule opération atomique.
4. **Un rançongiciel chiffre le serveur. ACID vous protège-t-il ? Qu'est-ce qui vous protège ?**
   **Non.** ACID (la durabilité) protège d'une panne, pas d'un attaquant qui chiffre les fichiers, ni d'une erreur validée. Ce qui protège : des **sauvegardes** régulières, **testées** (restaurées), gardées **hors ligne** ou immuables, hors de portée du serveur, avec leur empreinte pour prouver qu'elles sont intactes (voir `durabilite.md`).
