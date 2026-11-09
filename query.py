# query.py : la même recherche, avec une requête paramétrée
#
# | Saisie                                            | query_vuln.py                         | query.py |
# | code normal (SN-CASA-014)                         | 1 ligne                               | 1 ligne  |
# | ' OR '1'='1                                       | 11 lignes : toutes les ruches         | 0 ligne  |
# | ' UNION SELECT nom, telephone FROM apicultrice -- | 8 lignes : noms et téléphones de      | 0 ligne  |
# |                                                   | toutes les apicultrices               |          |
#
# Pourquoi query.py résiste : la requête et la valeur partent séparément vers PostgreSQL (%s est un
# paramètre, pas un morceau de texte collé). Le serveur analyse d'abord la requête, puis reçoit la saisie
# comme une simple valeur de type texte : apostrophes, OR et UNION n'y sont jamais lus comme du SQL. On
# cherche donc une ruche dont le code est littéralement « ' OR '1'='1 », et il n'y en a aucune.
import psycopg

conn = psycopg.connect(dbname="queenbee")
code = input("Code ruche : ")
rows = conn.execute("SELECT code, site_id FROM ruche WHERE code = %s", (code,)).fetchall()
print(len(rows), "ligne(s)")
for row in rows:
    print(row)
