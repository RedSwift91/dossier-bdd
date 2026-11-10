# TP Jour 2 - Labs 6 et 7 - Killian Morvan

Notre base du jour 1 est utilisée : Fatou Ba du sujet = Awa Diop (+221 77 000 01 02, ruche SN-CASA-030), SN-CASA-011 = SN-CASA-021.

## Lab 6 - Décomposer sans rien perdre

### 6.1 Analyser la table reçue

![01_lab67_61_fichier](01_lab67_61_fichier.png)

![02_lab67_61_creation](02_lab67_61_creation.png)

![03_lab67_61_tests](03_lab67_61_tests.png)

Dépendances : (telephone, theme) → formateur, et formateur → theme.

Clés candidates : (telephone, theme) et (telephone, formateur).

3NF : oui, les trois colonnes font partie d'une clé candidate. BCNF : non, formateur → theme part de formateur, qui n'est pas une clé.

![04_lab67_61_anomalie](04_lab67_61_anomalie.png)

Anomalie : la table accepte que Moussa Sarr enseigne deux thèmes, sans aucun message.

### 6.2 Découper, et prouver qu'on n'a rien perdu

![05_lab67_62_mauvais](05_lab67_62_mauvais.png)

16 lignes au lieu de 8, dont 8 inventées : la colonne commune, theme, n'est la clé d'aucun des deux morceaux, car un thème a plusieurs formateurs. Awa Diop serait suivie par trois formateurs varroa.

![06_lab67_62_bon](06_lab67_62_bon.png)

Bon découpage : 5 formateurs, 8 suivis, 0 ligne de différence.

La contrainte UNIQUE sur formateur.nom garantit formateur → theme : un formateur n'a qu'une ligne, donc un seul thème.

suivi_formation pointe vers apicultrice(id) au lieu de recopier le téléphone, parce que le téléphone peut changer et que c'est une donnée personnelle. Pour que la jointure par téléphone retrouve une seule apicultrice, formation.sql pose UNIQUE (telephone) sur apicultrice.

### 6.3 La règle perdue, et le trigger qui la rétablit

![07_lab67_63_perdue](07_lab67_63_perdue.png)

Sans trigger, Awa Diop peut avoir deux formateurs varroa : plus aucune table ne contient à la fois l'apicultrice et le thème.

![08_lab67_63_trigger](08_lab67_63_trigger.png)

Avec le trigger : Ibrahima Fall (varroa) est refusé, Khady Ndiaye (récolte) est accepté. Le trigger ignore aussi l'ancienne ligne lors d'un UPDATE (changer de formateur dans le même thème est accepté), et un second trigger refuse qu'un formateur change de thème si l'une de ses apicultrices a déjà un formateur pour ce thème (Khady Ndiaye en varroa : refusé). Les tests sont dans tests_formation.sql.

Pour aller plus loin : en recopiant theme dans suivi_formation, avec UNIQUE (apicultrice_id, theme) et une clé étrangère (formateur_id, theme), la table n'est plus en BCNF (formateur_id → theme), mais elle reste en 3NF. La copie ne peut pas diverger.

### 6.4 Relire tout le schéma

site, cooperative, apicultrice, adhesion, mesure, inspection, recolte, alerte, formateur, suivi_formation : chaque dépendance part de la clé primaire ou d'une colonne UNIQUE. La partie gauche est une super-clé : BCNF.

formation_plat : formateur → theme ne part pas d'une clé, donc pas BCNF. C'est la table d'import, laissée telle quelle.

![09_lab67_64_sites](09_lab67_64_sites.png)

Chaque apicultrice n'a de ruches que sur son site. C'est une règle métier : une apicultrice est rattachée à un site, et le coordinateur valide les récoltes de son site. Elle est garantie par la clé étrangère composée (apicultrice_id, site_id) vers apicultrice (id, site_id), ajoutée au Lab 10.

### Testez-vous - Lab 6

1. (A, B) + (A, C) est sans perte : la colonne commune A est la clé de (A, B). (A, B) + (B, C) n'est pas garanti : B n'est la clé d'aucun morceau.

2. La 3NF accepte X → A quand A fait partie d'une clé candidate : theme fait partie de la clé (telephone, theme).

3. Sans s.formateur_id <> NEW.formateur_id, le trigger trouverait la ligne même qu'on écrit et refuserait à tort. Mais ça ne suffit pas : en changeant de formateur dans le même thème, l'ancienne ligne est encore en table pendant l'UPDATE, il faut donc aussi exclure OLD. Et un UPDATE du thème dans formateur a son propre trigger.

4. Rester en 3NF : avantage, toutes les règles sont garanties par des clés, sans trigger. Inconvénient, la redondance reste, avec l'anomalie de mise à jour.

## Lab 7 - Dénormaliser, en connaissance de cause

### 7.1 Mesurer avant de copier

![10_lab67_71_volume](10_lab67_71_volume.png)

volume.sql : INSERT 0 47520 (11 ruches x 4 320 mesures). Tableau de bord : 192 mesures par jour (4 ruches x 48).

![11_lab67_71_explain](11_lab67_71_explain.png)

Execution Time de la requête sur la table mesure : 10,6 ms.

### 7.2 La synthèse, et son prix

![12_lab67_72_vue](12_lab67_72_vue.png)

Mêmes chiffres dans la vue matérialisée : 0,06 ms au lieu de 10,6 ms.

![13_lab67_72_vol](13_lab67_72_vol.png)

Le vol (8,40 kg) n'apparaît dans la synthèse qu'après le REFRESH.

Si la vue n'est rafraîchie que la nuit, le vol reste invisible jusqu'à 24 h. Il faut donc le détecter sur les mesures brutes, pas dans la synthèse.

### 7.3 L'export pour le bailleur

![14_lab67_73_hash](14_lab67_73_hash.png)

Le téléphone d'Awa Diop est retrouvé à partir de son haché sha256 en 1,2 s.

![15_lab67_73_export](15_lab67_73_export.png)

8 lignes pour 11 ruches, sans nom ni téléphone. La clé n'est pas dans la définition de la vue (f).

Colonnes retirées :

- nom et téléphone : ils identifient la personne, et le téléphone permet de la contacter ;

- id de l'apicultrice : remplacé par un HMAC à clé secrète ;

- code de la ruche : il relie la ligne à une ruche, donc à une personne ;

- position exacte : elle mène à la ruche (risque de vol) ; elle est arrondie à 0,1°, soit environ 11 km ;

- date d'installation et détail des mesures : inutiles au bailleur, et utiles pour ré-identifier.

### 7.4 Le journal d'audit

![16_lab67_74_rejoue](16_lab67_74_rejoue.png)

denormalisation.sql est rejouable : le journal et la clé ne sont créés qu'une fois (IF NOT EXISTS), ils ne sont jamais effacés.

1. ligne_id n'est pas une clé étrangère : le journal doit survivre à la suppression de la récolte. Une clé étrangère bloquerait la suppression, ou effacerait la trace avec elle (CASCADE).

2. Recopier les lignes entières est acceptable : c'est une copie figée et datée, jamais modifiée, qui sert de preuve.

3. clock_timestamp() donne l'heure réelle de chaque écriture. now() donne l'heure du début de la transaction, la même pour toutes ses écritures.

### Testez-vous - Lab 7

1. Une vue est recalculée à chaque lecture : elle est toujours à jour, mais lente. Une vue matérialisée stocke son résultat : elle est rapide, mais en retard jusqu'au REFRESH.

2. md5(nom) : sans clé secrète, il se casse avec une liste de noms ; et deux homonymes (les deux Aminata Diop) auraient le même pseudonyme.

3. Oui, l'export est soumis au RGPD : des données pseudonymisées restent personnelles. Avec la clé, ou par recoupement, on peut retrouver la personne.

4. Le journal n'a pas de clé étrangère pour survivre à la suppression de la ligne, et parce qu'il surveille plusieurs tables.

---

# TP Jour 2 - Labs 8 à 10 - Killian Morvan

Notre base du jour 1 est utilisée : f.ba du sujet = awa.diop (Awa Diop, ruche SN-CASA-030), awa.diop du sujet = aminata.diop.casa, coord.sn = m.ndiaye, CI-MAN-012 = SN-KOLD-012, CM-BAF = CI-KORH. Les jetons s'appellent RT-awa.diop-1 à 30.

## Lab 8 - Contraintes, trigger d'audit et rôles

### 8.1 Que se passe-t-il quand on supprime ?

![17_lab810_81_delete](17_lab810_81_delete.png)

Par défaut, la suppression est refusée par mesure_ruche_fk. En CASCADE (transaction annulée), la ruche part avec ses 4 368 mesures, sans un message : 48 049, puis 43 681. Après le ROLLBACK, tout revient.

![18_lab810_81_references](18_lab810_81_references.png)

2 CASCADE (adhesion), 4 RESTRICT (mesure, inspection, recolte, alerte).

### 8.2 Refuser les valeurs impossibles

![19_lab810_82_check](19_lab810_82_check.png)

![20_lab810_82_tests](20_lab810_82_tests.png)

Notre schéma appelle le rôle « administrateur » (et non « admin ») et le statut « refusee » (et non « ecart ») : avec la liste du sujet, l'ALTER serait refusé à cause de cette ligne. On garde donc notre vocabulaire. Les deux tests sont refusés.

### 8.3 Le trigger d'audit

![21_lab810_83_audit](21_lab810_83_audit.png)

![22_lab810_83_tests](22_lab810_83_tests.png)

Le journal a bien enregistré la modification du volume (12.50 → 14.00) faite le 9 novembre. UPDATE, DELETE et TRUNCATE sont refusés, et le nombre de lignes ne bouge pas.

Limite : en postgres, DISABLE TRIGGER passe. Le propriétaire peut désactiver la protection : il faut donc aussi copier le journal hors de la base, vers le SIEM.

### 8.4 Les rôles et les vues de moindre privilège

Matrice des droits :

| Objet | apicultrice | coordinateur | gestionnaire | admin |
|---|---|---|---|---|
| ses ruches et leurs mesures | lire | lire (son site) | non | non |
| déclarer une récolte | sur ses ruches | non | non | non |
| valider une récolte | non | sur son site (fonction) | non | non |
| ruches et téléphones de son site | non | lire | non | non |
| synthèse et export | non | non | lire | non |
| comptes utilisateurs | son compte | son compte | son compte | lire, créer, modifier |
| journal d'audit | non | non | non | lire |

![23_lab810_84_roles](23_lab810_84_roles.png)

Cinq personnes, chacune dans son groupe. Les rôles n'ont pas de mot de passe : on les teste par SET ROLE en postgres.

### 8.5 et 8.6 La validation, et les tests de contournement

![24_lab810_86_apicultrice](24_lab810_86_apicultrice.png)

Tests 1 à 9 (awa.diop) : table refusée, ses ruches seulement, sa récolte acceptée, la ruche d'une autre refusée (check option), le statut refusé, UPDATE refusé, valider_recolte refusée, journal refusé, DISABLE TRIGGER refusé.

![25_lab810_86_coord](25_lab810_86_coord.png)

Tests 10 et 11 (m.ndiaye) : la récolte du test 3 est validée, puis refusée la deuxième fois ; la récolte d'un autre site est refusée.

![26_lab810_86_admin](26_lab810_86_admin.png)

Test 12 (admin.beeafrica) : le journal nomme les vrais acteurs (awa.diop, m.ndiaye), même quand la validation passe par une fonction exécutée avec les droits de postgres. La suppression d'un utilisateur est refusée.

### Testez-vous - Lab 8

1. CASCADE sur mesure.ruche_id efface toutes les mesures d'une ruche en un seul DELETE : la chute de poids qui prouve un vol disparaît.

2. Dans une fonction SECURITY DEFINER de postgres, current_user vaut postgres : le journal accuserait toujours postgres. D'où qui(), qui lit le rôle de la session.

3. Par la vue, l'apicultrice ne peut écrire que sur ses ruches (WITH CHECK OPTION) et que trois colonnes : elle ne peut ni se valider, ni déclarer au nom d'une autre.

4. Sans REVOKE, tout le monde peut appeler valider_recolte, qui s'exécute avec les droits de postgres : seul le contrôle écrit dans la fonction protégerait encore.

## Lab 9 - Transactions

### 9.1 L'action et sa trace ensemble

![27_lab810_91_trace](27_lab810_91_trace.png)

L'UPDATE est refusé par recolte_validation_tracee, mais le journal de l'application affirme la validation : la trace ment.

![28_lab810_91_transaction](28_lab810_91_transaction.png)

Dans la transaction, le journal passe à +1. Après l'erreur, tout est refusé (transaction annulée). Après le ROLLBACK, tout revient.

### 9.2 La course au jeton, dans deux terminaux

![29_lab810_92_jeton](29_lab810_92_jeton.png)

![30_lab810_92_retrait](30_lab810_92_retrait.png)

jeton.sql contient déjà la contrainte de l'étape 9.4 : on la retire pour rejouer la course.

| Temps | Terminal A | Terminal B |
|---|---|---|
| T1 | BEGIN |   |
| T2 |   | BEGIN |
| T3 | SELECT : utilise_le vide |   |
| T4 |   | SELECT : utilise_le vide |
| T5 | UPDATE 1 |   |
| T6 | INSERT 0 1 |   |
| T7 | COMMIT |   |
| T8 |   | UPDATE 1 |
| T9 |   | INSERT 0 1 |
| T10 |   | COMMIT |

![31_lab810_naif_A](31_lab810_naif_A.png)

![32_lab810_naif_B](32_lab810_naif_B.png)

2 sessions avec un seul jeton.

### 9.3 La course par un programme

![33_lab810_93_vuln](33_lab810_93_vuln.png)

![34_lab810_93_corrige](34_lab810_93_corrige.png)

Version vulnérable : 2 sessions à chaque fois. Version corrigée (UPDATE ... RETURNING) : un accepté, un refusé, 1 session.

### 9.4 Les quatre corrections

1. SELECT ... FOR UPDATE : B se fige au T4, puis voit utilise_le rempli dès que A fait COMMIT.

![35_lab810_for_update_A](35_lab810_for_update_A.png)

![36_lab810_for_update_B](36_lab810_for_update_B.png)

2. UPDATE ... RETURNING : A reçoit un id, B attend puis reçoit UPDATE 0.

![37_lab810_returning_A](37_lab810_returning_A.png)

![38_lab810_returning_B](38_lab810_returning_B.png)

3. UNIQUE (jeton_id) : d'abord refusée à cause des doublons, qu'on supprime en gardant la plus ancienne session ; puis le programme vulnérable n'ouvre plus qu'une session.

![39_lab810_94_unique](39_lab810_94_unique.png)

![40_lab810_94_course](40_lab810_94_course.png)

4. REPEATABLE READ : l'UPDATE de B échoue (« n'a pas pu sérialiser un accès »).

![41_lab810_repeatable_A](41_lab810_repeatable_A.png)

![42_lab810_repeatable_B](42_lab810_repeatable_B.png)

| Correction | Où agit-elle ? | Que voit la seconde requête ? | Avantage | Limite |
|---|---|---|---|---|
| SELECT ... FOR UPDATE | dans le code (verrou) | elle attend, puis voit le jeton utilisé | simple à ajouter | à ne pas oublier dans chaque programme |
| UPDATE ... RETURNING | dans le code (une instruction) | elle attend, puis 0 ligne | sûr et rapide | chaque programme doit l'écrire ainsi |
| UNIQUE (jeton_id) | dans la base | une erreur duplicate key | protège même le code vulnérable | l'erreur doit être gérée |
| REPEATABLE READ | dans la transaction | une erreur de sérialisation | aucune requête à changer | il faut réessayer |

Le trigger du lab 6 est aussi un « vérifier, puis agir » : deux insertions simultanées le contournent.

![43_lab810_trigger_A](43_lab810_trigger_A.png)

![44_lab810_trigger_B](44_lab810_trigger_B.png)

Fatou Sow a deux formateurs varroa. Une contrainte le protégerait : theme recopié dans suivi_formation, avec UNIQUE (apicultrice_id, theme) et une clé étrangère (formateur_id, theme).

### 9.5 Durabilité et sauvegarde

![45_lab810_95_show](45_lab810_95_show.png)

![46_lab810_95_sauvegarde](46_lab810_95_sauvegarde.png)

![47_lab810_95_empreinte](47_lab810_95_empreinte.png)

Même empreinte que celle gardée dans le dépôt ; le journal restauré a le même nombre de lignes, et le DELETE y est refusé.

Avec synchronous_commit = off, on perdrait les dernières transactions confirmées en cas de panne.

On garde l'empreinte ailleurs que la sauvegarde : sinon, celui qui modifie la sauvegarde modifie aussi l'empreinte.

pg_dump ne sauvegarde pas les rôles : il faut aussi pg_dumpall --roles-only.

La durabilité protège d'une panne. La sauvegarde protège de la perte du disque, d'une erreur ou d'un rançongiciel.

### Testez-vous - Lab 9

1. Après une erreur, la transaction est annulée et psql affiche queenbee=!#. Il faut taper ROLLBACK.

2. En READ COMMITTED, les deux SELECT voient le jeton libre avant que l'un ne valide : rien ne relie la vérification à l'action.

3. L'UPDATE verrouille la ligne ; quand A valide, la condition utilise_le IS NULL est réévaluée pour B : 0 ligne.

4. ACID ne protège pas d'un rançongiciel. Ce qui protège : des sauvegardes hors du serveur, testées, avec leur empreinte.

## Lab 10 - Revue de sécurité

### 10.1 L'injection par le tri

![48_lab810_101_normal](48_lab810_101_normal.png)

![49_lab810_101_erreur](49_lab810_101_erreur.png)

Par erreur : le téléphone d'Awa Diop apparaît dans le message de la base.

![50_lab810_101_aveugle](50_lab810_101_aveugle.png)

À l'aveugle : avec « 77 » le tri se fait par code, avec « 78 » par longitude. L'ordre répond oui ou non.

![51_lab810_101_empilee](51_lab810_101_empilee.png)

Empilée : refusée, une requête paramétrée ne contient qu'une commande.

![52_lab810_101_corrige](52_lab810_101_corrige.png)

recherche.py (liste blanche, sql.Identifier) : le tri inconnu est refusé, le tri normal marche.

### 10.2 La vue qui en dit trop

![53_lab810_102_avant](53_lab810_102_avant.png)

Avant correction (état remis dans une transaction annulée) : la table est refusée, mais la vue de carte montre les 11 ruches avec tous les téléphones ; l'espion ne renvoie qu'une ligne, mais ses NOTICE donnent la position des 11 ruches.

![54_lab810_10_corrections](54_lab810_10_corrections.png)

![55_lab810_102_meme_session](55_lab810_102_meme_session.png)

![56_lab810_102_nouvelle_session](56_lab810_102_nouvelle_session.png)

Après corrections.sql : une seule ligne sans téléphone, l'espion ne voit plus que SN-CASA-030, et dans une nouvelle session la fonction temporaire est refusée.

### 10.3 Auditer notre base

![57_lab810_103_c1_c3](57_lab810_103_c1_c3.png)

C1 : 0 fonction exécutable par PUBLIC. C2 : les 3 fonctions SECURITY DEFINER fixent leur search_path. C3 : les 7 vues filtrantes sont des barrières. v_export_bailleur ne filtre pas par utilisateur et n'est donnée qu'au gestionnaire ; v_ruche_coordinateur (jour 1) n'est donnée à personne.

![58_lab810_103_c4](58_lab810_103_c4.png)

C4 : chaque rôle ne voit que son périmètre.

![59_lab810_103_c5_c7](59_lab810_103_c5_c7.png)

C5 : trois refus. C6 : le journal nomme admin.beeafrica. C7 : refus par la check option. C10 : les 4 preuves sont en RESTRICT (r).

![60_lab810_103_c8](60_lab810_103_c8.png)

C8 : 1 session.

![61_lab810_103_c9_c11](61_lab810_103_c9_c11.png)

C9 : seuls les deux scripts volontairement vulnérables construisent une requête par +. C11 : le mot « password » n'apparaît que dans des explications, aucun secret.

![62_lab810_103_c12](62_lab810_103_c12.png)

C12 : la base se reconstruit avec nos fichiers dans une base vide (code 0 partout, seulement les refus voulus).

![63_lab810_103_constats](63_lab810_103_constats.png)

Retests des constats : R1, le compte qb_recherche ne lit que la ruche, l'attaque est refusée ; R2, une nouvelle fonction n'est plus ouverte à PUBLIC (0 ligne) ; R3, PUBLIC n'a plus de droit sur la base ; R4, une ruche ne peut plus changer de site sans son apicultrice. R5 (C4) : le gestionnaire lit l'export, mais pas la clé.

| ID | Gravité | Constat | Correction |
|---|---|---|---|
| P1 | haute | injection par le tri | liste blanche et sql.Identifier |
| P2 | critique | vue de carte trop large | vue réécrite, security_barrier |
| P3 | critique | fuite par fonction espion | security_barrier, REVOKE TEMPORARY |
| R1 | haute | scripts connectés en superutilisateur | compte qb_recherche minimal |
| R2 | moyenne | nouvelles fonctions ouvertes à PUBLIC | ALTER DEFAULT PRIVILEGES |
| R3 | basse | nom de la base écrit en dur | current_database() |
| R4 | haute | ruche sur un autre site que son apicultrice | clé étrangère composée |
| R5 | moyenne | le gestionnaire ne lisait pas l'export | GRANT EXECUTE sur hmac |

### Testez-vous - Lab 10

![64_lab810_104_order_by](64_lab810_104_order_by.png)

1. ORDER BY %s envoie une valeur, pas un nom de colonne : on trie par une constante, l'ordre ne change pas.

2. Non : l'attaque par erreur et l'attaque à l'aveugle passent quand même.

3. security_barrier : le filtre de la vue passe avant les conditions de l'utilisateur. security_invoker : la vue s'exécute avec les droits de celui qui la lit.

4. Critique : la vue v_carte_ruches d'origine. Haute : une fonction SECURITY DEFINER sans search_path. Basse : un README absent.

## 11 - Rendu

Le schéma complet est exporté dans jour2/1_schema_normalise/schema_j2.sql, les fichiers sont rangés dans jour2/, et le README explique comment reconstruire la base. La reconstruction dans une base vide est montrée par le contrôle C12 ci-dessus.
