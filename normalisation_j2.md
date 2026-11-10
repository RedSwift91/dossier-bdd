# Normalisation, jour 2 - Groupe Killian Morvan

> **TP Jour 2 · Labs 6 et 7**
> Fichiers liés : `formation.sql`, `volume.sql`, `denormalisation.sql`
> Base de départ : la base `queenbee` du jour 1 (`schema.sql`, `donnees.sql`, logins corrigés au lab 4)

## Sommaire

1. [Correspondance avec le sujet](#correspondance-avec-le-sujet)
2. [Lab 6 · Décomposer sans rien perdre](#lab-6--décomposer-sans-rien-perdre)
3. [Lab 7 · Dénormaliser, en connaissance de cause](#lab-7--dénormaliser-en-connaissance-de-cause)

---

## Correspondance avec le sujet

Le sujet est écrit pour un autre jeu d'essai que le nôtre. On garde **notre** base du jour 1 et on remplace chaque élément cité par son équivalent :

| Dans le sujet | Chez nous | Pourquoi celui-là |
|---|---|---|
| Fatou Ba, `+221 77 100 00 02`, `f.ba` | Awa Diop, `+221 77 000 01 02`, `awa.diop` | apicultrice de SN-CASA avec une seule ruche |
| sa ruche SN-CASA-013 | SN-CASA-030 | la seule ruche d'Awa Diop |
| les 6 téléphones de `formation_plat` | 6 téléphones de notre table `apicultrice` | sinon `suivi_formation` ne retrouve personne (le sujet dit : « corrigez la ligne ») |
| SN-CASA-011 (récolte de 12,5 kg, vol) | SN-CASA-021 | notre récolte de 12,50 kg |
| CI-MAN-012 | SN-KOLD-012 | une ruche qui n'a que des mesures (pas d'inspection, récolte ni alerte) |
| `volume_kg`, `validee_le` | `quantite_kg`, `date_validation` | noms de colonnes de notre `schema.sql` |

Les nombres attendus par le sujet (8 lignes, 16 lignes, 192 mesures par jour, 47 520 mesures, 8 lignes d'export...) sont **tous retrouvés** avec nos données.

---

# Lab 6 · Décomposer sans rien perdre

## 6.1 · Analyser la table reçue

`formation_plat (telephone, theme, formateur)`, clé primaire `(telephone, theme)`, 8 lignes : `CREATE TABLE`, puis `INSERT 0 8`.

### Les dépendances

| | DF | En français |
|---|---|---|
| **DF1** | `telephone, theme → formateur` | pour un thème, une apicultrice n'a qu'un formateur (celui qui signe l'attestation) |
| **DF2** | `formateur → theme` | un formateur n'enseigne qu'un thème |

Les trois tests `GROUP BY ... HAVING count(DISTINCT ...) > 1` donnent **0 ligne** chacun ✅ : DF1, DF2, et `telephone, formateur → theme`.

### Les clés candidates

| Clé | Pourquoi |
|---|---|
| **(telephone, theme)** | DF1 donne le formateur : les 3 colonnes |
| **(telephone, formateur)** | DF2 donne le thème : les 3 colonnes |

### 3NF ? BCNF ?

| Forme | Verdict | Justification |
|---|---|---|
| **3NF** | ✅ oui | les trois colonnes font partie d'une clé candidate : une DF qui aboutit à une colonne de clé ne viole pas la 3NF |
| **BCNF** | ❌ non | `formateur → theme` part de `formateur`, qui n'est pas une clé à lui seul |

### L'anomalie

Entre `BEGIN` et `ROLLBACK`, Moussa Sarr passe en `capteurs` sur la ligne de `+221 77 000 01 02` (Awa Diop). La table **accepte**, sans message :

```text
  formateur  |     array_agg
-------------+-------------------
 Moussa Sarr | {capteurs,varroa}
```

La règle `formateur → theme` est violée : la clé `(telephone, theme)` ne la protège pas.

## 6.2 · Découper, et prouver qu'on n'a rien perdu

### Le mauvais découpage : (telephone, theme) + (theme, formateur)

| Mesure | Obtenu |
|---|---|
| lignes de la jointure | **16** au lieu de 8 ❌ |
| lignes inventées (`EXCEPT`) | **8** |
| exemple | Awa Diop (`+221 77 000 01 02`) serait suivie par **trois formateurs varroa** : Moussa Sarr, Ibrahima Fall, Kouassi Yao |

**Pourquoi :** la colonne commune, `theme`, n'est la clé d'**aucun** des deux morceaux (le thème varroa a trois formateurs). La jointure associe donc chaque apicultrice à tous les formateurs du thème.

### Le bon découpage : formateur + suivi_formation

| Table | Clé | DF |
|---|---|---|
| `formateur (id, nom, theme)` | `id`, et `nom` **UNIQUE** | `nom → theme` |
| `suivi_formation (apicultrice_id, formateur_id)` | les deux colonnes | aucune autre |

| Étape | Obtenu |
|---|---|
| remplir `formateur` | `INSERT 0 5` ✅ |
| remplir `suivi_formation` (apicultrice retrouvée par son téléphone) | `INSERT 0 8` ✅ |
| double `EXCEPT` (recomposition contre `formation_plat`) | **0 ligne** ✅ : rien de perdu, rien d'inventé |

- **Quelle contrainte garantit `formateur → theme` ?** La contrainte `UNIQUE` sur `formateur.nom` (`formateur_nom_key`) : un formateur n'a qu'**une** ligne, donc un seul thème. Le `CHECK` limite en plus le thème à varroa, recolte ou capteurs.
- **Pourquoi pointer vers `apicultrice(id)` au lieu de recopier le téléphone ?** Le téléphone est une donnée personnelle qui **change** (nouveau numéro) : recopié, il faudrait le corriger partout, et une copie oubliée ferait perdre le suivi. L'`id` ne change jamais, la clé étrangère garantit que l'apicultrice existe, et le téléphone reste écrit **une seule fois**, dans `apicultrice`.

## 6.3 · La règle perdue, et le trigger qui la rétablit

Après le découpage, plus aucune table ne contient à la fois l'apicultrice et le thème : la DF1 n'est plus vérifiée.

| Test | Obtenu |
|---|---|
| sans trigger : Awa Diop chez Ibrahima Fall (varroa, alors qu'elle a Moussa Sarr) | `INSERT 0 1` ❌ accepté |
| recherche des doublons | `Awa Diop \| varroa \| {"Moussa Sarr","Ibrahima Fall"}` (ligne ensuite supprimée) |

Avec le trigger `suivi_formation_df` (fonction `suivi_un_formateur_par_theme()`) :

| Insertion pour Awa Diop | Obtenu |
|---|---|
| chez Ibrahima Fall (varroa) | ❌ refusée |
| chez Khady Ndiaye (récolte, thème nouveau pour elle) | ✅ `INSERT 0 1` |

```text
ERREUR:  DF violée : cette apicultrice a déjà un formateur pour ce thème
CONTEXTE : fonction PL/pgSQL suivi_un_formateur_par_theme(), ligne 11 à RAISE
INSERT 0 1
```

### Pour aller plus loin : la même garantie sans trigger

On recopie `theme` dans `suivi_formation`, avec `UNIQUE (apicultrice_id, theme)` et une clé étrangère composée `(formateur_id, theme) REFERENCES formateur (id, theme)`.

- **Est-ce encore en BCNF ?** **Non.** Dans `suivi_formation`, `formateur_id → theme` part d'une colonne qui n'est pas une clé : c'est exactement la situation de `formation_plat`. La table est en **3NF** (le thème fait partie de la clé `(apicultrice_id, theme)`).
- **Mais la copie ne peut pas diverger :** la clé étrangère composée oblige le thème recopié à être celui du formateur. C'est une redondance **contrôlée par une contrainte**, qui résiste aux insertions simultanées (lab 9), ce que le trigger ne fait pas.

## 6.4 · Relire tout le schéma

| Table | Dépendances (chaque clé détermine tout) | Partie gauche = super-clé ? | BCNF ? |
|---|---|---|---|
| `site` | `id → nom, pays, localite` | ✅ | ✅ |
| `cooperative` | `id → nom, site_id` | ✅ | ✅ |
| `apicultrice` | `id → nom, telephone, site_id` | ✅ | ✅ (voir la remarque 1) |
| `ruche` | `id → tout` ; `code → tout` (UNIQUE) | ✅ | ✅ si l'on s'en tient aux clés (voir la remarque 2) |
| `adhesion` | `(apicultrice_id, cooperative_id) → date_adhesion` | ✅ | ✅ |
| `utilisateur` | `id → tout` ; `login → tout` (UNIQUE) ; `apicultrice_id → tout` (UNIQUE) | ✅ | ✅ (voir la remarque 2) |
| `mesure` | `id → tout` ; `(ruche_id, horodatage) → tout` (UNIQUE anti-rejeu) | ✅ | ✅ |
| `inspection` | `id → tout` | ✅ | ✅ |
| `recolte` | `id → tout` | ✅ | ✅ |
| `alerte` | `id → tout` | ✅ | ✅ |
| `formateur` | `id → tout` ; `nom → tout` (UNIQUE) | ✅ | ✅ |
| `suivi_formation` | aucune DF autre que la clé | ✅ | ✅ |
| `formation_plat` | `formateur → theme` | ❌ | ❌ (table d'import, laissée telle quelle comme preuve du fichier reçu) |

> **Remarque 1.** Le jour 1, `telephone → apicultrice` tenait dans les données, mais aucune contrainte `UNIQUE (telephone)` ne la garantit. Si deux apicultrices partagent un téléphone (un téléphone familial), `suivi_formation` ne saurait plus qui retrouver : c'est une règle métier à confirmer avant de l'imposer.

### Deux colonnes qui disent peut-être la même chose : `apicultrice.site_id` et `ruche.site_id`

```text
      nom       | site_apicultrice | sites_de_ses_ruches | coherent
----------------+------------------+---------------------+----------
 Adjoua Kouassi | CI-KORH          | {CI-KORH}           | t
 Mariam Kone    | CI-KORH          | {CI-KORH}           | t
 Clarisse Ngo   | CM-NGAO          | {CM-NGAO}           | t
 Hadja Bello    | CM-NGAO          | {CM-NGAO}           | t
 Aminata Diop   | SN-CASA          | {SN-CASA}           | t
 Awa Diop       | SN-CASA          | {SN-CASA}           | t
 Aminata Diop   | SN-KOLD          | {SN-KOLD}           | t
 Fatou Sow      | SN-KOLD          | {SN-KOLD}           | t
```

Chaque apicultrice n'a de ruches que sur son site ✅. Mais les données ne suffisent pas à trancher.

> **Remarque 2 : règle métier ou coïncidence ?** Le cahier des charges dit qu'une apicultrice « est rattachée à un site », et que le coordinateur valide les récoltes **de son site**. On en fait une **règle métier** : une apicultrice n'a de ruches que sur son site. Alors `ruche.site_id` est une **copie** de `apicultrice.site_id`, et `ruche.apicultrice_id → ruche.site_id` est une DF qui ne part pas d'une clé : `ruche` n'est pas vraiment en BCNF. De même, `utilisateur.site_id` recopie le site de l'apicultrice.
>
> **Qu'est-ce qui garantit la cohérence dans notre schéma ? Rien, au départ.** Une ruche pourrait être déplacée sur SN-KOLD tout en restant à une apicultrice de SN-CASA : le coordinateur de SN-KOLD validerait alors ses récoltes, celui de SN-CASA ne les verrait plus. On garde la colonne (elle sert à toutes les requêtes par site), mais on la **contrôle** par une clé étrangère composée `(apicultrice_id, site_id) REFERENCES apicultrice (id, site_id)`. Correction prévue lors de la revue de sécurité.

## Testez-vous · Lab 6

1. **R(A, B, C) avec A → B. (A, B) + (A, C) est-il sans perte ? Et (A, B) + (B, C) ?**
   (A, B) + (A, C) : **oui**, la colonne commune A est la clé de (A, B). (A, B) + (B, C) : **pas garanti**, la colonne commune B n'est la clé d'aucun morceau (il faudrait B → C) : la jointure peut inventer des lignes.
2. **Pourquoi `formation_plat` est-elle en 3NF, alors que `formateur → theme` ne part pas d'une clé ?**
   La 3NF tolère une DF X → A quand A fait partie d'une clé candidate. `theme` fait partie de la clé (telephone, theme). La BCNF, elle, ne tolère rien : toute partie gauche doit être une super-clé.
3. **Pourquoi le trigger a-t-il besoin de `s.formateur_id <> NEW.formateur_id` ?**
   Sans elle, la ligne cherchée peut être **la même** que celle qu'on écrit : lors d'un `UPDATE` (la ligne est encore dans la table) ou d'un doublon exact, le trigger trouverait « un formateur pour ce thème »... qui est le même, et refuserait à tort. On ne cherche qu'un **autre** formateur.
4. **Un avantage et un inconvénient de rester en 3NF plutôt que de passer en BCNF ?**
   Avantage : toutes les DF restent garanties par des clés, sans trigger (qui peut être contourné par deux insertions simultanées). Inconvénient : la redondance reste (`formateur → theme` recopié), d'où l'anomalie de mise à jour de l'étape 6.1.

---

# Lab 7 · Dénormaliser, en connaissance de cause

## 7.1 · Mesurer avant de copier

`volume.sql` ajoute 90 jours de mesures (du 2026-12-14 au 2027-03-13, juste avant le jeu d'essai du 2027-03-14) : **`INSERT 0 47520`** ✅ (11 ruches × 4 320). Lancé une seule fois : relancé, il serait refusé par `mesure_anti_rejeu`.

Le tableau de bord du gestionnaire (UC-G01), SN-CASA, les 3 derniers jours :

| jour | nb_mesures | poids_moyen | poids_min | batterie_min |
|---|---|---|---|---|
| 2027-03-14 | 192 | 37.51 | 30.06 | 53 |
| 2027-03-13 | 192 | 32.54 | 30.09 | 90 |
| 2027-03-12 | 192 | 32.54 | 30.01 | 90 |

192 mesures par jour = 4 ruches × 48 ✅. **Execution Time : 6,826 ms** (lecture de toute la table `mesure`, 48 048 lignes, *Seq Scan*).

## 7.2 · La synthèse, et son prix

| Lecture | Plan | Execution Time |
|---|---|---|
| requête sur `mesure` (7.1) | Seq Scan sur 48 048 mesures + Hash Join | **6,826 ms** |
| vue matérialisée `synthese_site_jour` | Bitmap Index Scan sur `synthese_site_jour_pk` | **0,110 ms** ✅ (60 fois moins) |

Les chiffres sont les mêmes.

### Le vol invisible

Le 15 mars à 6 h, la ruche SN-CASA-021 passe à **8,40 kg** (25 kg de moins : un vol, UC-CY04).

| Moment | Ce que montre la synthèse pour SN-CASA |
|---|---|
| après l'`INSERT`, avant le rafraîchissement | 2027-03-14 et avant : **rien d'anormal** |
| après `REFRESH MATERIALIZED VIEW CONCURRENTLY` | **2027-03-15 \| 1 mesure \| poids_min = 8.40** |

- **Si la vue n'est rafraîchie que la nuit, combien de temps le vol reste-t-il invisible ?** Jusqu'au prochain rafraîchissement : un vol à 6 h n'apparaît que la nuit suivante, soit **près de 24 h** au pire. Largement le temps d'emporter la ruche.
- **Où détecter un vol ?** Sur les **mesures brutes**, à leur arrivée (une requête ou un trigger sur `mesure` qui compare au poids précédent et crée une `alerte`). La synthèse sert au pilotage, jamais à la sécurité.

## 7.3 · L'export pour le bailleur

### Un haché simple se casse

`sha256('+221 77 000 01 02')` = `f7bda31fa5df1fde3bd29cc7a93d88ccd1b9b1e5de6a5a6af5cd1d866827c7b5`

En essayant le million de numéros qui commencent par `+221 77 0`, la base retrouve **`+221 77 000 01 02`** en **941 ms** (`\timing on`). Un haché sans clé ne protège rien : l'espace des téléphones est trop petit.

### Le bon export : `v_export_bailleur`

Pseudonyme = HMAC-SHA256 de l'`id` de l'apicultrice avec une clé secrète de 32 octets aléatoires, gardée dans `cle_pseudonymisation` (une seule ligne, `REVOKE ALL ... FROM PUBLIC`).

```text
 apicultrice_pseudo |     pays      | site_id | latitude | longitude | recolte_validee_kg
--------------------+---------------+---------+----------+-----------+--------------------
 389992473206       | Cameroun      | CM-NGAO |      7.3 |      13.6 |                  0
 bf5f86ca44a6       | Cameroun      | CM-NGAO |      7.3 |      13.6 |                  0
 9daa00d7e1cc       | Côte d'Ivoire | CI-KORH |      9.5 |      -5.6 |                  0
 cbcfeaf1d2e4       | Côte d'Ivoire | CI-KORH |      9.5 |      -5.6 |                  0
 5bae0561b18b       | Sénégal       | SN-CASA |     12.6 |     -16.3 |              20.70
 d7179118ac6b       | Sénégal       | SN-CASA |     12.6 |     -16.3 |                  0
 c7a9cfea08b6       | Sénégal       | SN-KOLD |     12.9 |     -15.0 |                  0
 f5b04c2d9df8       | Sénégal       | SN-KOLD |     12.9 |     -14.9 |                  0
```

**8 lignes pour 11 ruches** ✅ (les ruches proches d'une même apicultrice se regroupent), sans nom ni téléphone. La clé est-elle écrite dans la définition de la vue ? **`f`** ✅ (la vue lit la table, elle ne contient pas la clé).

### Les colonnes retirées

| Colonne retirée | Pourquoi |
|---|---|
| `apicultrice.nom` | identifie directement la personne |
| `apicultrice.telephone` | identifie **et** permet de la contacter (ou de l'hameçonner) |
| `apicultrice.id` | stable et présent partout dans la base : remplacé par un HMAC, illisible sans la clé |
| `ruche.code` | relie la ligne à une ruche précise, donc à son apicultrice |
| `latitude`, `longitude` à 5 décimales (~1 m) | mènent à la ruche, et souvent au domicile : risque de vol. Arrondies à 0,1° (~11 km) |
| `date_installation`, détail des mesures, dates des récoltes | inutiles au bailleur, et chaque détail en plus aide à ré-identifier par recoupement |

## 7.4 · Le journal d'audit, une copie voulue

`denormalisation.sql` a été relancé deux fois sans erreur. Le journal et la clé sont créés avec `IF NOT EXISTS` : les relancer **n'efface pas** les preuves, et **ne change pas** la clé (sinon tous les pseudonymes déjà transmis changeraient).

1. **Pourquoi `ligne_id` n'est-il pas une clé étrangère vers la récolte ?** Une clé étrangère empêcherait de supprimer la récolte (RESTRICT), ou effacerait la trace avec elle (CASCADE). Or le journal doit justement **survivre** à la suppression : c'est là qu'il sert de preuve. Et le même journal surveille plusieurs tables (`recolte`, `utilisateur`) : une seule colonne ne peut pas pointer vers toutes.
2. **`avant` et `apres` recopient des lignes entières : est-ce acceptable ?** Oui : c'est une copie **voulue**, figée, jamais modifiée (ajout seul), qui montre la ligne **telle qu'elle était à ce moment**. La normalisation évite les copies qui peuvent diverger ; une photo datée ne diverge pas. Le prix : le journal contient des données personnelles, d'où l'accès réservé à l'admin et une durée de conservation à fixer.
3. **Pourquoi `clock_timestamp()` et pas `now()` ?** Dans une transaction, `now()` donne l'heure du **début** de la transaction : toutes les actions d'une longue transaction auraient la même heure, et l'ordre réel serait perdu. `clock_timestamp()` donne l'heure **réelle** de chaque écriture.

## Testez-vous · Lab 7

1. **Vue ou vue matérialisée ?** Une vue est une requête enregistrée, recalculée à chaque lecture : toujours à jour, mais lente. Une vue matérialisée stocke son résultat : rapide, mais **en retard** jusqu'au prochain `REFRESH`.
2. **`md5(nom)` comme pseudonyme : deux raisons de refuser.** (a) Sans clé, il se casse par dictionnaire : il suffit de hacher la liste des noms de la région. (b) Le nom n'identifie pas : les deux Aminata Diop auraient le **même** pseudonyme et seraient fusionnées. (En plus, md5 est cassé.)
3. **`v_export_bailleur` est-elle soumise au RGPD ?** **Oui.** Des données pseudonymisées restent des données personnelles : celui qui a la clé peut retrouver la personne, et le recoupement (un site, une zone de 11 km, un total de récolte) peut suffire à la reconnaître dans un petit village.
4. **Pourquoi le journal n'a-t-il pas de clé étrangère vers la table surveillée ?** Pour qu'il survive à la suppression de la ligne (ni blocage, ni effacement en cascade de la preuve), et parce qu'il surveille plusieurs tables.
