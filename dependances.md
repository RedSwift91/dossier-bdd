# Dépendances fonctionnelles - Groupe Killian Morvan

> **TP Jour 1 · Lab 4 · Livrable 3 (partie 1)**
> Table étudiée : `extrait_plat` (créée par `plat.sql`), **528 lignes**, une par mesure
> Fichiers liés : `plat.sql`, `contraintes.sql`

Les 10 colonnes de `extrait_plat` :

| ruche_code | site_id | site_nom | pays | apicultrice | telephone | cooperative | horodatage | poids_kg | temp_int_c |
|---|---|---|---|---|---|---|---|---|---|

## Sommaire

1. [Les DF de extrait_plat](#1-les-df-de-extrait_plat)
2. [Trois fermetures](#2-trois-fermetures)
3. [La clé candidate](#3-la-clé-candidate)
4. [Confrontation aux données](#4-confrontation-aux-données)
5. [Identifier par le nom ?](#5-et-si-lapplication-identifiait-les-apicultrices-par-leur-nom-)
6. [Testez-vous](#testez-vous--lab-4)

---

## 1. Les DF de extrait_plat

| | DF | En français |
|---|---|---|
| **DF1** | `site_id → site_nom, pays` | un site a un seul nom et un seul pays |
| **DF2** | `ruche_code → site_id, telephone` | une ruche est sur un seul site et a une seule apicultrice |
| **DF3** | `telephone → apicultrice, cooperative` | un téléphone désigne une seule apicultrice, et donc sa coopérative |
| **DF4** | `ruche_code, horodatage → poids_kg, temp_int_c` | une seule mesure par ruche et par instant |

> ⚠️ **DF3 dépend du jeu d'essai.** `telephone → cooperative` n'est vraie que parce que chaque apicultrice adhère ici à **une seule** coopérative. Le MCD en autorise plusieurs (1,n) : dès qu'une apicultrice en aura deux, cette DF tombera.

> ❌ **Pas de DF `apicultrice → telephone`** : le nom ne détermine pas la personne (voir la partie 4).

## 2. Trois fermetures

### {site_id}⁺

| Tour | DF utilisée | Colonnes obtenues |
|---|---|---|
| 0 | — | site_id |
| 1 | DF1 | + site_nom, pays |
| 2 | plus rien ne s'ajoute | |

**→ 3 colonnes sur 10 : pas une clé.**

### {ruche_code}⁺

| Tour | DF utilisée | Colonnes obtenues |
|---|---|---|
| 0 | — | ruche_code |
| 1 | DF2 | + site_id, telephone |
| 2 | DF1, DF3 | + site_nom, pays, apicultrice, cooperative |
| 3 | plus rien ne s'ajoute | |

**→ 7 colonnes sur 10 : pas une clé.** Il manque `horodatage`, `poids_kg` et `temp_int_c`, car une ruche a 48 mesures.

### {ruche_code, horodatage}⁺

| Tour | DF utilisée | Colonnes obtenues |
|---|---|---|
| 0 | — | ruche_code, horodatage |
| 1 | DF4, DF2 | + poids_kg, temp_int_c, site_id, telephone |
| 2 | DF1, DF3 | + site_nom, pays, apicultrice, cooperative |
| 3 | plus rien ne s'ajoute | |

**→ 10 colonnes sur 10 : c'est une clé. ✅**

## 3. La clé candidate

> **Clé candidate : {ruche_code, horodatage}**

On ne peut rien en retirer :

| Si on retire... | Il reste | Fermeture | Clé ? |
|---|---|---|---|
| `horodatage` | {ruche_code} | 7 colonnes sur 10 (48 lignes par ruche) | ❌ |
| `ruche_code` | {horodatage} | 1 colonne sur 10 (11 ruches mesurent au même instant) | ❌ |

C'est la **seule** clé candidate : `ruche_code` et `horodatage` n'apparaissent jamais à droite d'une DF, donc toute clé doit contenir les deux.

## 4. Confrontation aux données

Les requêtes sont dans `contraintes.sql`, sur le modèle :
`SELECT X FROM extrait_plat GROUP BY X HAVING count(DISTINCT Y) > 1;`

| DF testée | Attendu | Obtenu |
|---|---|---|
| DF1 `site_id → site_nom, pays` | 0 ligne | ✅ 0 ligne |
| DF2 `ruche_code → site_id, telephone` | 0 ligne | ✅ 0 ligne |
| DF3 `telephone → apicultrice, cooperative` | 0 ligne | ✅ 0 ligne |
| DF4 `ruche_code, horodatage → poids_kg, temp_int_c` | 0 ligne | ✅ 0 ligne |
| fausse DF `apicultrice → telephone` | Aminata Diop | ❌ **Aminata Diop, 2 téléphones** |

> « 0 ligne » ne prouve pas qu'une DF est vraie. Cela veut dire que **ces données-ci** ne la contredisent pas. Seule une contrainte dans le schéma (clé primaire, UNIQUE) la garantit pour l'avenir.

### Les logins (étape 4.4)

| # | Commande | Résultat |
|---|---|---|
| 1 | logins en double | `a.diop` × 3 |
| 2 | `UNIQUE (login)` | ❌ refusée : doublons |
| 3 | 3 `UPDATE` (`aminata.diop.casa`, `aminata.diop.kold`, `awa.diop`) | ✅ |
| 4 | `UNIQUE (login)` | ✅ acceptée |
| 5 | insérer `Awa.Diop` | ✅ acceptée : le piège des majuscules |
| 6 | index unique sur `lower(login)`, puis `Awa.Diop` | ❌ refusée |

## 5. Et si l'application identifiait les apicultrices par leur nom ?

Les deux « Aminata Diop » (SN-CASA et SN-KOLD) seraient **confondues** :

| Conséquence | STRIDE |
|---|---|
| Une mesure, une récolte ou un paiement attribué à la mauvaise personne | T |
| L'une voit les ruches (GPS) et le téléphone de l'autre | I |
| On ne sait plus laquelle a déclaré ou validé, et chacune peut nier | S, R |
| Un `UPDATE … WHERE nom = 'Aminata Diop'` modifie les deux | T |

C'est exactement ce qui s'est passé avec les trois logins `a.diop`.

> **À retenir :** on identifie une personne par un identifiant attribué (UUID). Une donnée métier unique (téléphone, login) se protège par une contrainte UNIQUE.

---

## Testez-vous · Lab 4

1. **Que veut dire `site_id → pays` ?**
   Si je connais le site, je connais son pays. Deux lignes qui ont le même `site_id` ont forcément le même `pays`.
2. **Pourquoi `{ruche_code}` n'est-il pas une clé ?**
   Sa fermeture ne donne que 7 colonnes sur 10 : une ruche a 48 lignes, une par mesure.
3. **Pourquoi « 0 ligne » ne prouve-t-il pas qu'une DF est vraie ?**
   Une DF est une règle sur **toutes** les données possibles. 0 ligne veut seulement dire « pas encore contredite ».
