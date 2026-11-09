# Dépendances fonctionnelles - Groupe Killian Morvan

Table étudiée : `extrait_plat` (plat.sql), 528 lignes, 10 colonnes :
`ruche_code, site_id, site_nom, pays, apicultrice, telephone, cooperative, horodatage, poids_kg, temp_int_c`.

## Les DF de extrait_plat

| DF | En français |
|---|---|
| site_id -> site_nom, pays | un site a un seul nom et un seul pays |
| ruche_code -> site_id, telephone | une ruche est installée sur un seul site et appartient à une seule apicultrice (désignée par son téléphone) |
| telephone -> apicultrice, cooperative | un téléphone désigne une seule apicultrice, et donc sa coopérative |
| ruche_code, horodatage -> poids_kg, temp_int_c | une seule mesure par ruche et par instant (la règle anti-rejeu) |

Remarque : `telephone -> cooperative` n'est vraie que parce que, dans notre jeu d'essai, chaque apicultrice adhère à **une seule** coopérative. Le MCD autorise 1,n adhésions. Dès qu'une apicultrice adhérera à deux coopératives, chaque mesure apparaîtra deux fois dans `extrait_plat`, et cette DF tombera.

On n'a **pas** `apicultrice -> telephone` : le nom ne détermine pas la personne (voir l'étape 4.3).

## Fermeture de {site_id}

| Tour | DF utilisée | {site_id}⁺ |
|---|---|---|
| 0 | aucune | {site_id} |
| 1 | site_id -> site_nom, pays | + site_nom, pays |
| 2 | plus rien ne s'ajoute | |

**3 colonnes sur 10 : pas une clé.**

## Fermeture de {ruche_code}

| Tour | DF utilisée | {ruche_code}⁺ |
|---|---|---|
| 0 | aucune | {ruche_code} |
| 1 | ruche_code -> site_id, telephone | + site_id, telephone |
| 2 | site_id -> site_nom, pays ; telephone -> apicultrice, cooperative | + site_nom, pays, apicultrice, cooperative |
| 3 | plus rien ne s'ajoute | |

**7 colonnes sur 10 : pas une clé.** Il manque horodatage, poids_kg et temp_int_c : une ruche a 48 mesures.

## Fermeture de {ruche_code, horodatage}

| Tour | DF utilisée | {ruche_code, horodatage}⁺ |
|---|---|---|
| 0 | aucune | {ruche_code, horodatage} |
| 1 | ruche_code, horodatage -> poids_kg, temp_int_c ; ruche_code -> site_id, telephone | + poids_kg, temp_int_c, site_id, telephone |
| 2 | site_id -> site_nom, pays ; telephone -> apicultrice, cooperative | + site_nom, pays, apicultrice, cooperative |
| 3 | plus rien ne s'ajoute | |

**10 colonnes sur 10 : c'est une clé.**

## La clé candidate

**{ruche_code, horodatage}** est la clé candidate de `extrait_plat`. Elle est minimale, on ne peut rien en retirer :
- sans `horodatage`, {ruche_code}⁺ ne donne que 7 colonnes : il y a 48 lignes par ruche ;
- sans `ruche_code`, {horodatage}⁺ = {horodatage} : à un même instant, les 11 ruches envoient chacune une mesure.

Aucune autre colonne n'apparaît uniquement à gauche des DF. `horodatage` n'apparaît jamais à droite, donc toute clé le contient. `ruche_code` n'apparaît jamais à droite non plus. C'est donc la seule clé candidate.

## Confrontation aux données (contraintes.sql)

Les 4 DF ont donné **0 ligne** de contradiction. La fausse DF `apicultrice -> telephone` renvoie **Aminata Diop, 2 téléphones**.

Ce « 0 ligne » ne prouve pas que la DF est vraie. Il dit seulement que **ces données-ci** ne la contredisent pas : une DF est une règle métier, qui doit valoir pour toutes les données futures. La seule garantie, c'est une contrainte dans le schéma (clé primaire, UNIQUE).

## Si l'application identifiait les apicultrices par leur nom ?

Les deux « Aminata Diop » (SN-CASA et SN-KOLD) seraient confondues :
- **mauvais rattachements** : une mesure, une récolte ou une alerte attribuée à la mauvaise personne, et un paiement de récolte versé à la mauvaise apicultrice ;
- **fuite de données (I)** : l'une verrait les ruches, donc les positions GPS, et le téléphone de l'autre ;
- **usurpation (S) et répudiation (R)** : on ne peut pas savoir laquelle a déclaré ou validé, et chacune peut nier ;
- **perte de données** : une mise à jour « WHERE nom = 'Aminata Diop' » modifierait ou supprimerait les deux.

C'est exactement ce qui s'est passé avec les logins `a.diop` (3 comptes pour 3 personnes). On identifie une personne par un identifiant attribué (UUID). Une donnée métier unique (téléphone, login) se protège par une contrainte UNIQUE.

## Testez-vous · Lab 4

1. `site_id -> pays` : si je connais le site, je connais son pays. Deux lignes qui ont le même `site_id` ont forcément le même `pays`.
2. Parce que sa fermeture ne contient que 7 colonnes sur 10 : `ruche_code` ne détermine ni `horodatage` ni la mesure. Une ruche a 48 lignes dans `extrait_plat`.
3. Parce qu'une DF est une règle sur **toutes** les données possibles, pas seulement sur celles d'aujourd'hui. 0 ligne veut dire « pas encore contredite ». Demain, une saisie peut la violer si aucune contrainte ne l'interdit.
