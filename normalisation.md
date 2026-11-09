# Normalisation de extrait_plat - Groupe Killian Morvan

Rappel (dependances.md) : clé candidate **{ruche_code, horodatage}**, et les DF :

- DF1 `site_id -> site_nom, pays`
- DF2 `ruche_code -> site_id, telephone`
- DF3 `telephone -> apicultrice, cooperative`
- DF4 `ruche_code, horodatage -> poids_kg, temp_int_c`

## Les anomalies provoquées (anomalies.sql) et leur cause

| Anomalie | Ce qu'on a fait | Ce qu'on a obtenu | DF qui la cause |
|---|---|---|---|
| **Mise à jour** | `Sénégal` changé en `Senegal` sur une seule ligne de SN-KOLD-011 ; le téléphone d'Awa Diop changé sur une seule ligne de SN-CASA-030 | l'enquête par pays passe de **3 à 4 pays** (« Senegal » : 1 mesure) ; SN-CASA-030 a deux téléphones | **DF1** : le pays dépend du site, mais il est recopié sur les 48 lignes de chaque ruche du site. **DF2/DF3** : le téléphone est recopié sur chaque mesure |
| **Suppression** | effacer les 48 mesures de SN-KOLD-020, la seule ruche de Fatou Sow (entre BEGIN et ROLLBACK) | Fatou Sow et son téléphone **disparaissent** de la base | **DF2 + DF3** : l'apicultrice n'existe qu'à travers les lignes de mesure de ses ruches |
| **Insertion** | avec la clé (ruche_code, horodatage), ajouter le site CM-BAFO sans ruche | **refus** : `une valeur NULL viole la contrainte NOT NULL de la colonne « ruche_code »` | **DF1** : un site ne peut être écrit que sur une ligne de mesure, il faut donc inventer une ruche et un instant |

## Classement des dépendances

| Forme normale | Règle | Nos dépendances qui la violent |
|---|---|---|
| 1NF | chaque case contient une seule valeur | **aucune** : chaque colonne contient une valeur atomique (un pays, un téléphone, un poids) |
| 2NF | aucune colonne ne dépend d'une partie de la clé | **DF2** `ruche_code -> site_id, telephone`. `ruche_code` n'est qu'une partie de la clé {ruche_code, horodatage}. Par transitivité, site_nom, pays, apicultrice et cooperative en dépendent aussi |
| 3NF | aucune colonne ne dépend d'une colonne qui n'est pas la clé | **DF1** `site_id -> site_nom, pays` et **DF3** `telephone -> apicultrice, cooperative` : `site_id` et `telephone` ne sont pas des clés (dépendances transitives) |
| BCNF | la partie gauche de toute dépendance est une clé | **DF1, DF2 et DF3**. Seule **DF4** a pour partie gauche la clé {ruche_code, horodatage} |

`extrait_plat` n'est donc qu'en **1NF**.

## Le découpage (migration_3nf.sql)

Une table par déterminant, dans le schéma `norm` :

| Table norm | Clé primaire | Colonnes | DF portée |
|---|---|---|---|
| norm.site | site_id | site_nom, pays | DF1 |
| norm.apicultrice | telephone | apicultrice, cooperative | DF3 |
| norm.ruche | ruche_code | #site_id, #telephone | DF2 |
| norm.mesure | (ruche_code, horodatage) | poids_kg, temp_int_c | DF4 |

- **1er lancement, sur les données corrompues : refus.** `la valeur d'une clé dupliquée rompt la contrainte unique « site_pkey » ; la clé « (site_id)=(SN-KOLD) » existe déjà`. La base découpée ne peut plus contenir deux pays pour un site. Grâce à `BEGIN`, rien n'est créé.
- **Nettoyage** : on trouve deux conflits, `SN-KOLD : {Senegal, Sénégal}` et `SN-CASA-030 : deux téléphones`. On garde la valeur majoritaire et on corrige la copie fautive (UPDATE 1, UPDATE 1).
- **2e lancement : 4 sites, 8 apicultrices, 11 ruches, 528 mesures.**

## La preuve que rien n'est perdu

La vue `norm.reconstruit` rejoint les quatre tables avec les mêmes colonnes, dans le même ordre, que `extrait_plat`. La différence dans les deux sens (`EXCEPT` puis `UNION ALL`) renvoie **0 ligne** : la décomposition est **sans perte**. C'est garanti par construction, car chaque jointure se fait sur la clé primaire d'une des deux tables (théorème de Heath).

On rejoue ensuite les attaques :
- un second pays pour SN-KOLD est **refusé** (`site_pkey`) ;
- un site sans ruche (CM-BAFO) est **accepté**.

L'enquête par pays sur les tables norm redonne **3 pays**.

## Les tables norm sont-elles en BCNF ?

| Table | DF qui s'y appliquent | Partie gauche = clé ? | BCNF |
|---|---|---|---|
| norm.site | site_id -> site_nom, pays | oui, site_id est la clé primaire | oui |
| norm.apicultrice | telephone -> apicultrice, cooperative | oui, telephone est la clé primaire | oui |
| norm.ruche | ruche_code -> site_id, telephone | oui, ruche_code est la clé primaire | oui |
| norm.mesure | ruche_code, horodatage -> poids_kg, temp_int_c | oui, c'est la clé primaire | oui |

Aucune autre DF non triviale ne s'applique : `site_nom`, `pays`, `apicultrice` (homonymes !), `poids_kg`... ne déterminent rien. Les quatre tables sont en **BCNF**, donc aussi en 3NF.

Limite : `norm.apicultrice` prend le téléphone comme clé, parce que c'est le seul identifiant présent dans `extrait_plat`. Dans la vraie base, on garde un UUID (`apicultrice.id`) et le téléphone reste une simple donnée qui peut changer. Comme une apicultrice peut adhérer à plusieurs coopératives, `cooperative` irait dans une table `adhesion`, comme dans `schema.sql`.

## Conclusion

**Une seule ligne modifiée a fait passer l'enquête de 3 à 4 pays. Une base non normalisée ne peut pas servir de preuve.**

## Testez-vous · Lab 5

1. Les trois anomalies dans `extrait_plat` :
   - **mise à jour** : corriger le pays sur une seule des 96 lignes du site crée deux pays pour un même site ;
   - **suppression** : effacer les mesures de la seule ruche de Fatou Sow fait disparaître Fatou Sow ;
   - **insertion** : impossible d'enregistrer un nouveau site (ou une nouvelle apicultrice) tant qu'il n'a ni ruche ni mesure.
2. `ruche_code -> site_id` : `site_id` dépend de `ruche_code` seul, qui n'est qu'une **partie** de la clé {ruche_code, horodatage}. C'est une dépendance partielle, interdite en 2NF : le site est recopié 48 fois par ruche.
3. On recompose la table de départ en joignant les morceaux, dans une vue, puis on compare les deux sens : `(A EXCEPT B) UNION ALL (B EXCEPT A)`. Si le résultat fait 0 ligne, aucune ligne n'a été perdue et aucune ligne parasite n'est apparue : la décomposition est sans perte.
