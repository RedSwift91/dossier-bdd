# Normalisation de extrait_plat - Groupe Killian Morvan

> **TP Jour 1 · Lab 5 · Livrable 3 (partie 2)**
> Fichiers liés : `anomalies.sql`, `migration_3nf.sql`
> Point de départ : `dependances.md` (clé **{ruche_code, horodatage}**)

| | DF |
|---|---|
| **DF1** | `site_id → site_nom, pays` |
| **DF2** | `ruche_code → site_id, telephone` |
| **DF3** | `telephone → apicultrice, cooperative` |
| **DF4** | `ruche_code, horodatage → poids_kg, temp_int_c` |

## Sommaire

1. [Les trois anomalies](#1-les-trois-anomalies)
2. [Diagnostic : quelle forme normale ?](#2-diagnostic--quelle-forme-normale-)
3. [Le découpage](#3-le-découpage)
4. [La preuve que rien n'est perdu](#4-la-preuve-que-rien-nest-perdu)
5. [Les tables norm sont en BCNF](#5-les-tables-norm-sont-en-bcnf)
6. [Conclusion](#conclusion)

---

## 1. Les trois anomalies

### Mise à jour

On change le pays sur **une seule** ligne de SN-KOLD-011, et le téléphone d'Awa Diop sur une seule ligne de SN-CASA-030.

| Enquête par pays | Avant | Après |
|---|---|---|
| Cameroun | 96 mesures | 96 mesures |
| Côte d'Ivoire | 96 mesures | 96 mesures |
| Sénégal | 336 mesures | 335 mesures |
| **Senegal** | — | **1 mesure** |
| **Nombre de pays** | **3** | **4** ❌ |

**Cause : DF1.** Le pays dépend du site, mais il est recopié sur chaque mesure. DF2 et DF3 font de même pour le téléphone.

### Suppression

Entre `BEGIN` et `ROLLBACK`, on efface les 48 mesures de SN-KOLD-020, la seule ruche de Fatou Sow.

**Résultat : Fatou Sow et son téléphone disparaissent de la base.** ❌

**Cause : DF2 + DF3.** L'apicultrice n'existe qu'à travers les mesures de ses ruches.

### Insertion

Avec la clé `(ruche_code, horodatage)`, on essaie d'ajouter le site CM-BAFO, qui n'a pas encore de ruche.

```text
ERREUR: une valeur NULL viole la contrainte NOT NULL de la colonne « ruche_code »
```

**Cause : DF1.** Un site ne peut être écrit que sur une ligne de mesure.

## 2. Diagnostic : quelle forme normale ?

| Forme | Règle | DF qui la violent |
|---|---|---|
| **1NF** | une seule valeur par case | ✅ aucune |
| **2NF** | aucune colonne ne dépend d'une **partie** de la clé | ❌ **DF2** : `ruche_code` n'est qu'une partie de la clé |
| **3NF** | aucune colonne ne dépend d'une colonne **hors clé** | ❌ **DF1** (`site_id`) et **DF3** (`telephone`) |
| **BCNF** | la partie gauche de toute DF est une clé | ❌ **DF1, DF2, DF3** (seule DF4 respecte la règle) |

> **`extrait_plat` n'est qu'en 1NF.**

## 3. Le découpage

Une table par déterminant (partie gauche d'une DF), dans le schéma `norm` :

| Table | Clé primaire | Autres colonnes | DF |
|---|---|---|---|
| `norm.site` | site_id | site_nom, pays | DF1 |
| `norm.apicultrice` | telephone | apicultrice, cooperative | DF3 |
| `norm.ruche` | ruche_code | #site_id, #telephone | DF2 |
| `norm.mesure` | ruche_code, horodatage | poids_kg, temp_int_c | DF4 |

### Lancement de migration_3nf.sql

| Lancement | Résultat |
|---|---|
| **1.** Sur les données corrompues | ❌ `clé dupliquée « site_pkey » : (site_id)=(SN-KOLD)`. Rien n'est créé. |
| Nettoyage | 2 conflits trouvés : SN-KOLD `{Senegal, Sénégal}` et SN-CASA-030 avec 2 téléphones. On garde la valeur majoritaire. |
| **2.** Après nettoyage | ✅ **4 sites, 8 apicultrices, 11 ruches, 528 mesures** |

> Le refus du premier lancement est le but recherché : **la base découpée ne peut plus se contredire.**

## 4. La preuve que rien n'est perdu

La vue `norm.reconstruit` rejoint les 4 tables (mêmes colonnes, même ordre que `extrait_plat`), puis on compare les deux tables dans les deux sens :

```sql
(SELECT * FROM extrait_plat EXCEPT SELECT * FROM norm.reconstruit)
UNION ALL
(SELECT * FROM norm.reconstruit EXCEPT SELECT * FROM extrait_plat);
```

**Résultat : 0 ligne. ✅** La décomposition est **sans perte** : chaque jointure se fait sur la clé primaire d'une des deux tables.

### Les attaques rejouées

| Attaque | Avant (extrait_plat) | Après (norm) |
|---|---|---|
| Un second pays pour SN-KOLD | ✅ accepté (la base se contredit) | ❌ **refusé** (`site_pkey`) |
| Un site sans ruche (CM-BAFO) | ❌ refusé | ✅ **accepté** |
| Enquête par pays | 4 pays | ✅ **3 pays** |

## 5. Les tables norm sont en BCNF

| Table | DF | Partie gauche = clé ? |
|---|---|---|
| `norm.site` | site_id → site_nom, pays | ✅ |
| `norm.apicultrice` | telephone → apicultrice, cooperative | ✅ |
| `norm.ruche` | ruche_code → site_id, telephone | ✅ |
| `norm.mesure` | ruche_code, horodatage → poids_kg, temp_int_c | ✅ |

Aucune autre DF ne s'applique : `site_nom`, `pays`, `apicultrice` (homonymes) ou `poids_kg` ne déterminent rien. **Les 4 tables sont en BCNF**, donc aussi en 3NF.

> **Limite.** `norm.apicultrice` prend le téléphone comme clé, car c'est le seul identifiant présent dans `extrait_plat`. Dans la vraie base (`schema.sql`), on garde un UUID, et la coopérative passe dans `adhesion`, car une apicultrice peut adhérer à plusieurs coopératives.

---

## Conclusion

> **Une seule ligne modifiée a fait passer l'enquête de 3 à 4 pays. Une base non normalisée ne peut pas servir de preuve.**

## Testez-vous · Lab 5

1. **Un exemple de chaque anomalie ?**
   - *Mise à jour* : corriger le pays sur une seule des 96 lignes d'un site crée deux pays pour ce site.
   - *Suppression* : effacer les mesures de la seule ruche de Fatou Sow fait disparaître Fatou Sow.
   - *Insertion* : impossible d'ajouter un site tant qu'il n'a ni ruche ni mesure.
2. **Pourquoi `ruche_code → site_id` viole-t-il la 2NF ?**
   `site_id` dépend d'une **partie** de la clé {ruche_code, horodatage} : le site est recopié 48 fois par ruche.
3. **Comment prouver en SQL qu'une décomposition est sans perte ?**
   On recompose la table par jointure, puis on calcule `(A EXCEPT B) UNION ALL (B EXCEPT A)`. 0 ligne veut dire que rien n'a été perdu et que rien n'est apparu.
