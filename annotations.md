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
