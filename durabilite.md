# Durabilité et sauvegarde - Groupe Killian Morvan

> **TP Jour 2 · Lab 9 · Étape 9.5**
> Fichier lié : `queenbee_j2.dump.sha256` (l'empreinte). La sauvegarde `queenbee_j2.dump` n'est **pas** dans le dépôt : elle est grosse et contient des données personnelles (`.gitignore`).

## Les réglages de durabilité

| Réglage | Attendu | Obtenu | Rôle |
|---|---|---|---|
| `fsync` | on | ✅ on | PostgreSQL force l'écriture physique sur le disque |
| `synchronous_commit` | on | ✅ on | un `COMMIT` ne répond qu'une fois le journal d'écriture (WAL) sur le disque |
| `wal_level` | replica | ✅ replica | le WAL contient assez d'informations pour une réplique ou une restauration à un instant donné |

## La sauvegarde vérifiée

```bash
pg_dump -U postgres -d queenbee -Fc -f queenbee_j2.dump
sha256sum queenbee_j2.dump > queenbee_j2.dump.sha256
certutil -hashfile queenbee_j2.dump SHA256
psql -U postgres -d postgres -c "CREATE DATABASE queenbee_restore"
pg_restore -U postgres -d queenbee_restore queenbee_j2.dump
sha256sum -c queenbee_j2.dump.sha256
```

| Vérification | Obtenu |
|---|---|
| taille de la sauvegarde | 774 360 octets |
| empreinte SHA-256 (`sha256sum`) | `3d0c1007edf34e1575ae8142dd3ec45406cca9fc5dcfb22a6b3603f8efc08700` |
| empreinte (`certutil`, Windows) | la même, comparée à l'œil ✅ |
| `pg_restore` dans `queenbee_restore` | code de retour 0, aucune erreur ✅ |
| lignes de `journal_audit` : base / copie | 13 / 13 ✅ |
| `DELETE FROM journal_audit` dans la copie | ❌ refusé : `journal_audit est en ajout seul : DELETE interdit` ✅ (le trigger est restauré avec la table) |
| `sha256sum -c queenbee_j2.dump.sha256` | **`queenbee_j2.dump: OK`** ✅ |

## Les questions

**Que perdrait-on avec `synchronous_commit = off` ?** Le `COMMIT` répondrait **avant** que le WAL soit sur le disque. Après une panne (coupure de courant, fréquente sur un site rucher), les dernières transactions confirmées (jusqu'à environ trois fois `wal_writer_delay`, soit environ 600 ms) seraient **perdues**, alors que l'application a dit « enregistré ». Une mesure, une récolte, une ligne de journal : la preuve disparaît. La base reste cohérente, mais elle n'est plus durable.

**Pourquoi garder l'empreinte ailleurs que la sauvegarde ?** Un attaquant qui modifie la sauvegarde (pour effacer une trace du journal, par exemple) peut aussi recalculer l'empreinte posée à côté. Gardée **ailleurs** (ici dans le dépôt Git, dont l'historique est daté et copié), elle prouve que la sauvegarde n'a pas été modifiée depuis.

**Ce que `pg_dump` ne sauvegarde pas :** les objets **communs au serveur**, et d'abord les **rôles** (`qb_apicultrice`, `awa.diop`...) et leurs appartenances. Restaurée sur un serveur neuf, la base aurait des `GRANT` vers des rôles qui n'existent pas. Il faut aussi `pg_dumpall --roles-only` (sans les mots de passe : `--no-role-passwords`), ainsi que la configuration (`postgresql.conf`, `pg_hba.conf`).

**Durabilité ou sauvegarde ?**

| | Durabilité (le D de ACID) | Sauvegarde |
|---|---|---|
| protège de | une **panne** : coupure, plantage du serveur | la **perte du disque**, une **erreur** (un `DELETE` validé), un **rançongiciel**, un incendie |
| comment | le WAL écrit sur le disque avant le `COMMIT`, rejoué au redémarrage | une copie **ailleurs**, régulière, **restaurée pour être testée**, hors ligne ou immuable |
| limite | une erreur validée est durablement validée ; un disque chiffré est durablement chiffré | on perd ce qui s'est passé depuis la dernière sauvegarde |
