# Lab 1 · Modèle entité-association Queen Bee — annotations

## Question 1 · De quoi le système doit-il se souvenir ?

9 entités : **site**, **ruche**, **apicultrice**, **coopérative**, **mesure**, **inspection**, **récolte**, **alerte**, **utilisateur** (compte de connexion).

Ne sont pas des entités : le pays (une information sur le site), le poids ou la température (des informations sur la mesure), le rôle (une information sur l'utilisateur).

Les deux entités sans équivalent dans GreenFarm sont **RÉCOLTE** et **ALERTE** :
- RÉCOLTE : la production de miel est déclarée par l'apicultrice puis validée par un coordinateur. Il faut garder qui a validé et quand, car c'est sur cette quantité que repose la valeur économique (et donc la fraude).
- ALERTE : le système détecte des événements (essaimage, vol, capteur silencieux) avec un niveau de confiance ; il faut les historiser pour réagir et pour prouver ce qui s'est passé.

## Question 2 · Que garde-t-on sur chacune, et qu'est-ce qui la distingue ?

| Chose | Ce qu'on garde | Ce qui la distingue |
|---|---|---|
| site | nom, pays, localité | un numéro attribué (deux sites peuvent porter le même nom dans deux pays) |
| ruche | code, latitude, longitude, date d'installation | le code (ex. SN-CASA-014) |
| apicultrice | nom, téléphone | un numéro attribué (le nom ne suffit pas : homonymes) |
| coopérative | nom | un numéro attribué |
| mesure | horodatage, poids, température intérieure et extérieure, humidité, activité sonore, batterie | la ruche et l'horodatage |
| inspection | date, état de la colonie, présence de la reine, observations | un numéro attribué |
| récolte | date, quantité (kg), statut (déclarée / validée / refusée), date de validation | un numéro attribué |
| alerte | type (essaimage, vol, capteur silencieux), date, niveau de confiance, statut | un numéro attribué |
| utilisateur | login, empreinte du mot de passe, rôle | un numéro attribué (le login aussi est unique) |

## Question 3 · Comment sont-elles liées ?

| Lien | Dans un sens | Dans l'autre sens |
|---|---|---|
| ruche - apicultrice | une ruche appartient à une seule apicultrice | une apicultrice possède zéro, une ou plusieurs ruches |
| site - ruche | une ruche est installée sur un seul site | un site accueille zéro, une ou plusieurs ruches |
| apicultrice - site | une apicultrice est rattachée à un seul site | un site a zéro, une ou plusieurs apicultrices |
| apicultrice - coopérative | une apicultrice adhère à au moins une coopérative | une coopérative a zéro, un ou plusieurs adhérents |
| ruche - mesure | une mesure est émise par une seule ruche | une ruche émet zéro, une ou plusieurs mesures |
| ruche - inspection | une inspection porte sur une seule ruche | une ruche subit zéro, une ou plusieurs inspections |
| ruche - récolte | une récolte provient d'une seule ruche | une ruche produit zéro, une ou plusieurs récoltes |
| ruche - alerte | une alerte concerne une seule ruche | une ruche a zéro, une ou plusieurs alertes |
| coordinateur - récolte validée | une récolte est validée par au plus un coordinateur (aucun tant qu'elle n'est pas validée) | un coordinateur valide zéro, une ou plusieurs récoltes |
| apicultrice - compte de connexion | une apicultrice a au plus un compte | un compte appartient au plus à une apicultrice (les comptes coordinateur, gestionnaire et admin n'en ont pas) |
| coopérative - site | une coopérative est basée sur un seul site | un site accueille zéro, une ou plusieurs coopératives |
| compte - site | un compte (de coordinateur) est affecté à au plus un site | un site a zéro, un ou plusieurs comptes affectés |
| compte - récolte déclarée | une récolte est déclarée par un seul compte | un compte déclare zéro, une ou plusieurs récoltes |

## Question 4 · Ce que le sujet ne dit pas (hypothèses)

| Question au client | Notre hypothèse |
|---|---|
| Une ruche peut-elle changer de site (transhumance) ? | oui, mais on ne garde que le site actuel ; l'historique des déplacements sera ajouté si besoin |
| Une ruche peut-elle changer de propriétaire ? | oui, mais on ne garde que l'apicultrice actuelle |
| Qui peut valider une récolte ? | uniquement un coordinateur, et seulement pour les ruches de son site ; jamais la déclarante elle-même |
| Une récolte refusée peut-elle être redéclarée ? | non, elle reste refusée ; l'apicultrice fait une nouvelle déclaration |
| Un coordinateur est-il rattaché à un seul site ? | oui, un seul site |
| Une alerte est-elle traitée par quelqu'un ? | oui, elle a un statut (ouverte / traitée) ; on ne garde pas encore qui l'a traitée |
| Qui fait les inspections ? | l'apicultrice propriétaire de la ruche |
| Un capteur peut-il être déplacé d'une ruche à une autre ? | non : on rattache la mesure directement à la ruche, pas au capteur |

## Question 5 · Ce qui intéresserait un voleur ou un fraudeur

1. **La position GPS des ruches** : aller voler les ruches (une ruche vaut cher), surtout celles qu'une alerte indique comme isolées.
2. **La quantité des récoltes et leur validation** : gonfler une récolte, ou la faire valider par un complice, pour toucher plus d'argent ou écouler du miel non tracé.
3. **Le téléphone et le nom des apicultrices** : démarchage, hameçonnage, pression sur des personnes isolées.
4. **Le login et le mot de passe** : se connecter comme coordinateur pour valider de fausses récoltes, ou comme admin pour effacer les traces.

## Partie C · Sensibilité et menaces (STRIDE)

Rôles : **API** = apicultrice, **COO** = coordinateur de site, **GES** = gestionnaire de l'association, **ADM** = administrateur.

| Entité | Sensibilité | Qui lit | Qui modifie | Menace STRIDE et ce que gagne l'attaquant |
|---|---|---|---|---|
| RUCHE | confidentielle (GPS) | API (les siennes), COO (son site), GES, ADM | COO, ADM | **I** : connaître la position GPS pour voler la ruche |
| SITE | interne | tous | GES, ADM | **T** : modifier le site d'une ruche pour masquer un déplacement ou un vol |
| APICULTRICE | confidentielle (donnée personnelle, RGPD) | elle-même, COO (son site), GES, ADM | elle-même (téléphone), GES, ADM | **I** : fuite du nom et du téléphone, puis hameçonnage ou démarchage |
| COOPÉRATIVE | interne | tous | GES, ADM | **T** : ajouter une fausse adhésion pour toucher des aides ou un prix coopératif |
| MESURE | interne | API (ses ruches), COO, GES | les capteurs uniquement (insertion), jamais modifiée | **T / S** : **une mesure rejouée** (renvoyer un ancien poids) cache une chute de poids, donc un vol ou un essaimage ; un faux capteur envoie des mesures au nom d'une ruche |
| INSPECTION | interne | API (ses ruches), COO, GES | API (les siennes) | **R** : l'apicultrice nie avoir constaté l'absence de reine ; **T** : une fausse inspection couvre une ruche abandonnée |
| RÉCOLTE | critique (valeur économique) | API (les siennes), COO (son site), GES | API (déclaration), COO (validation) | **R** : **une récolte validée sans qu'on sache par qui**, donc personne n'est responsable d'une quantité gonflée ; **E** : une apicultrice qui valide sa propre récolte |
| ALERTE | interne | API (ses ruches), COO, GES | le système (création), COO (statut) | **D** : faire taire les alertes (capteur silencieux, suppression) pendant un vol ; **T** : baisser le niveau de confiance |
| UTILISATEUR | critique | ADM (l'utilisateur voit son propre compte) | ADM | **S** : se connecter à la place d'un coordinateur ; **E** : changer son propre rôle en admin |
| *Journal des actions* (à prévoir) | critique | ADM (lecture seule) | personne (ajout seulement) | **R / T** : **l'effacement de l'historique des actions** permet à un admin ou à un attaquant de nier avoir validé ou supprimé quoi que ce soit |

Lettres STRIDE utilisées : S, T, R, I, D, E (les 6).

## Testez-vous · Lab 1

1. La date d'adhésion appartient **au lien** ADHÈRE entre l'apicultrice et la coopérative : une apicultrice adhère à plusieurs coopératives à des dates différentes.
2. Le nom n'est **pas unique** (homonymes), il peut **changer** (mariage, faute de frappe), et c'est une donnée personnelle qu'on ne veut pas propager dans d'autres tables.
3. Le rejeu d'une ancienne mesure de poids, c'est **T** (altération de l'intégrité des données), et souvent **S** aussi quand l'attaquant se fait passer pour le capteur.
4. **1,1 du côté de RUCHE** (et 0,n du côté d'APICULTRICE).

## Schéma relationnel

Notation : clé primaire en **gras**, clé étrangère précédée de `#`.

| Table | Clé primaire | Autres colonnes | Clés étrangères (vers quelle table) |
|---|---|---|---|
| site | **id** (code lisible : `SN-CASA`) | nom, pays, localite | — |
| cooperative | **id** (uuid) | nom | #site_id (site) |
| apicultrice | **id** (uuid) | nom, telephone | #site_id (site) |
| ruche | **id** (uuid) | code (UNIQUE), latitude, longitude, date_installation | #site_id (site), #apicultrice_id (apicultrice) |
| adhesion | **(apicultrice_id, cooperative_id)** | date_adhesion | #apicultrice_id (apicultrice), #cooperative_id (cooperative) |
| utilisateur | **id** (uuid) | login, mot_de_passe_hash, role | #site_id (site), #apicultrice_id UNIQUE (apicultrice) |
| mesure | **id** (bigint identity) ; UNIQUE (ruche_id, horodatage) | horodatage, poids_kg, temp_int_c, temp_ext_c, humidite_pct, activite_sonore_db, batterie_pct | #ruche_id (ruche) |
| inspection | **id** (uuid) | date_inspection, etat_colonie, reine_presente, observations | #ruche_id (ruche) |
| recolte | **id** (uuid) | date_recolte, quantite_kg, statut, date_validation | #ruche_id (ruche), #declaree_par (utilisateur), #validee_par (utilisateur) |
| alerte | **id** (uuid) | type_alerte, date_alerte, niveau_confiance, statut | #ruche_id (ruche) |

**10 tables, 14 clés étrangères.** Les règles appliquées :
- **Règle 1** : chaque entité devient une table. Le site garde un code lisible (court, stable, pas secret). Tout ce que l'application exposera (ruches, personnes, comptes, récoltes) reçoit un UUID, car un numéro 1, 2, 3 se devine.
- **Règle 2** : chaque lien 1,1 - 0,n devient une clé étrangère du côté 1,1 (`ruche.site_id`, `ruche.apicultrice_id`, `mesure.ruche_id`...).
- **Règle 3** : le lien n,n ADHÈRE devient la table `adhesion`. Sa clé primaire réunit les deux clés étrangères, et la table porte `date_adhesion`.
- **Règle 4** : le lien 0,1 - 0,1 entre l'apicultrice et son compte devient `utilisateur.apicultrice_id UNIQUE` : jamais deux comptes pour une apicultrice.
- Les deux liens entre UTILISATEUR et RÉCOLTE (DÉCLARE, VALIDE) ne portent pas le nom de la table visée. Ils deviennent `declaree_par` et `validee_par`, qui pointent tous deux vers `utilisateur`.

Les règles de sécurité posées dans `schema.sql` :
- `mesure_anti_rejeu UNIQUE (ruche_id, horodatage)` empêche de rejouer une mesure.
- `recolte_quantite_positive` interdit une quantité nulle ou négative.
- `recolte_validation_tracee` garantit qu'une récolte validée ou refusée a toujours un validateur et une date, et qu'une récolte simplement déclarée n'en a pas.
- `recolte_pas_auto_validation` empêche de valider sa propre récolte.
- `alerte_confiance_bornee` limite le niveau de confiance entre 0 et 1.
- Un compte de rôle « apicultrice » pointe obligatoirement vers une apicultrice, et un coordinateur a toujours un site.

**Relancer `donnees.sql` une seconde fois, sans `schema.sql`** : le premier INSERT échoue avec `la valeur d'une clé dupliquée rompt la contrainte unique « site_pkey » ; la clé « (id)=(SN-CASA) » existe déjà`. Grâce à `BEGIN; ... COMMIT;`, toute la transaction est annulée. Rien n'est doublé : il y a toujours 11 ruches. Deux règles protègent la base : la **clé primaire de `site`**, un code lisible et donc stable d'un lancement à l'autre, et l'**atomicité de la transaction**. Le `UNIQUE` sur `ruche.code` et l'anti-rejeu des mesures bloqueraient aussi plus loin.

### Testez-vous · Lab 2

1. Dans la table du côté **1,1** : par exemple, la ruche porte `apicultrice_id`.
2. Parce qu'une ligne d'association est identifiée par le **couple** (apicultrice, coopérative). Chaque colonne seule se répète : une apicultrice adhère à plusieurs coopératives. Le couple, lui, ne doit apparaître qu'une fois, sinon une même adhésion serait enregistrée deux fois.
3. Elle protège contre le **rejeu** : renvoyer une ancienne mesure (même ruche, même instant) pour masquer une chute de poids est refusé (menace T).
4. Parce que `ruche.site_id REFERENCES site(id)` exige que la table visée existe déjà au moment du `CREATE TABLE`.
