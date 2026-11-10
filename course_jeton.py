"""course_jeton.py : deux requêtes en même temps avec le même jeton (version vulnérable)."""
import sys, threading, time
import psycopg

JETON = sys.argv[1]
depart = threading.Barrier(2)
resultats = {}

def rafraichir(nom):
    try:
        with psycopg.connect(dbname="queenbee") as conn:
            depart.wait()
            row = conn.execute(
                "SELECT id, utilisateur_id, utilise_le FROM jeton WHERE valeur = %s",
                (JETON,)).fetchone()
            if row is None or row[2] is not None:                  # 1. vérifier
                resultats[nom] = "refusé : jeton déjà utilisé"
                return
            time.sleep(0.2)
            conn.execute("UPDATE jeton SET utilise_le = now() WHERE id = %s", (row[0],))
            conn.execute("INSERT INTO session_app (utilisateur_id, jeton_id) VALUES (%s, %s)",
                         (row[1], row[0]))                         # 2. agir
            resultats[nom] = "accepté : session ouverte"
    except psycopg.Error as e:
        resultats[nom] = "erreur de la base : " + e.diag.message_primary

fils = [threading.Thread(target=rafraichir, args=(n,)) for n in ("requête 1", "requête 2")]
for f in fils: f.start()
for f in fils: f.join()
for nom in sorted(resultats):
    print(nom, "->", resultats[nom])

with psycopg.connect(dbname="queenbee") as conn:
    n = conn.execute("""SELECT count(*) FROM session_app s JOIN jeton j ON j.id = s.jeton_id
                        WHERE j.valeur = %s""", (JETON,)).fetchone()[0]
print("sessions ouvertes avec ce jeton :", n)
