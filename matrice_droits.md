# Matrice des droits - Groupe Killian Morvan

> **TP Jour 2 · Lab 8 · Étape 8.4**
> Remplie **avant** d'écrire le moindre `GRANT`. `roles.sql` l'applique ligne à ligne.
> Fichiers liés : `roles.sql`, `audit.sql`, `tests_contournement.sql`

## La matrice

| Objet | apicultrice | coordinateur | gestionnaire | admin |
|---|---|---|---|---|
| ses ruches et leurs mesures | lire (`v_mes_ruches`, `v_mes_mesures`) | lire les ruches **de son site** (`v_ruches_site`) | non (chiffres agrégés seulement) | non |
| déclarer une récolte | sur ses ruches (`v_mes_recoltes`) | non | non | non |
| valider une récolte (UC-C02) | non | sur son site, par `valider_recolte()` seulement | non | non |
| ruches et téléphones de son site | non | lire (`v_ruches_site`) | non | non |
| synthèse et export (UC-G01, UC-G02) | non | non | lire (`synthese_site_jour`, `v_export_bailleur`) | non |
| comptes utilisateurs (UC-AD01) | son compte (`v_moi`) | son compte (`v_moi`) | son compte (`v_moi`) | lire, créer, modifier (pas supprimer) |
| journal d'audit | non | non | non | lire |

Personne n'a de droit direct sur une table métier (`apicultrice`, `ruche`, `mesure`, `recolte`). Tout passe par une vue qui filtre sur `qui()`, ou par une fonction qui vérifie le rôle.

## Les choix

| Choix | Pourquoi |
|---|---|
| Le coordinateur valide **par une fonction**, pas par `UPDATE` sur `recolte` | avec `UPDATE`, il pourrait aussi changer les volumes ou valider hors de son site |
| L'apicultrice écrit dans **trois colonnes** de `v_mes_recoltes` (`ruche_id`, `date_recolte`, `quantite_kg`) | elle ne peut ni se déclarer validée (`statut`), ni déclarer au nom d'une autre (`declaree_par` est rempli par la base) |
| `WITH CHECK OPTION` sur `v_mes_recoltes` | refuse une récolte sur une ruche qui n'est pas la sienne |
| L'admin n'a pas `DELETE` sur `utilisateur` | un compte supprimé effacerait le lien avec ses récoltes et ses validations (preuves) ; on le désactive plutôt |
| Le gestionnaire ne voit que des agrégats et l'export pseudonymisé | il pilote l'association, il n'a pas besoin des téléphones ni des positions exactes |
| Le journal n'est lisible que par l'admin, et **personne** ne peut y écrire | seul le trigger `audit_ligne()` (`SECURITY DEFINER`) y écrit |

## Correspondance avec le sujet

Le sujet est écrit pour un autre jeu d'essai. Les rôles PostgreSQL portent **les logins de notre table `utilisateur`**, puisque `qui()` relie les deux :

| Dans le sujet | Chez nous | Qui |
|---|---|---|
| `f.ba` | `awa.diop` | Awa Diop, SN-CASA, une seule ruche (SN-CASA-030) |
| `awa.diop` | `aminata.diop.casa` | Aminata Diop, SN-CASA, trois ruches |
| `coord.sn` | `m.ndiaye` | coordinateur de SN-CASA |
| `gest.beeafrica` | `gest.beeafrica` | ajouté dans `utilisateur` par `roles.sql` |
| `admin.beeafrica` | `admin.beeafrica` | le compte `admin` du jour 1, renommé : un compte nominatif, pas un compte partagé |

## Limite : le superutilisateur

En `postgres`, `ALTER TABLE journal_audit DISABLE TRIGGER journal_ajout_seul;` **passe** (étape 8.3, point 4, dans `tests_audit.sql`). Le propriétaire de la table peut donc désactiver la protection, modifier le journal, puis la réactiver.

> **Conséquence :** le journal de la base ne suffit pas comme preuve. Il doit aussi être **copié au fil de l'eau hors de la base** (vers le SIEM du cahier des charges), là où l'administrateur de la base ne peut pas écrire. Et personne ne doit travailler au quotidien en superutilisateur.

## Testez-vous · Lab 8

1. **Pourquoi `ON DELETE CASCADE` sur `mesure.ruche_id` est-il un risque pour la preuve ?** Un seul `DELETE FROM ruche` efface **sans un message** toutes ses mesures : 4 368 lignes pour SN-KOLD-012 (testé dans une transaction annulée). Un voleur, ou un compte volé, ferait disparaître la chute de poids qui prouve le vol. Avec `RESTRICT`, la suppression est refusée.
2. **Que vaut `current_user` dans une fonction SECURITY DEFINER qui appartient à postgres ? Quelle conséquence pour le journal ?** Il vaut **`postgres`**, le propriétaire. Si le journal utilisait `current_user`, il accuserait toujours postgres, et le vrai acteur serait perdu. D'où `qui()`, qui lit le rôle de la session (`current_setting('role')`, sinon `session_user`) : le journal nomme `m.ndiaye` même quand la validation passe par `valider_recolte()`.
3. **Pourquoi donner à l'apicultrice INSERT sur la vue `v_mes_recoltes` plutôt que sur la table `recolte` ?** Avec INSERT sur la table, elle pourrait déclarer sur la ruche d'une autre, se mettre directement en `validee`, ou déclarer au nom d'une autre. Par la vue, `WITH CHECK OPTION` limite l'insertion à **ses** ruches, le droit sur 3 colonnes seulement interdit `statut`, et `declaree_par` est rempli par la base (`utilisateur_courant()`).
4. **Que risque-t-on si l'on oublie `REVOKE ALL ON FUNCTION valider_recolte(uuid) FROM PUBLIC` ?** Par défaut, **tout le monde** peut exécuter une fonction. Une apicultrice pourrait l'appeler, et c'est alors le contrôle interne (le rôle coordinateur, vérifié par `qui()`) qui serait la seule défense. Une seule erreur dans ce contrôle, et elle validerait ses propres récoltes avec les droits de postgres. Le test 7 montre le refus attendu : `droit refusé pour la fonction valider_recolte`.
